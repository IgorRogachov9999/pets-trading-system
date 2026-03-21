# PostgreSQL 16 + Dapper Reference

## Schema Design Principles

- Use `UUID` (or `gen_random_uuid()`) as primary keys for all entities — never auto-increment integers.
- Use `TIMESTAMPTZ` (not `TIMESTAMP`) for all datetime columns to avoid timezone ambiguity.
- Store monetary amounts as `NUMERIC(12,2)` — never `FLOAT` or `DOUBLE`.
- Use `TEXT` for string columns unless a fixed length constraint adds business value.
- Apply `NOT NULL` by default; allow `NULL` only when absence is semantically meaningful.
- Add check constraints at the DB level for invariants (e.g., `asking_price > 0`).

### Key Tables

```sql
CREATE TABLE traders (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cognito_sub     TEXT UNIQUE NOT NULL,
    username        TEXT UNIQUE NOT NULL,
    available_cash  NUMERIC(12,2) NOT NULL DEFAULT 150.00 CHECK (available_cash >= 0),
    locked_cash     NUMERIC(12,2) NOT NULL DEFAULT 0.00   CHECK (locked_cash >= 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE pets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    breed_id        INTEGER NOT NULL REFERENCES pet_dictionary(id),
    owner_id        UUID REFERENCES traders(id),
    health          NUMERIC(5,2) NOT NULL CHECK (health BETWEEN 0 AND 100),
    desirability    NUMERIC(4,2) NOT NULL CHECK (desirability BETWEEN 0 AND 10),
    intrinsic_value NUMERIC(12,2) NOT NULL DEFAULT 0,
    age             NUMERIC(8,4) NOT NULL DEFAULT 0,  -- cached; derived from created_at
    is_expired      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE listings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID NOT NULL REFERENCES pets(id),
    seller_id       UUID NOT NULL REFERENCES traders(id),
    asking_price    NUMERIC(12,2) NOT NULL CHECK (asking_price > 0),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    last_trade_price NUMERIC(12,2),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (pet_id, is_active) WHERE is_active = TRUE  -- one active listing per pet
);

CREATE TABLE bids (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id      UUID NOT NULL REFERENCES listings(id),
    bidder_id       UUID NOT NULL REFERENCES traders(id),
    amount          NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    status          TEXT NOT NULL CHECK (status IN ('active','accepted','rejected','withdrawn','outbid')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## Index Strategy

Index every foreign key and every column used in `WHERE`/`ORDER BY` on hot paths.

```sql
-- listings hot path: market view
CREATE INDEX idx_listings_active ON listings(created_at DESC) WHERE is_active = TRUE;
CREATE INDEX idx_listings_seller ON listings(seller_id);
CREATE INDEX idx_listings_pet    ON listings(pet_id);

-- bids: find active bid for a listing
CREATE INDEX idx_bids_listing_active ON bids(listing_id) WHERE status = 'active';
CREATE INDEX idx_bids_bidder ON bids(bidder_id);

-- trades: most recent trade price for a listing
CREATE INDEX idx_trades_listing ON trades(listing_id, executed_at DESC);

-- notifications: trader's notification feed
CREATE INDEX idx_notifications_trader ON notifications(trader_id, created_at DESC);

-- pets: Lifecycle Lambda scans all non-expired pets
CREATE INDEX idx_pets_active ON pets(is_expired) WHERE is_expired = FALSE;
```

---

## ACID Compliance for Financial Operations

All cash-moving operations must execute inside an **explicit transaction** with row-level locking.

### Bid Placement / Replacement (atomic)

```sql
BEGIN;

-- 1. Lock listing row to prevent concurrent modifications
SELECT id, seller_id, is_active FROM listings WHERE id = @ListingId FOR UPDATE;

-- 2. Lock the current bidder's trader row (for cash deduction)
SELECT id, available_cash, locked_cash FROM traders WHERE id = @BidderId FOR UPDATE;

-- 3. Release previous active bid (if any) — return locked cash to previous bidder
UPDATE traders
SET available_cash = available_cash + b.amount,
    locked_cash    = locked_cash    - b.amount
FROM bids b
WHERE b.listing_id = @ListingId
  AND b.status = 'active'
  AND traders.id = b.bidder_id;

UPDATE bids SET status = 'outbid'
WHERE listing_id = @ListingId AND status = 'active';

-- 4. Deduct from new bidder
UPDATE traders
SET available_cash = available_cash - @Amount,
    locked_cash    = locked_cash    + @Amount
WHERE id = @BidderId;

-- 5. Insert new bid
INSERT INTO bids (id, listing_id, bidder_id, amount, status, created_at)
VALUES (gen_random_uuid(), @ListingId, @BidderId, @Amount, 'active', NOW());

COMMIT;
```

### Trade Execution (accept bid)

```sql
BEGIN;

SELECT * FROM listings WHERE id = @ListingId AND is_active = TRUE FOR UPDATE;
SELECT * FROM bids     WHERE listing_id = @ListingId AND status = 'active' FOR UPDATE;
SELECT * FROM traders  WHERE id IN (@SellerId, @BuyerId) FOR UPDATE;

-- Transfer pet ownership
UPDATE pets SET owner_id = @BuyerId WHERE id = @PetId;

-- Transfer cash
UPDATE traders SET locked_cash = locked_cash - @Amount WHERE id = @BuyerId;
UPDATE traders SET available_cash = available_cash + @Amount WHERE id = @SellerId;

