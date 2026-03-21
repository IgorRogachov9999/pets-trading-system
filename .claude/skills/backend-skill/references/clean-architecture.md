# Clean Architecture with CQRS — .NET 10, Dapper, Minimal APIs

## Project Structure

This project uses Clean Architecture with light CQRS (MediatR) and Dapper for data access. Note: **no EF Core** — all DB access goes through Dapper + parameterized SQL.

```
PetsTrading.sln
├── src/
│   ├── PetsTrading.Domain/              # Core business logic — zero dependencies
│   │   ├── Entities/
│   │   │   ├── Trader.cs
│   │   │   ├── Pet.cs
│   │   │   ├── Listing.cs
│   │   │   ├── Bid.cs
│   │   │   └── Trade.cs
│   │   ├── ValueObjects/
│   │   │   ├── TraderId.cs             # Branded value types
│   │   │   ├── PetId.cs
│   │   │   ├── ListingId.cs
│   │   │   └── Money.cs
│   │   ├── Exceptions/
│   │   │   ├── DomainException.cs
│   │   │   ├── InsufficientFundsException.cs
│   │   │   └── BidTooLowException.cs
│   │   └── Interfaces/                 # Repository contracts (no I/O implementation)
│   │       ├── ITraderRepository.cs
│   │       ├── IListingRepository.cs
│   │       └── IPetRepository.cs
│   │
│   ├── PetsTrading.Application/         # Use cases — depends on Domain only
│   │   ├── Traders/
│   │   │   ├── Commands/
│   │   │   │   └── PlaceBid/
│   │   │   │       ├── PlaceBidCommand.cs
│   │   │   │       ├── PlaceBidCommandHandler.cs
│   │   │   │       └── PlaceBidCommandValidator.cs
│   │   │   └── Queries/
│   │   │       └── GetPortfolio/
│   │   │           ├── GetPortfolioQuery.cs
│   │   │           └── GetPortfolioQueryHandler.cs
│   │   ├── Listings/
│   │   │   ├── Commands/
│   │   │   └── Queries/
│   │   ├── Common/
│   │   │   ├── Behaviors/
│   │   │   │   ├── ValidationBehavior.cs
│   │   │   │   └── LoggingBehavior.cs
│   │   │   ├── Models/
│   │   │   │   └── PagedResult.cs
│   │   │   └── Interfaces/
│   │   │       └── INotificationService.cs
│   │   └── DependencyInjection.cs
│   │
│   ├── PetsTrading.Infrastructure/      # Dapper repos, AWS clients — depends on Application
│   │   ├── Persistence/
│   │   │   ├── Repositories/
│   │   │   │   ├── TraderRepository.cs
│   │   │   │   ├── ListingRepository.cs
│   │   │   │   └── PetRepository.cs
│   │   │   └── Migrations/             # Plain SQL files: 20240101_create_traders.sql
│   │   ├── Notifications/
│   │   │   └── WebSocketNotificationService.cs
│   │   └── DependencyInjection.cs
│   │
│   └── PetsTrading.Api/                 # Minimal API endpoints — depends on Application
│       ├── Endpoints/
│       │   ├── TraderEndpoints.cs
│       │   ├── ListingEndpoints.cs
│       │   └── MarketEndpoints.cs
│       ├── Middleware/
│       │   └── ExceptionHandlingMiddleware.cs
│       └── Program.cs
│
├── tests/
│   ├── PetsTrading.Domain.Tests/        # Pure domain logic — no I/O
│   ├── PetsTrading.Application.Tests/   # Service/handler tests — mock repos
│   ├── PetsTrading.Api.Tests/           # Endpoint integration tests
│   └── PetsTrading.Infrastructure.Tests/# Dapper repos vs real PostgreSQL (Testcontainers)
│
└── lambda/
    └── PetsTrading.LifecycleLambda/     # Lambda function — separate project
        ├── Function.cs
        └── PetsTrading.LifecycleLambda.csproj
```

---

## Domain Layer

The domain layer has **zero dependencies** on infrastructure, frameworks, or I/O. Pure C# with business logic in entity methods.

