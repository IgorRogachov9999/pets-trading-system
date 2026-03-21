# Security Reference

## OWASP Top 10 for .NET / ASP.NET Core

| Risk | Mitigation in this project |
|---|---|
| A01 Broken Access Control | Authorize every endpoint; enforce `traderId == sub` for private data |
| A02 Cryptographic Failures | TLS on ALB; encrypted RDS storage; Secrets Manager for credentials |
| A03 Injection | Dapper parameterized queries only — zero string concatenation in SQL |
| A04 Insecure Design | RFC 7807 errors; no stack traces in responses; business rule enforcement |
| A05 Security Misconfiguration | WAF on API Gateway; security groups restrict DB to app subnets only |
| A06 Vulnerable Components | Dependabot + `dotnet list package --vulnerable` in CI |
| A07 Auth Failures | Cognito JWT validation; token expiry enforced; HTTPS only |
| A08 Software Integrity | ECR image scanning on push; OIDC-based CI/CD (no static keys) |
| A09 Logging/Monitoring | Structured audit logs for every financial mutation; CloudWatch alarms |
| A10 SSRF | No outbound HTTP to user-supplied URLs; all external calls are to known AWS endpoints |

---

## SQL Injection Prevention

Dapper parameterization is the sole line of defense — always use it.

```csharp
// CORRECT — parameterized
await conn.QueryAsync<Listing>(
    "SELECT * FROM listings WHERE seller_id = @SellerId AND is_active = TRUE",
    new { SellerId = traderId });

// WRONG — never do this
await conn.QueryAsync<Listing>(
    $"SELECT * FROM listings WHERE seller_id = '{traderId}'");
```

- Never pass raw user input into `QueryAsync` or `ExecuteAsync` as inline SQL.
- Use `@Param` placeholders for all values, including GUIDs, booleans, and numeric types.
- Review all Dapper calls in code review for interpolation or concatenation.

---

## JWT Validation from Cognito

Validate every field. A missing or forged token must return `401`.

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = $"https://cognito-idp.{region}.amazonaws.com/{userPoolId}";
        options.Audience  = cognitoClientId;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer           = true,
            ValidIssuer              = $"https://cognito-idp.{region}.amazonaws.com/{userPoolId}",
            ValidateAudience         = true,
            ValidAudience            = cognitoClientId,
            ValidateLifetime         = true,
            ValidateIssuerSigningKey = true,
            ClockSkew                = TimeSpan.FromSeconds(30)
        };
    });
```

### Extracting `traderId`

```csharp
var traderId = Guid.Parse(httpContext.User.FindFirstValue("sub")
    ?? throw new UnauthorizedException("Missing sub claim"));
```

Always read `sub` from the validated token claims — never from a request body or query param.

### WebSocket JWT Validation

Pass JWT as query parameter on connect; API Gateway Cognito authorizer validates it before
invoking the `$connect` Lambda/route. The `requestContext.authorizer.claims.sub` is available
in the connection event.

---

## Input Validation

Use FluentValidation at the API boundary. Reject before hitting the service layer.

```csharp
public class CreateListingValidator : AbstractValidator<CreateListingRequest>
{
    public CreateListingValidator()
    {
        RuleFor(x => x.PetId).NotEmpty();
        RuleFor(x => x.AskingPrice).GreaterThan(0);
    }
}

// Register
builder.Services.AddValidatorsFromAssemblyContaining<CreateListingValidator>();

// Use in endpoint
app.MapPost("/v1/listings", async (CreateListingRequest req,
    IValidator<CreateListingValidator> validator, ...) =>
{
    var result = await validator.ValidateAsync(req);
    if (!result.IsValid)
        return Results.ValidationProblem(result.ToDictionary());
    ...
});
```

- Reject unknown JSON fields with `JsonUnmappedMemberHandling.Disallow`.
- Validate all path parameters (e.g., ensure `{id}` parses as `Guid`).
- Clamp numeric ranges at the API level; don't rely on DB check constraints alone.

---

## CORS Configuration

Allow only the CloudFront distribution origin. Never use `AllowAnyOrigin` in production.

```csharp
builder.Services.AddCors(opts => opts.AddDefaultPolicy(policy =>
    policy.WithOrigins("https://d1234abcd.cloudfront.net", "https://pettrading.example.com")
          .AllowAnyMethod()
          .AllowAnyHeader()
          .AllowCredentials()));

