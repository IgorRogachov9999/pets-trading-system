# .NET 10 / ASP.NET Core Reference

## Minimal APIs (Preferred Pattern)

Prefer Minimal APIs over MVC Controllers. Keep route handlers thin — delegate to service classes.

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddScoped<IListingService, ListingService>();

var app = builder.Build();
app.UseExceptionHandler();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/v1/listings", async (IListingService svc, CancellationToken ct) =>
    Results.Ok(await svc.GetActiveListingsAsync(ct)))
   .RequireAuthorization();

app.Run();
```

Organize related endpoints with `RouteGroupBuilder`:

```csharp
var listings = app.MapGroup("/v1/listings").RequireAuthorization();
listings.MapGet("/", GetListings);
listings.MapPost("/", CreateListing);
listings.MapDelete("/{id}", WithdrawListing);
```

---

## Dapper Patterns (No EF Core)

### Basic Query

```csharp
public async Task<Listing?> GetListingAsync(Guid listingId, CancellationToken ct)
{
    await using var conn = await _dataSource.OpenConnectionAsync(ct);
    return await conn.QuerySingleOrDefaultAsync<Listing>(
        "SELECT * FROM listings WHERE id = @Id AND is_active = TRUE",
        new { Id = listingId });
}
```

### Parameterized Insert

```csharp
await conn.ExecuteAsync(
    @"INSERT INTO listings (id, pet_id, trader_id, asking_price, created_at)
      VALUES (@Id, @PetId, @TraderId, @AskingPrice, NOW())",
    new { Id = Guid.NewGuid(), PetId = petId, TraderId = traderId, AskingPrice = price });
```

### Transactions (required for financial ops)

```csharp
await using var conn = await _dataSource.OpenConnectionAsync(ct);
await using var tx = await conn.BeginTransactionAsync(ct);
try
{
    // 1. Lock the listing row
    var listing = await conn.QuerySingleOrDefaultAsync<Listing>(
        "SELECT * FROM listings WHERE id = @Id FOR UPDATE",
        new { Id = listingId }, transaction: tx);

    // 2. Reject previous bid, lock bidder cash, insert new bid
    await conn.ExecuteAsync("UPDATE bids SET status = 'outbid' WHERE listing_id = @Id AND status = 'active'",
        new { Id = listingId }, transaction: tx);
    await conn.ExecuteAsync(
        "UPDATE traders SET available_cash = available_cash - @Amount, locked_cash = locked_cash + @Amount WHERE id = @TraderId",
        new { Amount = amount, TraderId = bidderId }, transaction: tx);
    await conn.ExecuteAsync(
        "INSERT INTO bids (id, listing_id, trader_id, amount, status, created_at) VALUES (@Id, @ListingId, @TraderId, @Amount, 'active', NOW())",
        new { Id = Guid.NewGuid(), ListingId = listingId, TraderId = bidderId, Amount = amount }, transaction: tx);

    await tx.CommitAsync(ct);
}
catch
{
    await tx.RollbackAsync(ct);
    throw;
}
```

### Multi-Mapping

```csharp
var result = await conn.QueryAsync<Listing, Pet, Listing>(
    @"SELECT l.*, p.* FROM listings l JOIN pets p ON p.id = l.pet_id WHERE l.is_active = TRUE",
    (listing, pet) => { listing.Pet = pet; return listing; },
    splitOn: "id");