```csharp
// Domain/Entities/Trader.cs
namespace PetsTrading.Domain.Entities;

public sealed class Trader
{
    public TraderId Id { get; private set; }
    public string DisplayName { get; private set; }
    public decimal AvailableCash { get; private set; }
    public decimal LockedCash { get; private set; }
    public IReadOnlyList<Pet> Inventory => _inventory.AsReadOnly();

    private readonly List<Pet> _inventory = [];

    private Trader() { } // for Dapper materialisation

    public static Trader Create(TraderId id, string displayName)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(displayName);
        return new Trader
        {
            Id = id,
            DisplayName = displayName,
            AvailableCash = 150m,   // ADR: starting cash fixed at $150
            LockedCash = 0m
        };
    }

    public void PlaceBid(Listing listing, decimal amount)
    {
        if (listing.OwnerId == Id)
            throw new DomainException("Traders cannot bid on their own listings.");

        if (amount <= 0)
            throw new ArgumentOutOfRangeException(nameof(amount), "Bid amount must be positive.");

        if (amount > AvailableCash)
            throw new InsufficientFundsException(amount, AvailableCash);

        AvailableCash -= amount;
        LockedCash += amount;
    }

    public void ReleaseLockedCash(decimal amount)
    {
        LockedCash -= amount;
        AvailableCash += amount;
    }

    public decimal CalculatePortfolioValue()
        => AvailableCash + LockedCash + _inventory.Sum(p => p.CalculateIntrinsicValue());
}
```

---

## Application Layer — Commands

Commands mutate state. Use MediatR `IRequest<TResponse>`. Each command has a handler and a FluentValidation validator in the same folder.

```csharp
// Application/Traders/Commands/PlaceBid/PlaceBidCommand.cs
public record PlaceBidCommand(
    TraderId BidderId,
    ListingId ListingId,
    decimal Amount
) : IRequest<BidDto>;

// Application/Traders/Commands/PlaceBid/PlaceBidCommandHandler.cs
public sealed class PlaceBidCommandHandler(
    ITraderRepository traderRepo,
    IListingRepository listingRepo,
    INotificationService notifications)
    : IRequestHandler<PlaceBidCommand, BidDto>
{
    public async Task<BidDto> Handle(PlaceBidCommand request, CancellationToken ct)
    {
        var trader = await traderRepo.GetByIdAsync(request.BidderId, ct)
            ?? throw new NotFoundException(nameof(Trader), request.BidderId);

        var listing = await listingRepo.GetByIdAsync(request.ListingId, ct)
            ?? throw new NotFoundException(nameof(Listing), request.ListingId);

        // Domain validates rules — throws DomainException if invalid
        trader.PlaceBid(listing, request.Amount);

        // Infrastructure handles atomic DB operations (Dapper transaction)
        var bid = await listingRepo.ReplaceBidAsync(
            listing, trader.Id, request.Amount, ct);

        // Push WebSocket notification after successful commit
        await notifications.SendBidReceivedAsync(listing.OwnerId, bid, ct);

        return new BidDto(bid.Id.Value, request.Amount, BidStatus.Active);
    }
}

// Application/Traders/Commands/PlaceBid/PlaceBidCommandValidator.cs
public sealed class PlaceBidCommandValidator : AbstractValidator<PlaceBidCommand>
{
    public PlaceBidCommandValidator()
    {
        RuleFor(x => x.Amount).GreaterThan(0).LessThan(1_000_000);
        RuleFor(x => x.ListingId).NotEmpty();
        RuleFor(x => x.BidderId).NotEmpty();
    }
}
```

---

## Application Layer — Queries

Queries read state, return DTOs, never mutate domain entities.

```csharp
// Application/Traders/Queries/GetPortfolio/GetPortfolioQuery.cs
public record GetPortfolioQuery(TraderId TraderId) : IRequest<TraderPortfolioDto>;

// Application/Traders/Queries/GetPortfolio/GetPortfolioQueryHandler.cs
public sealed class GetPortfolioQueryHandler(ITraderRepository traderRepo, IMapper mapper)
    : IRequestHandler<GetPortfolioQuery, TraderPortfolioDto>
{
    public async Task<TraderPortfolioDto> Handle(GetPortfolioQuery request, CancellationToken ct)
    {
        var trader = await traderRepo.GetWithInventoryAsync(request.TraderId, ct)
            ?? throw new NotFoundException(nameof(Trader), request.TraderId);

        return mapper.Map<TraderPortfolioDto>(trader);
    }
}
```

