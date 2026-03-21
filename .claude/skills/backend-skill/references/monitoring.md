# Monitoring & Observability Reference

## Structured Logging

Use `Microsoft.Extensions.Logging` with a JSON formatter for CloudWatch Logs.
Optionally add Serilog for enrichment (request ID, trade ID, environment).

### JSON Logging Setup

```csharp
builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(opts =>
{
    opts.IncludeScopes = true;
    opts.TimestampFormat = "O"; // ISO 8601
    opts.JsonWriterOptions = new JsonWriterOptions { Indented = false }; // single-line for CW
});
```

### Log Structure

Every log entry must include:
- `Timestamp` (ISO 8601)
- `Level` (Information/Warning/Error/Critical)
- `Message`
- `TraceId` (from X-Ray or ASP.NET Core)
- `RequestId`
- `TraderId` (when authenticated, via log scope)

```csharp
// Add traderId to all logs in the request scope
using (_logger.BeginScope(new Dictionary<string, object> { ["TraderId"] = traderId }))
{
    _logger.LogInformation("BidPlaced {ListingId} {Amount}", listingId, amount);
}
```

### Log Levels

| Level | Use case |
|---|---|
| `Debug` | Detailed SQL, request/response dumps (dev only, disable in prod) |
| `Information` | Business events: bid placed, trade executed, listing created |
| `Warning` | Recoverable issues: stale WS connection, DynamoDB retry, cache miss |
| `Error` | Unhandled exceptions, DB failures, downstream timeouts |
| `Critical` | System cannot serve requests; page on-call immediately |

Never log at `Debug` in production. Set minimum level to `Information` in prod.

---

## CloudWatch Metrics and Alarms

### Standard Metrics to Monitor

| Metric | Namespace | Alarm Threshold |
|---|---|---|
| API Gateway 5xx errors | `AWS/ApiGateway` | > 1% of requests over 5 min |
| API Gateway P99 latency | `AWS/ApiGateway` | > 1000 ms |
| ECS CPU utilization | `AWS/ECS` | > 80% sustained 10 min |
| ECS Memory utilization | `AWS/ECS` | > 85% |
| Lambda duration | `AWS/Lambda` | > 50,000 ms (50s of 55s limit) |
| Lambda error rate | `AWS/Lambda` | > 5% invocations |
| RDS CPU | `AWS/RDS` | > 80% sustained 5 min |
| RDS DB connections | `AWS/RDS` | > 80% of `max_connections` |
| DynamoDB throttled requests | `AWS/DynamoDB` | > 0 over 1 min |

### Custom Business Metrics

Emit custom metrics via `CloudWatch PutMetricData` API or embedded metric format (EMF):

```csharp
// Using CloudWatch Embedded Metric Format (emits structured log parsed by CW)
_logger.LogInformation("{_aws: {Metrics: [{Name: 'TradeExecuted', Unit: 'Count'}], Namespace: 'PetsTrading'}, TradeExecuted: 1, ListingId: {ListingId}}",
    listingId);
```

Recommended custom metrics:
- `TradeExecuted` (count per minute)
- `BidPlaced` (count per minute)
- `ActiveListingsCount` (gauge, from `/metrics` endpoint or scheduled Lambda)
- `LifecycleTick.Duration` (milliseconds, from Lifecycle Lambda)
- `LifecycleTick.PetsUpdated` (count per tick)
- `WebSocketPushFailures` (count — GoneException on push)

---

## X-Ray Distributed Tracing

### Setup in Trading API

```csharp
// NuGet: AWSXRayRecorder.Handlers.AspNetCore
builder.Services.AddAWSXRayForWebApp();

app.UseXRay("PetsTrading-API");
```

This automatically traces all incoming HTTP requests as X-Ray segments.

### Instrument Dapper Calls

Wrap Dapper calls in subsegments to see DB query timing in X-Ray:

```csharp
public async Task<IEnumerable<Listing>> GetActiveListingsAsync(CancellationToken ct)
{
    return await AWSXRayRecorder.Instance.TraceMethodAsync("dapper.query.listings", async () =>
    {
        await using var conn = await _dataSource.OpenConnectionAsync(ct);
        return await conn.QueryAsync<Listing>(
            "SELECT * FROM listings WHERE is_active = TRUE ORDER BY created_at DESC LIMIT 100");
    });
}
```