app.UseCors();
```

Restrict to the exact CloudFront URL. Update when adding custom domains.

---

## Rate Limiting

Layer 1 — API Gateway usage plan throttling (1000 burst / 500 steady req/s).

Layer 2 — Application-level per-trader rate limiting on write operations:

```csharp
builder.Services.AddRateLimiter(opts =>
{
    opts.AddSlidingWindowLimiter("bids", policy =>
    {
        policy.PermitLimit = 10;
        policy.Window = TimeSpan.FromMinutes(1);
        policy.SegmentsPerWindow = 6;
        policy.QueueLimit = 0;
    });
});

app.MapPost("/v1/listings/{id}/bids", PlaceBid)
   .RequireRateLimiting("bids");
```

Return `429` with `Retry-After` header on limit exceeded.

---

## Secrets Management

- Never store secrets in environment variables, appsettings.json, or source control.
- Load from Secrets Manager at startup via the configuration provider.
- Use IAM roles (ECS task role, Lambda execution role) for passwordless Secrets Manager access.
- Rotate secrets using Secrets Manager rotation Lambdas.
- Audit Secrets Manager access via CloudTrail.

```csharp
// Never do this
var connStr = Environment.GetEnvironmentVariable("DB_PASSWORD"); // WRONG

// Always do this
var connStr = configuration["Database:ConnectionString"]; // loaded from Secrets Manager
```

---

## Authentication vs. Authorization

| Concept | Implementation |
|---|---|
| Authentication | Cognito JWT validated by `AddJwtBearer` |
| Identity | `sub` claim maps to `trader.cognito_sub` |
| Authorization | `[Authorize]` / `RequireAuthorization()` on all endpoints |
| Ownership | Service layer checks `traderId == resource.ownerId` |

Ownership checks must happen in the **service layer**, not just route protection:

```csharp
// In ListingService
if (listing.SellerId != requestingTraderId)
    throw new ForbiddenException("You do not own this listing.");
```

Do not expose a trader's `availableCash`, `lockedCash`, or `notifications` to any other trader.

---

## Audit Logging for Financial Operations

Every financial mutation must emit a structured audit log entry:

```csharp
_logger.LogInformation(
    "BidPlaced {ListingId} {BidderId} {Amount} {PreviousBidderId}",
    listingId, bidderId, amount, previousBidderId);
```

Log to CloudWatch Logs with `eventType` field so logs can be filtered and alarmed on.

Required audit events:
- `BidPlaced` (listingId, bidderId, amount)
- `BidReplaced` (listingId, newBidderId, newAmount, outbidTraderId, refundAmount)
- `BidWithdrawn` (listingId, bidderId, refundAmount)
- `TradeExecuted` (tradeId, listingId, petId, buyerId, sellerId, price)
- `ListingWithdrawn` (listingId, sellerId, activeBidRefunded)
- `SupplyPurchased` (petId, buyerId, price)

Never log JWT tokens, full SQL, or passwords.

---

## Preventing Bid Manipulation and Race Conditions

- All bid placement runs inside a PostgreSQL transaction with `SELECT ... FOR UPDATE`.
- The service layer enforces:
  - Bidder cannot be the listing owner (`bid.bidderId != listing.sellerId`).
  - Bid amount must be ≤ bidder's `availableCash` at the time of transaction.
  - Only one active bid per listing at any time (enforced by transaction + update).
- Sequential request processing is sufficient (no Redis locks needed per ADR design).
- Idempotency: accept an `Idempotency-Key` header for bid placement; store in a short-lived
  cache (DynamoDB with 5-minute TTL) to prevent duplicate bids on client retries.

```csharp
var existingKey = await _idempotencyStore.GetAsync(idempotencyKey, ct);
if (existingKey is not null)
    return existingKey.Response; // return cached response, do not re-execute
```

---

## Security Headers

Add to all API responses via middleware:

```csharp
app.Use(async (ctx, next) =>
{
    ctx.Response.Headers["X-Content-Type-Options"] = "nosniff";
    ctx.Response.Headers["X-Frame-Options"] = "DENY";
    ctx.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
    ctx.Response.Headers["Permissions-Policy"] = "geolocation=(), microphone=()";
    await next();
});
```

HTTPS is enforced at the ALB level; `Strict-Transport-Security` is set by CloudFront on the
SPA distribution.