-- Close listing and bid
UPDATE listings SET is_active = FALSE, last_trade_price = @Amount WHERE id = @ListingId;
UPDATE bids SET status = 'accepted' WHERE id = @BidId;

-- Record trade
INSERT INTO trades (id, listing_id, pet_id, buyer_id, seller_id, price, executed_at)
VALUES (gen_random_uuid(), @ListingId, @PetId, @BuyerId, @SellerId, @Amount, NOW());

COMMIT;
```

---

## Dapper Patterns

### Parameterized Queries

Always use `@ParamName` syntax. Never concatenate user input into SQL strings.

```csharp
// Correct
var listing = await conn.QuerySingleOrDefaultAsync<Listing>(
    "SELECT * FROM listings WHERE id = @Id", new { Id = listingId });

// WRONG — SQL injection risk
var listing = await conn.QuerySingleOrDefaultAsync<Listing>(
    $"SELECT * FROM listings WHERE id = '{listingId}'");
```

### Executing Inside a Transaction (Dapper)

```csharp
await using var conn = await _dataSource.OpenConnectionAsync(ct);
await using var tx = await conn.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
try
{
    await conn.ExecuteAsync("UPDATE ...", new { ... }, transaction: tx);
    await conn.ExecuteAsync("INSERT ...", new { ... }, transaction: tx);
    await tx.CommitAsync(ct);
}
catch
{
    await tx.RollbackAsync(ct);
    throw;
}
```

### Multi-Row Inserts

Use `DynamicParameters` or pass an enumerable for bulk inserts:

```csharp
await conn.ExecuteAsync(
    "INSERT INTO notifications (id, trader_id, type, payload, created_at) VALUES (@Id, @TraderId, @Type, @Payload::jsonb, NOW())",
    notifications.Select(n => new { Id = Guid.NewGuid(), n.TraderId, n.Type, Payload = JsonSerializer.Serialize(n) }));
```

---

## Intrinsic Value Calculation Query

Derive age from `created_at` — never trust the cached `pets.age` column for financial calculations:

```sql
SELECT
    p.id,
    p.health,
    p.desirability,
    pd.base_price,
    pd.lifespan,
    EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 86400.0 AS age_days,
    pd.base_price
        * (p.health / 100.0)
        * (p.desirability / 10.0)
        * GREATEST(0, 1 - (EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 86400.0) / pd.lifespan)
        AS intrinsic_value,
    (EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 86400.0) >= pd.lifespan AS is_expired
FROM pets p
JOIN pet_dictionary pd ON pd.id = p.breed_id
WHERE p.owner_id = @TraderId;
```

---

## Connection Pooling

Register `NpgsqlDataSource` once at startup. The data source manages the connection pool.

```csharp
var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);
dataSourceBuilder.EnableDynamicJson();
builder.Services.AddSingleton(dataSourceBuilder.Build());
```

Connection string pool settings (RDS recommended):
```
Pooling=true;MinPoolSize=2;MaxPoolSize=20;ConnectionIdleLifetime=300;ConnectionPruningInterval=10
```

Set `MaxPoolSize` based on: `RDS max_connections / (number of ECS tasks × services per task)`.

---

## Migration Strategy

Use plain SQL migration files with a timestamp prefix. Apply in CI/CD before deploying the app.

```
migrations/
  20260301_001_initial_schema.sql
  20260302_001_add_notifications_table.sql
  20260310_001_add_idx_listings_active.sql
```

Migration runner (Flyway or custom):
```bash
flyway -url=jdbc:postgresql://$DB_HOST/pettrading \
       -user=$DB_USER -password=$DB_PASSWORD \
       migrate
```

Or custom .NET migration runner using Dapper:

```csharp
// Apply migrations not yet in schema_versions table
var applied = (await conn.QueryAsync<string>("SELECT version FROM schema_versions")).ToHashSet();
foreach (var file in Directory.GetFiles("migrations", "*.sql").OrderBy(f => f))
{
    var version = Path.GetFileNameWithoutExtension(file);
    if (!applied.Contains(version))
    {
        var sql = await File.ReadAllTextAsync(file);
        await conn.ExecuteAsync(sql);
        await conn.ExecuteAsync("INSERT INTO schema_versions (version, applied_at) VALUES (@v, NOW())", new { v = version });
    }
}
```

---

## Query Optimization

- Run `EXPLAIN ANALYZE` on every non-trivial query before merging.
- Avoid `SELECT *` in production queries — name the columns you need.
- Use `LIMIT` on all list queries; never return unbounded result sets.
- For the leaderboard (portfolioValues), pre-compute `intrinsic_value` in the Lifecycle Lambda tick
  rather than calculating it on every leaderboard request.
- Use `RETURNING` on `INSERT`/`UPDATE` to avoid a separate `SELECT` round-trip:

```sql
UPDATE traders SET available_cash = available_cash - @Amount WHERE id = @Id
RETURNING available_cash, locked_cash;
```

---

## RDS Multi-AZ Failover Considerations

- Automatic failover occurs in < 60 s for Multi-AZ deployments.
- Use a retry loop with exponential backoff on `NpgsqlException` with `SqlState` indicating
  connection failure (codes `08*`, `57P03`).
- Configure `Tcp Keepalive=true` in the connection string to detect stale connections.
- Health check endpoint (`/ready`) must verify DB connectivity; ECS will drain traffic during failover.
- Do not cache connection strings; reload from Secrets Manager on startup and on reconnect error.
