# Dapper Advanced Reference — .NET 10, PostgreSQL/Npgsql

## Table of Contents
1. [Connection Management with NpgsqlDataSource](#1-connection-management-with-npgsqldatasource)
2. [Core Query Methods](#2-core-query-methods)
3. [Parameterized Queries & SQL Injection Prevention](#3-parameterized-queries--sql-injection-prevention)
4. [Transactions for Financial Operations](#4-transactions-for-financial-operations)
5. [Multi-Mapping (Relationships)](#5-multi-mapping-relationships)
6. [Multiple Result Sets](#6-multiple-result-sets)
7. [Dynamic Parameters & Stored Procedures](#7-dynamic-parameters--stored-procedures)
8. [Buffered vs Unbuffered Queries](#8-buffered-vs-unbuffered-queries)
9. [Repository Pattern with Dapper](#9-repository-pattern-with-dapper)
10. [Common Pitfalls](#10-common-pitfalls)

---

## 1. Connection Management with NpgsqlDataSource

Always use `NpgsqlDataSource` — it manages connection pooling, prepared statement caching, and authentication. Never instantiate `NpgsqlConnection` directly in application code.

```csharp
// Program.cs — register once
var connectionString = configuration.GetConnectionString("Postgres")
    ?? throw new InvalidOperationException("Postgres connection string missing");

var dataSource = NpgsqlDataSource.Create(connectionString);
builder.Services.AddSingleton(dataSource);

// In repositories — inject NpgsqlDataSource, open connections per operation
public class TraderRepository(NpgsqlDataSource dataSource) : ITraderRepository
{
    public async Task<Trader?> GetByIdAsync(TraderId id, CancellationToken ct)
    {
        await using var connection = await dataSource.OpenConnectionAsync(ct);
        return await connection.QuerySingleOrDefaultAsync<TraderRow>(
            "SELECT * FROM traders WHERE id = @id",
            new { id = id.Value });
    }
}
```

**Connection string tuning for ECS:**
```
Host=rds-endpoint;Port=5432;Database=petsdb;Username=app_user;Password=...;
Maximum Pool Size=20;Minimum Pool Size=2;Connection Idle Lifetime=300;
Pooling=true;Timeout=30;CommandTimeout=60
```

Set `Maximum Pool Size` per ECS task × tasks ≤ RDS `max_connections`. For `db.t3.medium` (max 170), with 3 tasks: `Maximum Pool Size=50` leaves room for migrations and admin.

---

## 2. Core Query Methods

| Method | Use case |
|---|---|
| `QueryAsync<T>` | Multiple rows |
| `QuerySingleAsync<T>` | Exactly one row; throws if 0 or >1 |
| `QuerySingleOrDefaultAsync<T>` | Zero or one row; throws if >1 |
| `QueryFirstOrDefaultAsync<T>` | First row or null; never throws |
| `ExecuteAsync` | INSERT / UPDATE / DELETE — returns rows affected |
| `ExecuteScalarAsync<T>` | Single value (COUNT, MAX, etc.) |
| `QueryMultipleAsync` | Multiple result sets in one round-trip |

```csharp
// Multiple rows
var listings = await conn.QueryAsync<ListingRow>(
    "SELECT * FROM listings WHERE is_active = TRUE ORDER BY created_at DESC",
    cancellationToken: ct);

// Single row — throws if missing (use for by-PK lookups where missing = bug)
var pet = await conn.QuerySingleAsync<PetRow>(
    "SELECT * FROM pets WHERE id = @id", new { id });

// Single or null — use for user-facing lookups that return 404 on missing
var trader = await conn.QuerySingleOrDefaultAsync<TraderRow>(
    "SELECT * FROM traders WHERE id = @id", new { id });

// Scalar
var count = await conn.ExecuteScalarAsync<int>(
    "SELECT COUNT(*) FROM listings WHERE is_active = TRUE");

// DML — check rows affected for optimistic concurrency
var affected = await conn.ExecuteAsync(
    "UPDATE pets SET health = @health WHERE id = @id",
    new { health, id });
if (affected == 0) throw new ConcurrencyException("Pet was modified concurrently");
```

Always pass `cancellationToken: ct` to async Dapper methods that accept it.

---

## 3. Parameterized Queries & SQL Injection Prevention

Dapper parameterizes via anonymous objects, `DynamicParameters`, or typed DTOs. **Never interpolate user input into SQL strings.**

```csharp
// CORRECT — parameterized
var result = await conn.QueryAsync<ListingRow>(
    "SELECT * FROM listings WHERE asking_price <= @maxPrice AND breed_id = @breedId",
    new { maxPrice, breedId });

// WRONG — injection vector
var result = await conn.QueryAsync<ListingRow>(
    $"SELECT * FROM listings WHERE breed_id = '{breedId}'");  // Never do this

// IN clause — Dapper expands IEnumerable automatically
var ids = new[] { 1, 2, 3 };
var pets = await conn.QueryAsync<PetRow>(
    "SELECT * FROM pets WHERE id = ANY(@ids)",
    new { ids });
// For PostgreSQL use ANY(@ids) with array; Dapper handles Npgsql array binding
```

**DynamicParameters** for conditional queries:
```csharp
var parameters = new DynamicParameters();
parameters.Add("@isActive", true);
if (breedId.HasValue)
    parameters.Add("@breedId", breedId.Value);

var sql = "SELECT * FROM listings WHERE is_active = @isActive"
        + (breedId.HasValue ? " AND breed_id = @breedId" : "");

var listings = await conn.QueryAsync<ListingRow>(sql, parameters);
```

---

## 4. Transactions for Financial Operations

Every mutation that involves cash, bids, or ownership transfer must run inside an explicit transaction with appropriate row locking.

```csharp
// Atomic bid replacement — the critical financial operation
public async Task ReplaceBidAsync(
    ListingId listingId,
    TraderId previousBidderId, decimal previousAmount,
    TraderId newBidderId, decimal newAmount,
    CancellationToken ct)
{
    await using var conn = await dataSource.OpenConnectionAsync(ct);
    await using var tx = await conn.BeginTransactionAsync(ct);
    try
    {
        // 1. Lock the listing row to prevent concurrent modifications
        var listing = await conn.QuerySingleOrDefaultAsync<ListingRow>(
            "SELECT * FROM listings WHERE id = @listingId FOR UPDATE",
            new { listingId = listingId.Value },
            transaction: tx);

        if (listing is null) throw new NotFoundException($"Listing {listingId} not found");
        if (!listing.IsActive) throw new DomainException("Listing is not active");

        // 2. Reject and release previous bid
        await conn.ExecuteAsync(
            "UPDATE bids SET status = 'outbid' WHERE listing_id = @listingId AND status = 'active'",
            new { listingId = listingId.Value }, transaction: tx);

        await conn.ExecuteAsync(
            @"UPDATE traders
              SET available_cash = available_cash + @amount,
                  locked_cash    = locked_cash    - @amount
              WHERE id = @traderId",
            new { amount = previousAmount, traderId = previousBidderId.Value },
            transaction: tx);

        // 3. Lock new bidder and deduct cash
        await conn.ExecuteAsync(
            @"UPDATE traders
              SET available_cash = available_cash - @amount,
                  locked_cash    = locked_cash    + @amount
              WHERE id = @traderId AND available_cash >= @amount",
            new { amount = newAmount, traderId = newBidderId.Value },
            transaction: tx);

        // 4. Insert new active bid
        await conn.ExecuteAsync(
            @"INSERT INTO bids (id, listing_id, bidder_id, amount, status, created_at)
              VALUES (@id, @listingId, @bidderId, @amount, 'active', now())",
            new { id = Guid.NewGuid(), listingId = listingId.Value,
                  bidderId = newBidderId.Value, amount = newAmount },
            transaction: tx);

        await tx.CommitAsync(ct);
    }
    catch
    {
        await tx.RollbackAsync(ct);
        throw;
    }
}
```

**Key rules:**
- Always pass `transaction: tx` to every Dapper call inside the transaction.
- Catch, rollback, and re-throw — never swallow exceptions.
- Use `SELECT ... FOR UPDATE` to prevent lost updates on rows being modified.
- Use `BeginTransactionAsync` / `CommitAsync` / `RollbackAsync` (async variants).

---

## 5. Multi-Mapping (Relationships)

When a query JOINs related tables, use multi-mapping to populate nested objects. The `splitOn` parameter tells Dapper where one type ends and the next begins.

```csharp
// Load listings with their embedded pet and breed data
var sql = @"
    SELECT l.*, p.*, pd.*
    FROM listings l
    JOIN pets p ON p.id = l.pet_id
    JOIN pet_dictionary pd ON pd.id = p.breed_id
    WHERE l.is_active = TRUE";

var listings = await conn.QueryAsync<ListingRow, PetRow, BreedRow, ListingRow>(
    sql,
    (listing, pet, breed) =>
    {
        pet.Breed = breed;
        listing.Pet = pet;
        return listing;
    },
    splitOn: "id,id");   // split at the second and third 'id' columns
```

**One-to-many** (trader with all their active bids):
```csharp
var sql = @"
    SELECT t.*, b.*
    FROM traders t
    LEFT JOIN bids b ON b.bidder_id = t.id AND b.status = 'active'
    WHERE t.id = @traderId";

var traderDict = new Dictionary<Guid, TraderRow>();

await conn.QueryAsync<TraderRow, BidRow?, TraderRow>(
    sql,
    (trader, bid) =>
    {
        if (!traderDict.TryGetValue(trader.Id, out var existing))
        {
            existing = trader;
            existing.ActiveBids = [];
            traderDict[trader.Id] = existing;
        }
        if (bid is not null)
            existing.ActiveBids.Add(bid);
        return existing;
    },
    new { traderId },
    splitOn: "id");

var trader = traderDict.Values.SingleOrDefault();
```

---

## 6. Multiple Result Sets

Use `QueryMultipleAsync` to fetch related data in a single round-trip — critical for trader dashboard which needs portfolio + notifications at once.

```csharp
public async Task<(TraderRow? Trader, IReadOnlyList<NotificationRow> Notifications)>
    GetTraderDashboardAsync(TraderId traderId, CancellationToken ct)
{
    var sql = @"
        SELECT * FROM traders WHERE id = @traderId;
        SELECT * FROM notifications WHERE trader_id = @traderId
          ORDER BY occurred_at DESC LIMIT 50;";

    await using var conn = await dataSource.OpenConnectionAsync(ct);
    await using var multi = await conn.QueryMultipleAsync(sql, new { traderId = traderId.Value });

    var trader = await multi.ReadSingleOrDefaultAsync<TraderRow>();
    var notifications = (await multi.ReadAsync<NotificationRow>()).ToList();

    return (trader, notifications);
}
```

---

## 7. Dynamic Parameters & Stored Procedures

```csharp
// Stored procedure with output parameter
public async Task<Guid> ExecuteTradeAsync(
    ListingId listingId, TraderId buyerId, CancellationToken ct)
{
    var parameters = new DynamicParameters();
    parameters.Add("@listing_id", listingId.Value);
    parameters.Add("@buyer_id", buyerId.Value);
    parameters.Add("@trade_id", dbType: DbType.Guid, direction: ParameterDirection.Output);

    await using var conn = await dataSource.OpenConnectionAsync(ct);
    await conn.ExecuteAsync(
        "execute_trade",
        parameters,
        commandType: CommandType.StoredProcedure);

    return parameters.Get<Guid>("@trade_id");
}
```

In this project, prefer inline parameterized SQL over stored procedures for most operations — easier to version-control, review, and debug. Use stored procedures only for complex multi-step operations already defined in the DB.

---

## 8. Buffered vs Unbuffered Queries

**Buffered (default):** all rows loaded into memory before returning. Use for most queries.

```csharp
// Buffered — safe to close connection before iterating
var listings = await conn.QueryAsync<ListingRow>(sql);
// Connection closed here, listings still accessible
foreach (var l in listings) { ... }
```

**Unbuffered:** rows streamed one at a time. Use for large exports (e.g., all trade history for analytics) where loading everything into memory would be wasteful.

```csharp
// Unbuffered — must keep connection open during iteration
await using var conn = await dataSource.OpenConnectionAsync(ct);
var trades = conn.QueryUnbufferedAsync<TradeRow>(
    "SELECT * FROM trades ORDER BY executed_at DESC",
    cancellationToken: ct);

await foreach (var trade in trades)
{
    await writer.WriteLineAsync(trade.ToCsv());
}
```

For the trading system's typical queries (market listings, leaderboard, notifications), always use buffered. Unbuffered is only for bulk data export endpoints.

---

## 9. Repository Pattern with Dapper

Encapsulate all SQL in repository classes. This keeps query strings out of service layer and enables the integration test pattern (see `unit-testing.md`).

```csharp
public interface IListingRepository
{
    Task<IReadOnlyList<Listing>> GetActiveListingsAsync(CancellationToken ct);
    Task<Listing?> GetByIdAsync(ListingId id, CancellationToken ct);
    Task SaveAsync(Listing listing, CancellationToken ct);
    Task WithdrawAsync(ListingId id, CancellationToken ct);
}

public sealed class ListingRepository(NpgsqlDataSource dataSource, IMapper mapper)
    : IListingRepository
{
    public async Task<IReadOnlyList<Listing>> GetActiveListingsAsync(CancellationToken ct)
    {
        var sql = @"
            SELECT l.*, p.*, pd.*
            FROM listings l
            JOIN pets p ON p.id = l.pet_id
            JOIN pet_dictionary pd ON pd.id = p.breed_id
            WHERE l.is_active = TRUE
            ORDER BY l.created_at DESC";

        await using var conn = await dataSource.OpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<ListingRow, PetRow, BreedRow, ListingRow>(
            sql,
            (listing, pet, breed) => { pet.Breed = breed; listing.Pet = pet; return listing; },
            splitOn: "id,id");

        return mapper.Map<IReadOnlyList<Listing>>(rows);
    }

    public async Task<Listing?> GetByIdAsync(ListingId id, CancellationToken ct)
    {
        await using var conn = await dataSource.OpenConnectionAsync(ct);
        var row = await conn.QuerySingleOrDefaultAsync<ListingRow>(
            "SELECT * FROM listings WHERE id = @id",
            new { id = id.Value });
        return row is null ? null : mapper.Map<Listing>(row);
    }
}
```

**Conventions:**
- Repository methods return domain entities (not rows/DTOs) — mapping happens inside the repo.
- Never expose `IDbConnection` or `IDbTransaction` outside the repository.
- Repository interfaces live in the domain/application layer; implementations in infrastructure.

---

## 10. Common Pitfalls

| Pitfall | Symptom | Fix |
|---|---|---|
| Missing `transaction:` parameter | Changes not rolled back on failure | Pass `transaction: tx` to every Dapper call in a transaction |
| `QuerySingle` on missing row | Unexpected `InvalidOperationException` in prod | Use `QuerySingleOrDefault` and handle `null` explicitly |
| String interpolation in SQL | SQL injection, hard-to-test queries | Always use `@param` syntax |
| Forgetting `cancellationToken:` | Request cancellation not propagated to DB | Pass `ct` to all async Dapper methods |
| Opening connection inside `using` without `await using` | Connection not returned to pool on exception | Use `await using var conn = await ...` |
| Mapping column name mismatches silently | Null properties in result | Add `DefaultTypeMap.MatchNamesWithUnderscores = true` at startup for snake_case columns |
| Large result sets buffered in memory | OOM on analytics queries | Use `QueryUnbufferedAsync` for large unbounded sets |
| N+1 queries in loops | Slow endpoints under load | Use JOIN + multi-mapping or `QueryMultiple` instead of looping single queries |

**PostgreSQL snake_case fix** (add once in `Program.cs`):
```csharp
DefaultTypeMap.MatchNamesWithUnderscores = true;
```
This makes Dapper map `asking_price` → `AskingPrice` automatically, avoiding manual column aliases on every query.
