# Unit Testing Reference — .NET 10, xUnit, FluentAssertions, Moq, AutoFixture

## Table of Contents
1. [Tech Stack & Project Setup](#1-tech-stack--project-setup)
2. [AAA Pattern](#2-aaa-pattern)
3. [Naming Convention](#3-naming-convention)
4. [Fixture Pattern — Shared Setup via IClassFixture](#4-fixture-pattern--shared-setup-via-iclassfixture)
5. [AutoFixture — Fake Data and Auto-Mocking](#5-autofixture--fake-data-and-auto-mocking)
6. [Domain / Business Logic Tests](#6-domain--business-logic-tests)
7. [Service / Handler Tests with Fixture](#7-service--handler-tests-with-fixture)
8. [Async Tests](#8-async-tests)
9. [Exception & Guard Tests](#9-exception--guard-tests)
10. [Integration Tests with Testcontainers](#10-integration-tests-with-testcontainers)
11. [Test Data Builders](#11-test-data-builders)
12. [Coverage & CI Configuration](#12-coverage--ci-configuration)

---

## 1. Tech Stack & Project Setup

| Package | Purpose |
|---|---|
| `xunit` | Test runner |
| `xunit.runner.visualstudio` | VS/Rider discovery |
| `FluentAssertions` | Readable, expressive assertions |
| `Moq` | Mocking/substitution |
| `AutoFixture` | Auto-generates fake test data |
| `AutoFixture.AutoMoq` | Auto-creates Moq mocks for interfaces/abstract classes |
| `AutoFixture.Xunit2` | `[AutoData]` / `[InlineAutoData]` theory attributes |
| `Testcontainers.PostgreSql` | Integration tests against real PostgreSQL |
| `Microsoft.AspNetCore.Mvc.Testing` | WebApplication factory for API integration tests |
| `coverlet.collector` | Code coverage collection (XPlat Code Coverage) |

```xml
<!-- *.Tests.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="xunit" Version="2.*" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.*" />
    <PackageReference Include="FluentAssertions" Version="6.*" />
    <PackageReference Include="Moq" Version="4.*" />
    <PackageReference Include="AutoFixture" Version="4.*" />
    <PackageReference Include="AutoFixture.AutoMoq" Version="4.*" />
    <PackageReference Include="AutoFixture.Xunit2" Version="4.*" />
    <PackageReference Include="Testcontainers.PostgreSql" Version="3.*" />
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="10.*" />
    <PackageReference Include="coverlet.collector" Version="6.*">
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
      <PrivateAssets>all</PrivateAssets>
    </PackageReference>
  </ItemGroup>
</Project>
```

**Project structure:**
```
tests/
  PetsTrading.Domain.Tests/          # Pure domain rules — no I/O
  PetsTrading.Application.Tests/     # Handler/service layer — mock repos via Fixture
  PetsTrading.Api.Tests/             # Endpoint integration tests
  PetsTrading.Infrastructure.Tests/  # Dapper repos vs real PostgreSQL (Testcontainers)
```

---

## 2. AAA Pattern

Every test follows **Arrange → Act → Assert**. Use section comments when the body is longer than ~10 lines; omit them for trivial tests where the intent is obvious.

```csharp
[Fact]
public void PlaceBid_WhenAmountExceedsAvailableCash_ThrowsInsufficientFundsException()
{
    // Arrange
    var trader = TraderBuilder.WithCash(50m).Build();
    var listing = ListingBuilder.Active().WithAskingPrice(100m).Build();

    // Act
    var act = () => trader.PlaceBid(listing, amount: 75m);

    // Assert
    act.Should().Throw<InsufficientFundsException>()
        .WithMessage("*insufficient*");
}
```

---

## 3. Naming Convention

Use the pattern: **`MethodName_WhenCondition_ExpectedOutcome`**

```
PlaceBid_WhenAmountExceedsAvailableCash_ThrowsInsufficientFundsException
PlaceBid_WhenAmountIsValid_LocksTraderCash
PlaceBid_OnOwnListing_ThrowsDomainException
AcceptBid_WhenBidIsActive_TransfersPetOwnership
WithdrawListing_WithActiveBid_RejectsBidAndReturnsCash
CalculateIntrinsicValue_WhenPetIsExpired_ReturnsZero
HandleAsync_WhenTraderNotFound_ThrowsNotFoundException
```

Descriptive names are more valuable than brevity. Never abbreviate the scenario.

---

## 4. Fixture Pattern — Shared Setup via IClassFixture

Instead of creating mocks and the SUT in every test's constructor, use a **Fixture class** that owns the `Mock<T>` objects and SUT. Tests receive the fixture via `IClassFixture<T>` and call `Reset()` at the start of each test to clear recorded calls and return values from the previous test.

This keeps setup DRY while preserving test isolation.

### Why Fixture instead of per-test `new`?

- **Eliminates repetitive constructor code** — mocks and SUT are wired once in the fixture.
- **Explicit reset contract** — `Reset()` makes state isolation visible and intentional.
- **Easier to add dependencies** — add a new mock to the fixture; all tests get it automatically.
- **Consistent with integration test pattern** — `IClassFixture` is also used for Testcontainers.

### Fixture class structure

```csharp
// Application.Tests/Traders/BidServiceFixture.cs
public sealed class BidServiceFixture
{
    // Public Mock<T> properties — tests configure setups against these
    public Mock<ITraderRepository> TraderRepository { get; } = new();
    public Mock<IListingRepository> ListingRepository { get; } = new();
    public Mock<INotificationService> NotificationService { get; } = new();

    // The system under test — wired from mock .Object properties
    public BidService Sut { get; }

    public BidServiceFixture()
    {
        Sut = new BidService(
            TraderRepository.Object,
            ListingRepository.Object,
            NotificationService.Object);
    }

    // Call at the start of every test to prevent state leaking between tests
    public void Reset()
    {
        TraderRepository.Reset();
        ListingRepository.Reset();
        NotificationService.Reset();
    }
}
```

### Test class using the fixture

```csharp
// Application.Tests/Traders/BidServiceTests.cs
public sealed class BidServiceTests : IClassFixture<BidServiceFixture>
{
    private readonly BidServiceFixture _fixture;

    // xUnit injects the shared fixture instance via constructor
    public BidServiceTests(BidServiceFixture fixture)
    {
        _fixture = fixture;
        _fixture.Reset();   // isolate from previous test in this class
    }

    [Fact]
    public async Task HandleAsync_WhenBidIsValid_LocksTraderCash()
    {
        // Arrange
        var trader = TraderBuilder.WithCash(200m).Build();
        var listing = ListingBuilder.Active().WithAskingPrice(50m).Build();

        _fixture.TraderRepository
            .Setup(r => r.GetByIdAsync(trader.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(trader);
        _fixture.ListingRepository
            .Setup(r => r.GetByIdAsync(listing.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(listing);

        var command = new PlaceBidCommand(trader.Id, listing.Id, amount: 80m);

        // Act
        await _fixture.Sut.HandleAsync(command, CancellationToken.None);

        // Assert
        trader.AvailableCash.Should().Be(120m);
        trader.LockedCash.Should().Be(80m);
    }

    [Fact]
    public async Task HandleAsync_WhenTraderNotFound_ThrowsNotFoundException()
    {
        // Arrange — TraderRepository returns null by default after Reset()
        var command = new PlaceBidCommand(TraderId.New(), ListingId.New(), amount: 50m);

        // Act
        var act = async () => await _fixture.Sut.HandleAsync(command, CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<NotFoundException>()
            .WithMessage($"*Trader*");
    }

    [Fact]
    public async Task HandleAsync_WhenBidSucceeds_SendsBidReceivedNotification()
    {
        // Arrange
        var seller = TraderBuilder.Default().Build();
        var bidder = TraderBuilder.WithCash(300m).Build();
        var listing = ListingBuilder.Active().OwnedBy(seller.Id).Build();

        _fixture.TraderRepository
            .Setup(r => r.GetByIdAsync(bidder.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(bidder);
        _fixture.ListingRepository
            .Setup(r => r.GetByIdAsync(listing.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(listing);

        var command = new PlaceBidCommand(bidder.Id, listing.Id, amount: 80m);

        // Act
        await _fixture.Sut.HandleAsync(command, CancellationToken.None);

        // Assert — verify notification sent to seller exactly once
        _fixture.NotificationService.Verify(
            s => s.SendBidReceivedAsync(seller.Id, It.IsAny<Bid>(), It.IsAny<CancellationToken>()),
            Times.Once);
    }
}
```

### One fixture per service class

```
Application.Tests/
  Traders/
    BidServiceFixture.cs
    BidServiceTests.cs
  Listings/
    ListingServiceFixture.cs
    ListingServiceTests.cs
  Pets/
    PetQueryHandlerFixture.cs
    PetQueryHandlerTests.cs
```

---

## 5. AutoFixture — Fake Data and Auto-Mocking

AutoFixture generates anonymous test data automatically, removing the need to hand-craft every value. Combined with `AutoMoqCustomization`, it also auto-creates Moq mocks for any interface or abstract type it encounters.

### One-off anonymous data in a test

```csharp
var fixture = new Fixture();
var traderId = fixture.Create<TraderId>();
var amount    = fixture.Create<decimal>();
var name      = fixture.Create<string>();    // unique non-empty string
```

### AutoMoqCustomization — auto-create mocks

```csharp
var fixture = new Fixture().Customize(new AutoMoqCustomization { ConfigureMembers = true });

// AutoFixture creates a Mock<ITraderRepository> internally and injects .Object
var sut = fixture.Create<BidService>();

// Retrieve the mock AutoFixture created so you can set up / verify it
var repoMock = fixture.Freeze<Mock<ITraderRepository>>();
repoMock.Setup(r => r.GetByIdAsync(It.IsAny<TraderId>(), It.IsAny<CancellationToken>()))
        .ReturnsAsync(fixture.Create<Trader>());
```

`Freeze<T>()` tells AutoFixture to always return the same instance for `T` — so the mock injected into `BidService` is the same one you hold a reference to.

### [AutoMoqData] attribute — theory tests with zero boilerplate

Define a reusable attribute:

```csharp
// TestInfrastructure/AutoMoqDataAttribute.cs
public sealed class AutoMoqDataAttribute : AutoDataAttribute
{
    public AutoMoqDataAttribute()
        : base(() => new Fixture().Customize(new AutoMoqCustomization { ConfigureMembers = true }))
    { }
}
```

Use it on `[Theory]` tests — xUnit injects fully constructed, auto-mocked parameters:

```csharp
[Theory, AutoMoqData]
public void PlaceBid_WhenAmountIsValid_LocksTraderCash(
    [Frozen] Mock<IListingRepository> listingRepo,
    BidService sut,
    Trader trader,
    Listing listing)
{
    // Arrange
    listingRepo.Setup(r => r.GetByIdAsync(listing.Id, It.IsAny<CancellationToken>()))
               .ReturnsAsync(listing);

    // Act
    trader.PlaceBid(listing, amount: 50m);

    // Assert
    trader.LockedCash.Should().Be(50m);
}
```

`[Frozen]` on a parameter is the attribute equivalent of `fixture.Freeze<T>()` — same instance goes everywhere.

### Customising generated values

Override auto-generation for specific types to keep values in valid domain ranges:

```csharp
fixture.Customize<decimal>(c => c.FromFactory(() => Math.Round(Random.Shared.NextDecimal(1m, 999m), 2)));
fixture.Customize<Trader>(c => c.With(t => t.DisplayName, "TestTrader"));
```

---

## 6. Domain / Business Logic Tests

Domain entity tests have no mocks or fixtures — they are pure in-memory tests and should be fast (<1 ms each).

```csharp
// Domain.Tests/Entities/TraderTests.cs
public sealed class TraderTests
{
    [Fact]
    public void NewTrader_HasStartingCashOfOneFiftyDollars()
    {
        var trader = Trader.Create(TraderId.New(), "Alice");
        trader.AvailableCash.Should().Be(150m);
    }

    [Fact]
    public void PlaceBid_OnOwnListing_ThrowsDomainException()
    {
        // Arrange
        var trader = TraderBuilder.WithCash(200m).Build();
        var listing = ListingBuilder.Active().OwnedBy(trader.Id).Build();

        // Act
        var act = () => trader.PlaceBid(listing, amount: 60m);

        // Assert
        act.Should().Throw<DomainException>()
            .WithMessage("*own listing*");
    }

    [Theory]
    [InlineData(100, 10, 0.5, 50.0)]   // half life remaining
    [InlineData(80,  8,  1.0, 64.0)]   // full life, health/desirability reduced
    [InlineData(50,  5,  1.0, 25.0)]   // both halved
    public void CalculateIntrinsicValue_AppliesFormula(
        int health, int desirability, double ageFraction, decimal expected)
    {
        // Arrange
        var lifespan = TimeSpan.FromDays(10);
        var breed = new BreedDefinition(basePrice: 100m, lifespan: lifespan);
        var age = TimeSpan.FromDays(lifespan.TotalDays * ageFraction);
        var pet = new Pet(PetId.New(), breed, DateTime.UtcNow - age, health, desirability);

        // Act
        var value = pet.CalculateIntrinsicValue();

        // Assert
        value.Should().BeApproximately(expected, precision: 0.01m);
    }
}
```

---

## 7. Service / Handler Tests with Fixture

See §4 for the full fixture pattern. Key rules:
- Call `_fixture.Reset()` in the test constructor — never skip it.
- Only configure `Setup()` calls relevant to the specific test; rely on reset defaults (returns null/default) for everything else.
- Verify mock interactions (`Verify()`) only for critical side effects (notifications, audit logs); don't assert every call.
- Use `Times.Once`, `Times.Never`, `Times.AtLeastOnce` to be precise about cardinality.

---

## 8. Async Tests

Use `async Task` — never `async void`. FluentAssertions provides async-aware assertion helpers.

```csharp
// Exception from async code
var act = async () => await _fixture.Sut.HandleAsync(command, CancellationToken.None);
await act.Should().ThrowAsync<NotFoundException>();

// Successful async result
var result = await _fixture.Sut.GetPortfolioAsync(traderId, CancellationToken.None);
result.Should().NotBeNull();
result.AvailableCash.Should().Be(150m);

// Moq async setup
_fixture.TraderRepository
    .Setup(r => r.GetByIdAsync(It.IsAny<TraderId>(), It.IsAny<CancellationToken>()))
    .ReturnsAsync((Trader?)null);   // simulates not-found
```

---

## 9. Exception & Guard Tests

Test all domain guard clauses. They are the financial safety net.

```csharp
[Theory]
[InlineData(0)]
[InlineData(-1)]
[InlineData(-999)]
public void Listing_WithNonPositiveAskingPrice_ThrowsArgumentException(decimal price)
{
    var act = () => new Listing(ListingId.New(), PetId.New(), TraderId.New(), askingPrice: price);

    act.Should().Throw<ArgumentException>()
        .WithParameterName("askingPrice");
}
```

---

## 10. Integration Tests with Testcontainers

Integration tests run against a real PostgreSQL container via `IAsyncLifetime`. These test the Dapper repository implementations end-to-end.

```csharp
// Infrastructure.Tests/Persistence/TraderRepositoryTests.cs
public sealed class TraderRepositoryTests : IAsyncLifetime
{
    private PostgreSqlContainer _postgres = null!;
    private NpgsqlDataSource _dataSource = null!;
    private TraderRepository _sut = null!;

    public async Task InitializeAsync()
    {
        _postgres = new PostgreSqlBuilder()
            .WithImage("postgres:16-alpine")
            .Build();
        await _postgres.StartAsync();

        _dataSource = NpgsqlDataSource.Create(_postgres.GetConnectionString());
        await DatabaseMigrator.ApplyAsync(_dataSource);   // run SQL migration files
        _sut = new TraderRepository(_dataSource, new Mapper(...));
    }

    public async Task DisposeAsync()
    {
        await _dataSource.DisposeAsync();
        await _postgres.DisposeAsync();
    }

    [Fact]
    public async Task GetByIdAsync_WhenTraderExists_ReturnsCorrectTrader()
    {
        // Arrange
        var trader = TraderBuilder.Default().Build();
        await _sut.SaveAsync(trader, CancellationToken.None);

        // Act
        var result = await _sut.GetByIdAsync(trader.Id, CancellationToken.None);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be(trader.Id);
        result.AvailableCash.Should().Be(150m);
    }
}
```

For sharing a single container across all tests in a class (faster than spinning up per test), use `IClassFixture<PostgreSqlContainerFixture>` with a shared container fixture.

---

## 11. Test Data Builders

Use the builder pattern — keeps tests readable and shields them from domain model changes. Seed values with AutoFixture when you need unique random data rather than hardcoded strings/IDs.

```csharp
// TestBuilders/TraderBuilder.cs
public sealed class TraderBuilder
{
    private static readonly IFixture _fixture = new Fixture();

    private TraderId _id = TraderId.New();
    private decimal _cash = 150m;
    private string _name = _fixture.Create<string>();   // unique per instance

    public static TraderBuilder Default() => new();
    public static TraderBuilder WithCash(decimal cash) => new TraderBuilder().HavingCash(cash);

    public TraderBuilder HavingCash(decimal cash)    { _cash = cash;    return this; }
    public TraderBuilder WithId(TraderId id)          { _id = id;        return this; }
    public TraderBuilder Named(string name)           { _name = name;    return this; }

    public Trader Build() => Trader.Create(_id, _name) with { AvailableCash = _cash };
}

// TestBuilders/ListingBuilder.cs
public sealed class ListingBuilder
{
    private TraderId _ownerId = TraderId.New();
    private PetId _petId = PetId.New();
    private decimal _askingPrice = 100m;
    private Bid? _activeBid;

    public static ListingBuilder Active() => new();

    public ListingBuilder OwnedBy(TraderId ownerId) { _ownerId = ownerId; return this; }
    public ListingBuilder ForPet(PetId petId)        { _petId = petId;    return this; }
    public ListingBuilder WithAskingPrice(decimal p) { _askingPrice = p;  return this; }
    public ListingBuilder WithActiveBid(decimal amount, TraderId? bidderId = null)
    {
        _activeBid = new Bid(BidId.New(), bidderId ?? TraderId.New(), amount);
        return this;
    }
    public ListingBuilder WithNoActiveBid()          { _activeBid = null; return this; }

    public Listing Build() => new(ListingId.New(), _petId, _ownerId, _askingPrice, _activeBid);
}
```

---

## 12. Coverage & CI Configuration

| Layer | Target |
|---|---|
| Domain | ≥ 95% — pure business logic, no excuses |
| Application | ≥ 80% — handler orchestration |
| Infrastructure | Covered by integration tests (no line target) |

Use `coverlet.collector` (already in the `.csproj` above) with the `XPlat Code Coverage` data collector:

```yaml
# .github/workflows/test.yml
- name: Run Tests
  run: dotnet test --configuration Release --collect:"XPlat Code Coverage" --results-directory coverage/

- name: Upload Coverage
  uses: codecov/codecov-action@v4
  with:
    directory: coverage/
    fail_ci_if_error: true
    threshold: 80
```

```xml
<!-- Directory.Build.props — enforce threshold locally too -->
<PropertyGroup>
  <CollectCoverage>true</CollectCoverage>
  <CoverletOutputFormat>opencover</CoverletOutputFormat>
  <Threshold>80</Threshold>
  <ThresholdType>line</ThresholdType>
</PropertyGroup>
```
