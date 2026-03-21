using FluentAssertions;
using PetsTrading.LifecycleLambda.Services;

namespace PetsTrading.LifecycleLambda.Tests;

/// <summary>
/// Unit tests for <see cref="ValuationCalculator"/> covering the intrinsic value formula:
/// IntrinsicValue = BasePrice x (Health/100) x (Desirability/10) x max(0, 1 - Age/Lifespan).
/// All tests are pure in-memory — no I/O, no dependencies.
/// </summary>
public sealed class ValuationCalculatorTests
{
    private readonly ValuationCalculator _sut = new();

    /// <summary>
    /// A pet at peak condition (full health, max desirability, age = 0) should return
    /// its full base price as intrinsic value.
    /// </summary>
    [Fact]
    public void Calculate_WhenPetIsNewAndFullyHealthy_ReturnsFullBasePrice()
    {
        // Arrange
        const decimal basePrice = 100m;
        const decimal health = 100m;
        const decimal desirability = 10m;
        const decimal ageInYears = 0m;
        const int lifespanInYears = 10;

        // Act
        var result = _sut.Calculate(basePrice, health, desirability, ageInYears, lifespanInYears);

        // Assert
        result.Should().Be(100.00m);
    }

    /// <summary>
    /// A pet at half health, half desirability, and half-way through its lifespan
    /// should return 12.50 (100 x 0.5 x 0.5 x 0.5).
    /// </summary>
    [Fact]
    public void Calculate_WhenPetIsHalfwayThroughLifeAtHalfStats_ReturnsCorrectValue()
    {
        // Arrange
        const decimal basePrice = 100m;
        const decimal health = 50m;
        const decimal desirability = 5m;
        const decimal ageInYears = 5m;
        const int lifespanInYears = 10;

        // Act
        var result = _sut.Calculate(basePrice, health, desirability, ageInYears, lifespanInYears);

        // Assert
        result.Should().Be(12.50m);
    }

    /// <summary>
    /// A pet that has reached exactly its lifespan (age == lifespan) is expired
    /// and must have an intrinsic value of 0.
    /// </summary>
    [Fact]
    public void Calculate_WhenAgeEqualsLifespan_ReturnsZero()
    {
        // Arrange
        const decimal basePrice = 100m;
        const decimal health = 100m;
        const decimal desirability = 10m;
        const decimal ageInYears = 10m;
        const int lifespanInYears = 10;

        // Act
        var result = _sut.Calculate(basePrice, health, desirability, ageInYears, lifespanInYears);

        // Assert
        result.Should().Be(0m);
    }

    /// <summary>
    /// A pet that exceeds its lifespan (age > lifespan) must also have an intrinsic
    /// value of 0. The max(0, ...) guard prevents negative values.
    /// </summary>
    [Fact]
    public void Calculate_WhenAgeExceedsLifespan_ReturnsZero()
    {
        // Arrange
        const decimal basePrice = 100m;
        const decimal health = 80m;
        const decimal desirability = 8m;
        const decimal ageInYears = 15m;
        const int lifespanInYears = 10;

        // Act
        var result = _sut.Calculate(basePrice, health, desirability, ageInYears, lifespanInYears);

        // Assert
        result.Should().Be(0m);
    }

    /// <summary>
    /// IsExpired returns true when age equals lifespan.
    /// </summary>
    [Fact]
    public void IsExpired_WhenAgeEqualsLifespan_ReturnsTrue()
    {
        // Arrange / Act / Assert
        _sut.IsExpired(ageInYears: 10m, lifespanInYears: 10).Should().BeTrue();
    }

    /// <summary>
    /// IsExpired returns true when age exceeds lifespan.
    /// </summary>
    [Fact]
    public void IsExpired_WhenAgeExceedsLifespan_ReturnsTrue()
    {
        // Arrange / Act / Assert
        _sut.IsExpired(ageInYears: 12m, lifespanInYears: 10).Should().BeTrue();
    }

    /// <summary>
    /// IsExpired returns false when the pet is still within its lifespan.
    /// </summary>
    [Fact]
    public void IsExpired_WhenAgeIsLessThanLifespan_ReturnsFalse()
    {
        // Arrange / Act / Assert
        _sut.IsExpired(ageInYears: 5m, lifespanInYears: 10).Should().BeFalse();
    }
}
