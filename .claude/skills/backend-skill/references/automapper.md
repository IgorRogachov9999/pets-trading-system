# AutoMapper Reference — .NET 10, Profile-Based Configuration

## Table of Contents
1. [Installation & DI Setup](#1-installation--di-setup)
2. [Profile Pattern (required style)](#2-profile-pattern-required-style)
3. [Mapping in This Project](#3-mapping-in-this-project)
4. [Custom Value Resolvers](#4-custom-value-resolvers)
5. [Projection with IQueryable](#5-projection-with-iqueryable)
6. [Testing Mappings](#6-testing-mappings)
7. [Common Pitfalls](#7-common-pitfalls)

---

## 1. Installation & DI Setup

```
dotnet add package AutoMapper
dotnet add package AutoMapper.Extensions.Microsoft.DependencyInjection
```

Register once in `Program.cs` (or DI bootstrap):
```csharp
builder.Services.AddAutoMapper(typeof(Program).Assembly);
// Or scan multiple assemblies:
builder.Services.AddAutoMapper(
    typeof(Program).Assembly,
    typeof(TradingDomainProfile).Assembly);
```

This auto-discovers all classes that inherit from `Profile` in the given assemblies. Never call `new MapperConfiguration(...)` in production code — let DI manage the singleton lifetime.

Inject `IMapper` via constructor:
```csharp
public class TraderService(ITraderRepository repo, IMapper mapper)
{
    public async Task<TraderDto> GetPortfolioAsync(TraderId id, CancellationToken ct)
    {
        var trader = await repo.GetByIdAsync(id, ct);
        return mapper.Map<TraderDto>(trader);
    }
}
```

---

## 2. Profile Pattern (required style)

Always define mappings in `Profile` classes, never inline at configuration time.
One profile per domain bounded context keeps things navigable.

```csharp
// Profiles/TradingProfile.cs
public sealed class TradingProfile : Profile
{
    public TradingProfile()
    {
        // Simple same-name mappings (AutoMapper resolves automatically)
        CreateMap<Trader, TraderDto>();
        CreateMap<Pet, PetDto>();

        // Explicit projection when property names differ
        CreateMap<Listing, ListingDto>()
            .ForMember(dest => dest.SellerName,
                       opt => opt.MapFrom(src => src.Owner.DisplayName))
            .ForMember(dest => dest.CurrentBidAmount,
                       opt => opt.MapFrom(src => src.ActiveBid != null
                                               ? src.ActiveBid.Amount
                                               : (decimal?)null));

        // Reverse map — enable mapping from DTO back to domain only when safe
        CreateMap<PlaceBidRequest, PlaceBidCommand>()
            .ForMember(dest => dest.ListingId,
                       opt => opt.MapFrom(src => ListingId.From(src.ListingId)));

        // Ignore computed or navigation properties not present in DTO
        CreateMap<Trade, TradeDto>()
            .ForMember(dest => dest.PetName,
                       opt => opt.MapFrom(src => src.Pet.Breed.Name))
            .ForMember(dest => dest.BuyerDisplayName,
                       opt => opt.MapFrom(src => src.Buyer.DisplayName));
    }
}
```

---

## 3. Mapping in This Project

### Response DTOs (Domain → DTO)

```csharp
// Domain entity → API response DTO
public record TraderDto(
    string Id,
    decimal AvailableCash,
    decimal LockedCash,
    decimal PortfolioValue,
    IReadOnlyList<PetDto> Inventory,
    IReadOnlyList<NotificationDto> Notifications);

public record PetDto(
    string Id,
    string BreedName,
    int Health,
    int Desirability,
    decimal IntrinsicValue,
    bool IsExpired,
    double AgeInDays);

public record ListingDto(
    string Id,
    PetDto Pet,
    decimal AskingPrice,
    decimal? LastTradePrice,
    decimal? CurrentBidAmount,
    string SellerId);

public record NotificationDto(
    string Type,            // bid.received, bid.accepted, etc.
    string PetName,
    decimal Price,
    string Counterparty,
    DateTimeOffset OccurredAt);
```

```csharp
// Profiles/TradingProfile.cs — mappings for the above
public sealed class TradingProfile : Profile
{
    public TradingProfile()
    {
        CreateMap<Trader, TraderDto>()
            .ForMember(d => d.Id, o => o.MapFrom(s => s.Id.Value))
            .ForMember(d => d.PortfolioValue,
                       o => o.MapFrom(s => s.CalculatePortfolioValue()));

        CreateMap<Pet, PetDto>()
            .ForMember(d => d.Id, o => o.MapFrom(s => s.Id.Value))
            .ForMember(d => d.BreedName, o => o.MapFrom(s => s.Breed.Name))
            .ForMember(d => d.AgeInDays,
                       o => o.MapFrom(s => (DateTime.UtcNow - s.CreatedAt).TotalDays))
            .ForMember(d => d.IntrinsicValue, o => o.MapFrom(s => s.CalculateIntrinsicValue()));

        CreateMap<Listing, ListingDto>()
            .ForMember(d => d.Id, o => o.MapFrom(s => s.Id.Value))
            .ForMember(d => d.SellerId, o => o.MapFrom(s => s.OwnerId.Value))
            .ForMember(d => d.CurrentBidAmount,
                       o => o.MapFrom(s => s.ActiveBid != null ? s.ActiveBid.Amount : (decimal?)null));

        CreateMap<Notification, NotificationDto>()
            .ForMember(d => d.Type, o => o.MapFrom(s => s.EventType.ToString()))
            .ForMember(d => d.PetName, o => o.MapFrom(s => s.Pet.Breed.Name));
    }
}
```

### Command / Request → Domain Command

Map incoming API request bodies to application-layer commands. Validate first with FluentValidation, then map.

```csharp
CreateMap<PlaceBidRequest, PlaceBidCommand>()
    .ForMember(d => d.ListingId, o => o.MapFrom(s => ListingId.From(s.ListingId)))
    .ForMember(d => d.Amount,    o => o.MapFrom(s => s.Amount));

CreateMap<CreateListingRequest, CreateListingCommand>()
    .ForMember(d => d.PetId,        o => o.MapFrom(s => PetId.From(s.PetId)))
    .ForMember(d => d.AskingPrice,  o => o.MapFrom(s => s.AskingPrice));
```

---

## 4. Custom Value Resolvers

Use a `IValueResolver<TSource, TDestination, TDestMember>` when the mapping logic is too complex for a lambda or is reused across multiple maps.

```csharp
// Resolves PortfolioValue including all pet intrinsic values
public class PortfolioValueResolver : IValueResolver<Trader, TraderDto, decimal>
{
    public decimal Resolve(Trader src, TraderDto dest, decimal destMember, ResolutionContext ctx)
        => src.AvailableCash
           + src.LockedCash
           + src.Inventory.Sum(p => p.CalculateIntrinsicValue());
}

// In profile:
CreateMap<Trader, TraderDto>()
    .ForMember(d => d.PortfolioValue, o => o.MapFrom<PortfolioValueResolver>());
```

---

## 5. Projection with IQueryable

When using Dapper (as in this project), AutoMapper projection with `IQueryable` doesn't apply — that's an EF Core feature. Instead, map in-memory after the Dapper query returns:

```csharp
// Correct pattern for Dapper + AutoMapper
var listings = await _listingRepo.GetActiveListingsAsync(ct);     // returns IReadOnlyList<Listing>
var dtos = _mapper.Map<IReadOnlyList<ListingDto>>(listings);      // in-memory mapping

// NOT: listings.ProjectTo<ListingDto>() — this requires IQueryable/EF Core
```

For large collections, mapping is fast (microseconds per object) — don't prematurely optimize by avoiding AutoMapper in hot paths.

---

## 6. Testing Mappings

### Configuration validity test (one test per profile)

```csharp
public class TradingProfileTests
{
    [Fact]
    public void TradingProfile_ConfigurationIsValid()
    {
        // Arrange
        var config = new MapperConfiguration(cfg => cfg.AddProfile<TradingProfile>());

        // Act & Assert
        config.AssertConfigurationIsValid();
    }
}
```

This catches unmapped destination properties, missing type converters, and circular references at test time rather than runtime.

### Specific mapping behavior tests

```csharp
public class PetMappingTests
{
    private readonly IMapper _mapper = new MapperConfiguration(
        cfg => cfg.AddProfile<TradingProfile>()).CreateMapper();

    [Fact]
    public void Pet_MapsToDto_WithCorrectAgeInDays()
    {
        // Arrange
        var createdAt = DateTime.UtcNow.AddDays(-5);
        var pet = PetBuilder.Default().CreatedAt(createdAt).Build();

        // Act
        var dto = _mapper.Map<PetDto>(pet);

        // Assert
        dto.AgeInDays.Should().BeApproximately(5.0, precision: 0.1);
    }

    [Fact]
    public void Listing_WithNoActiveBid_MapsToDtoWithNullCurrentBidAmount()
    {
        // Arrange
        var listing = ListingBuilder.Active().WithNoActiveBid().Build();

        // Act
        var dto = _mapper.Map<ListingDto>(listing);

        // Assert
        dto.CurrentBidAmount.Should().BeNull();
    }
}
```

---

## 7. Common Pitfalls

| Pitfall | What happens | Fix |
|---|---|---|
| Unmapped destination property | `AutoMapperConfigurationException` at startup | Add `.ForMember(d => d.X, o => o.Ignore())` or map it |
| Mapping domain method results (like `CalculateIntrinsicValue()`) | Not mapped by convention | Explicit `.ForMember(..., o => o.MapFrom(s => s.CalculateIntrinsicValue()))` |
| Forgetting `AssertConfigurationIsValid()` in tests | Silent wrong mappings in prod | Add the config test per profile (see §6) |
| Using `Mapper.Map<>()` static API | Untestable, hidden dependency | Always inject `IMapper` |
| Mapping branded value types (`TraderId`, `PetId`) to `string` | Will fail without custom converter | Explicit `.ForMember(d => d.Id, o => o.MapFrom(s => s.Id.Value))` |
| Registering profiles multiple times | Duplicate mappings, runtime errors | Use `AddAutoMapper(assembly)` — it deduplicates |
| Circular reference in domain model | Stack overflow during mapping | Add `.PreserveReferences()` in profile, or avoid mapping circular graphs |