---

## MediatR Pipeline Behaviors

Cross-cutting concerns (validation, logging, X-Ray tracing) run as pipeline behaviors — the handler stays clean.

```csharp
// Application/Common/Behaviors/ValidationBehavior.cs
public sealed class ValidationBehavior<TRequest, TResponse>(
    IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IRequest<TResponse>
{
    public async Task<TResponse> Handle(
        TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        if (!validators.Any()) return await next();

        var context = new ValidationContext<TRequest>(request);
        var failures = (await Task.WhenAll(
                validators.Select(v => v.ValidateAsync(context, ct))))
            .SelectMany(r => r.Errors)
            .Where(f => f is not null)
            .ToList();

        if (failures.Count > 0) throw new ValidationException(failures);

        return await next();
    }
}
```

---

## Minimal API Endpoints

Endpoints are thin — validate, send MediatR command/query, return result.

```csharp
// Api/Endpoints/ListingEndpoints.cs
public static class ListingEndpoints
{
    public static IEndpointRouteBuilder MapListingEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/v1/listings")
            .WithTags("Listings")
            .RequireAuthorization();

        group.MapPost("/{listingId}/bids", async (
            Guid listingId,
            PlaceBidRequest request,
            ISender sender,
            HttpContext ctx,
            CancellationToken ct) =>
        {
            var traderId = TraderId.From(ctx.User.GetTraderId());
            var command = new PlaceBidCommand(traderId, ListingId.From(listingId), request.Amount);
            var bid = await sender.Send(command, ct);
            return Results.Created($"/v1/listings/{listingId}/bids/{bid.Id}", bid);
        })
        .WithName("PlaceBid")
        .Produces<BidDto>(201)
        .ProducesValidationProblem()
        .ProducesProblem(404)
        .ProducesProblem(422);

        return app;
    }
}
```

---

## Dependency Injection

```csharp
// Application/DependencyInjection.cs
public static IServiceCollection AddApplication(this IServiceCollection services)
{
    services.AddMediatR(cfg =>
        cfg.RegisterServicesFromAssembly(typeof(DependencyInjection).Assembly));

    services.AddValidatorsFromAssembly(typeof(DependencyInjection).Assembly);
    services.AddAutoMapper(typeof(DependencyInjection).Assembly);

    services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
    services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));

    return services;
}

// Infrastructure/DependencyInjection.cs
public static IServiceCollection AddInfrastructure(
    this IServiceCollection services, IConfiguration config)
{
    DefaultTypeMap.MatchNamesWithUnderscores = true;  // snake_case → PascalCase

    var dataSource = NpgsqlDataSource.Create(
        config.GetConnectionString("Postgres")!);
    services.AddSingleton(dataSource);

    services.AddScoped<ITraderRepository, TraderRepository>();
    services.AddScoped<IListingRepository, ListingRepository>();
    services.AddScoped<IPetRepository, PetRepository>();
    services.AddScoped<INotificationService, WebSocketNotificationService>();

    return services;
}
```

---

## Layer Dependency Rules

```
Domain         ← no dependencies
Application    ← Domain only
Infrastructure ← Application + Domain
Api            ← Application only  (never Infrastructure directly)
```

Never reference `Infrastructure` from `Api` directly — always go through application layer interfaces. The DI container wires up implementations in `Program.cs`.

---

## Quick Reference

| Concept | Location | Rule |
|---|---|---|
| Business rules | `Domain/Entities/` | No I/O, no framework references |
| Use case orchestration | `Application/Commands/` | Thin handler; domain does the work |
| Data transformation | `Application/Queries/` | Return DTOs, never domain entities |
| DB access | `Infrastructure/Persistence/` | Dapper only; repos implement domain interfaces |
| HTTP concerns | `Api/Endpoints/` | Map to commands/queries; return HTTP results |
| Cross-cutting | `Application/Common/Behaviors/` | MediatR pipeline behaviors |