```

---

## Connection Pooling with NpgsqlDataSource

Register once at startup; inject `NpgsqlDataSource` everywhere:

```csharp
builder.Services.AddNpgsqlDataSource(connectionString);
// Then inject:
// public ListingRepository(NpgsqlDataSource dataSource) => _dataSource = dataSource;
```

Never instantiate `NpgsqlConnection` directly — always use `_dataSource.OpenConnectionAsync()`.

---

## Dependency Injection Patterns

- `AddScoped` for services that touch the DB (one per HTTP request).
- `AddSingleton` for stateless infrastructure (HTTP clients, config wrappers).
- `AddTransient` for lightweight, stateless helpers.
- Use constructor injection exclusively — no `IServiceLocator` or `HttpContext.RequestServices`.

---

## async/await Best Practices

- Every I/O method returns `Task` or `Task<T>` — never `async void` in production code.
- Pass `CancellationToken` from the HTTP request down through every async call chain.
- Use `ConfigureAwait(false)` in infrastructure/library code (repositories, clients).
- Omit `ConfigureAwait` in ASP.NET Core request handlers (no `SynchronizationContext`).
- Do not call `.Result` or `.Wait()` — it causes deadlocks.

---

## Global Error Handling + Problem Details

```csharp
builder.Services.AddProblemDetails();
app.UseExceptionHandler(exApp => exApp.Run(async ctx =>
{
    var feature = ctx.Features.Get<IExceptionHandlerFeature>();
    var ex = feature?.Error;
    var problem = ex switch
    {
        ValidationException v => new ProblemDetails { Status = 400, Title = "Validation failed", Detail = v.Message },
        BusinessRuleException b => new ProblemDetails { Status = 422, Title = "Business rule violation", Detail = b.Message },
        NotFoundException   n => new ProblemDetails { Status = 404, Title = "Not found", Detail = n.Message },
        _ => new ProblemDetails { Status = 500, Title = "An unexpected error occurred" }
    };
    problem.Instance = ctx.Request.Path;
    ctx.Response.StatusCode = problem.Status ?? 500;
    await ctx.Response.WriteAsJsonAsync(problem, ct: ctx.RequestAborted);
}));
```

Always return `application/problem+json` (RFC 7807) — never return plain text errors.

---

## JWT Validation from Cognito

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = $"https://cognito-idp.{region}.amazonaws.com/{userPoolId}";
        options.Audience = clientId;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true
        };
    });
```

Extract `traderId` from the `sub` claim or a custom Cognito attribute claim.

---

## Configuration + AWS Secrets Manager

```csharp
builder.Configuration.AddSecretsManager(region: RegionEndpoint.GetBySystemName(awsRegion),
    configurator: options =>
    {
        options.SecretFilter = entry => entry.Name.StartsWith("pettrading/");
        options.KeyGenerator = (_, key) => key.Replace("pettrading/", "").Replace("/", ":");
    });
```

Access via `IConfiguration["Database:Password"]` — never via environment variables for secrets.

---

## Health Checks

```csharp
builder.Services.AddHealthChecks()
    .AddNpgSql(connectionString, name: "postgres", tags: ["ready"])
    .AddCheck("self", () => HealthCheckResult.Healthy(), tags: ["live"]);

app.MapHealthChecks("/health", new HealthCheckOptions { Predicate = r => r.Tags.Contains("live") });
app.MapHealthChecks("/ready",  new HealthCheckOptions { Predicate = r => r.Tags.Contains("ready") });
```

ECS healthcheck: `CMD-SHELL curl -f http://localhost:8080/health || exit 1`.

---

## Docker Multi-Stage Build for .NET 10

```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY ["PetsTrading.Api/PetsTrading.Api.csproj", "PetsTrading.Api/"]
RUN dotnet restore "PetsTrading.Api/PetsTrading.Api.csproj"
COPY . .
RUN dotnet publish "PetsTrading.Api/PetsTrading.Api.csproj" -c Release -o /app/publish --no-restore

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
RUN adduser --disabled-password --gecos "" appuser && chown -R appuser /app
USER appuser
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "PetsTrading.Api.dll"]
```

- Pin SDK and runtime to the same version.
- Run as non-root (`appuser`).
- No TLS in container — ALB handles TLS offload.

---

## Lambda Function Handler Pattern (.NET 10)

For the Lifecycle Lambda, implement a minimal handler:

```csharp
// LambdaFunction.cs
[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

public class LifecycleHandler
{
    private readonly ILifecycleService _service;

    public LifecycleHandler()
    {
        // Manual DI bootstrap for Lambda cold start
        var services = new ServiceCollection();
        services.AddNpgsqlDataSource(GetConnectionString());
        services.AddScoped<ILifecycleService, LifecycleService>();
        _service = services.BuildServiceProvider().GetRequiredService<ILifecycleService>();
    }

    public async Task FunctionHandler(ILambdaContext context)
    {
        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(50)); // EventBridge fires every 60s
        await _service.RunTickAsync(cts.Token);
    }
}
```

Use `Amazon.Lambda.AspNetCoreServer.Hosting` when Lambda is fronting an HTTP API via API Gateway proxy integration.