### Instrument Lambda

```csharp
// Lambda: add subsegment for the full tick
AWSXRayRecorder.Instance.BeginSubsegment("lifecycle.tick");
try
{
    await RunTickAsync(ct);
    AWSXRayRecorder.Instance.EndSubsegment();
}
catch (Exception ex)
{
    AWSXRayRecorder.Instance.AddException(ex);
    AWSXRayRecorder.Instance.EndSubsegment();
    throw;
}
```

Set `AWS_XRAY_DAEMON_ADDRESS` environment variable in ECS task and Lambda to point at the
X-Ray daemon sidecar (ECS) or built-in Lambda X-Ray integration.

---

## Health Check Endpoints

Expose two endpoints per ADR decisions:

- `GET /health` — liveness: returns `200` if the process is running. No external checks.
- `GET /ready` — readiness: returns `200` only if DB is reachable; `503` otherwise.

```csharp
builder.Services.AddHealthChecks()
    .AddNpgSql(connStr, name: "postgres", failureStatus: HealthStatus.Unhealthy, tags: ["ready"])
    .AddCheck("self", () => HealthCheckResult.Healthy(), tags: ["live"]);

app.MapHealthChecks("/health", new HealthCheckOptions
{
    Predicate = r => r.Tags.Contains("live"),
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});
app.MapHealthChecks("/ready", new HealthCheckOptions
{
    Predicate = r => r.Tags.Contains("ready"),
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});
```

ECS uses `/health` for container health. ALB uses `/ready` for target group health.

---

## CloudWatch Dashboards

Create one dashboard per environment (`pettrading-prod`, `pettrading-staging`).

Widgets to include:
1. **API Requests** — request count, 4xx rate, 5xx rate (time series)
2. **API Latency** — P50, P95, P99 (time series)
3. **ECS** — CPU and memory utilization per service
4. **Lambda Lifecycle** — invocation count, duration, errors, throttles
5. **RDS** — CPU, connections, read/write IOPS, free storage
6. **Business KPIs** — TradeExecuted, BidPlaced, ActiveListings (custom metrics)
7. **Alarms** — alarm state widget showing all configured alarms

---

## Lambda Cold Start Monitoring

Cold starts occur when a new Lambda container is initialized. For the Lifecycle Lambda
(runs every 60s), cold starts should be rare once warm.

Monitor with CloudWatch Insights query:

```
filter @type = "REPORT"
| stats avg(@initDuration) as avgInit, max(@initDuration) as maxInit,
        avg(@duration) as avgDuration by bin(5m)
```

If `@initDuration` appears frequently (> 10% of invocations), consider:
1. Reducing Lambda package size (trim unused NuGet packages).
2. Using provisioned concurrency if tick latency SLA requires it.

---

## RDS Performance Insights

Enable Performance Insights in the RDS Terraform resource (see `aws-infrastructure.md`).

Key queries to watch in Performance Insights:
- Any query with wait event `Lock:relation` or `Lock:tuple` — indicates transaction contention.
- Slow queries appearing in `pg_stat_activity` — set `log_min_duration_statement = 1000` (ms).
- Top SQL by `total_time` — candidates for index improvements.

Create a CloudWatch alarm on `DatabaseConnections` metric approaching `max_connections`.
Set PostgreSQL `max_connections = 100`; ECS tasks pool max 20 each; with 2 tasks and Lambda
that's ~41 connections max — well within limit.

---

## Alert Escalation

| Severity | Examples | Action |
|---|---|---|
| Critical | All ECS tasks unhealthy, DB down, Lambda failing every tick | Page on-call immediately |
| High | 5xx rate > 5%, Lambda error rate > 20%, RDS CPU > 90% | Alert within 5 min, acknowledge within 15 min |
| Medium | P99 latency degraded, Lambda cold starts > 20%, DynamoDB throttling | Alert within 15 min |
| Low | Individual WebSocket push failure, slow query logged | Review in next business day |

Configure SNS topics and CloudWatch Alarm actions for paging integration (PagerDuty or similar).
