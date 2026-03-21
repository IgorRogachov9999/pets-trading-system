# Microservices & Architecture Reference

## Service Boundary Decisions

The system has three services. Keep them strictly separated.

| Service | Responsibility | Technology |
|---|---|---|
| **Trading API** | All business logic: listings, bids, trades, supply, portfolio, leaderboard, notifications, WebSocket push | ECS Fargate, .NET 10 |
| **Lifecycle Lambda** | Background tick only: read all pets, apply ±5% variance to health/desirability, recalculate `intrinsic_value`, update `pets.age` cache and `is_expired` | Lambda, EventBridge Scheduler |
| **React SPA** | UI only: polls REST every 5s; receives WebSocket notifications | S3 + CloudFront |

The Lifecycle Lambda has **no business logic** — it is a data maintenance tick. It never pushes
events. The Trading API has **no scheduled work** — all business actions are request-driven.

Do not add a fourth service without an ADR.

---

## Bounded Contexts (DDD)

Map each context to a namespace/folder in the Trading API codebase:

| Bounded Context | Key Aggregates | Repository |
|---|---|---|
| **Traders** | `Trader` (cash, inventory, notifications) | `ITraderRepository` |
| **Pets** | `Pet` (breed, health, desirability, age, intrinsicValue) | `IPetRepository` |
| **Market** | `Listing` (askingPrice, active), `Bid` (amount, status) | `IListingRepository`, `IBidRepository` |
| **Trades** | `Trade` (price, buyer, seller, pet, timestamp) | `ITradeRepository` |
| **Supply** | `SupplyInventory` (breed, count) | `ISupplyRepository` |

Aggregates do not directly reference objects from other bounded contexts — use IDs.
Cross-context operations go through the service layer, not across repositories.

---

## Event-Driven Patterns — WebSocket Notifications

The Trading API pushes notifications **synchronously within the same request transaction**
after committing the DB transaction. No message queue or separate event bus is used.

### Notification Push Flow

```
HTTP Request → Service Layer → Begin DB Transaction
                                 → Execute financial mutation
                                 → Insert notification rows
                               → Commit DB Transaction
                             → Lookup connectionId from DynamoDB
                             → POST to API Gateway Management API
                             → Return HTTP response
```

If the WebSocket push fails (stale connection, `GoneException`), log the error and continue —
the notification row is already persisted in PostgreSQL; the frontend will load it on next poll.

### Notification Service Interface

```csharp
public interface INotificationService
{
    Task PushAsync(Guid traderId, WebSocketEvent evt, CancellationToken ct);
}

public record WebSocketEvent(string EventType, Guid? PetId, string PetName,
    decimal? Amount, string? CounterpartyName, DateTimeOffset Timestamp);
```

---

## Inter-Service Communication

- **Trading API ↔ RDS**: Dapper over Npgsql (synchronous-style async SQL).
- **Trading API ↔ DynamoDB**: AWS SDK v3 (`AmazonDynamoDBClient`), async.
- **Trading API ↔ API Gateway Management API**: AWS SDK (`AmazonApiGatewayManagementApiClient`).
- **Lifecycle Lambda ↔ RDS**: Dapper over Npgsql (same pattern, no connection pooling across invocations — use min pool size 1).
- **React SPA ↔ Trading API**: REST over HTTPS (polling 5s) + WebSocket (notifications).

There is no direct communication between the Lifecycle Lambda and the Trading API.

---

## Circuit Breaker / Retry Patterns

Use `Polly` for resilience on all outbound calls from the Trading API.

### DynamoDB Retry

```csharp
var retryPolicy = Policy
    .Handle<AmazonDynamoDBException>(ex => ex.StatusCode == HttpStatusCode.ServiceUnavailable
        || ex.StatusCode == HttpStatusCode.InternalServerError)
    .WaitAndRetryAsync(3, attempt => TimeSpan.FromMilliseconds(100 * Math.Pow(2, attempt)),
        (ex, delay, attempt, ctx) =>
            _logger.LogWarning("DynamoDB retry {Attempt} after {Delay}ms: {Error}", attempt, delay.TotalMilliseconds, ex.Message));
```

### Secrets Manager (startup only)

Retry up to 5 times with exponential backoff. Application should not start if secrets
cannot be loaded after retries.

### PostgreSQL

Npgsql has built-in reconnect. Layer a Polly retry for transient `NpgsqlException` errors
with `SqlState` in `{ "08000", "08003", "08006", "57P03" }`.

---

## Graceful Shutdown (ECS Fargate)

ECS sends `SIGTERM` 30 seconds before `SIGKILL`. Handle it to drain in-flight requests.

```csharp
var lifetime = app.Services.GetRequiredService<IHostApplicationLifetime>();
lifetime.ApplicationStopping.Register(() =>
{
    _logger.LogInformation("Received SIGTERM — beginning graceful shutdown");
    // Allow current requests to complete; new connections rejected by ALB deregistration
});

app.Run(); // Respects cancellation from SIGTERM
```

ASP.NET Core's `IHostApplicationLifetime` integrates with the OS signal automatically.
Set ECS `stopTimeout` to 30 seconds in the task definition.

---

## Idempotency for Financial Operations

Bid placement and supply purchase are the primary retry targets. Accept an `Idempotency-Key` header.

```csharp
app.MapPost("/v1/listings/{id}/bids", async (
    [FromHeader(Name = "Idempotency-Key")] string? idempotencyKey,
    Guid id, PlaceBidRequest req, IBidService bidService, ...) =>
{
    if (idempotencyKey is not null)
    {
        var cached = await idempotencyStore.GetAsync(idempotencyKey, ct);
        if (cached is not null) return cached; // return previous response
    }

    var result = await bidService.PlaceBidAsync(id, req, traderId, ct);

    if (idempotencyKey is not null)
        await idempotencyStore.SetAsync(idempotencyKey, result, TimeSpan.FromMinutes(5), ct);

    return result;
});
```

Use DynamoDB as the idempotency store (TTL 5 minutes).

---

## CQRS — Where Applicable

Apply a lightweight CQRS split for the Market and Leaderboard views:

- **Commands** (writes): PlaceBid, CreateListing, WithdrawListing, AcceptBid, PurchaseSupply — run inside transactions, enforce business rules.
- **Queries** (reads): GetMarketView, GetLeaderboard, GetTraderPortfolio — read-only, can return cached/denormalized data.

Do not use a full CQRS framework (MediatR is optional). A simple pattern of separate
`ICommandService` and `IQueryService` interfaces is sufficient.

---

## Distributed Tracing with X-Ray

Instrument the full request path: API Gateway → ECS → RDS → DynamoDB.

```csharp
// Program.cs
builder.Services.AddAWSXRay();  // Amazon.XRay.Recorder.Handlers.AspNetCore

app.UseXRay("PetsTrading-API");

// Instrument Dapper calls as subsegments
AWSXRayRecorder.Instance.BeginSubsegment("dapper.query.listings");
try
{
    var listings = await conn.QueryAsync<Listing>(...);
    AWSXRayRecorder.Instance.EndSubsegment();
    return listings;
}
catch
{
    AWSXRayRecorder.Instance.EndSubsegment();
    throw;
}
```

Propagate the `X-Amzn-Trace-Id` header from API Gateway automatically via the X-Ray SDK.
The Lifecycle Lambda is instrumented separately via `AWSXRayRecorder`.
