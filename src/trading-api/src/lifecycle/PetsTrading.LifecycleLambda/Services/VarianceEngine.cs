namespace PetsTrading.LifecycleLambda.Services;

/// <summary>
/// Applies random ±5% variance to pet health and desirability on each lifecycle tick.
/// Health is clamped to [0, 100]; desirability is clamped to [0, breed maximum].
/// </summary>
public sealed class VarianceEngine
{
    private readonly Random _random;

    /// <summary>Initialises the engine with a thread-safe random source.</summary>
    public VarianceEngine()
    {
        _random = Random.Shared;
    }

    /// <summary>
    /// Applies ±5% variance to a health value and clamps the result to [0, 100].
    /// </summary>
    /// <param name="currentHealth">Current health in the range [0, 100].</param>
    /// <returns>New health value after variance, clamped to valid range.</returns>
    public decimal ApplyHealthVariance(decimal currentHealth)
    {
        var factor = 1m + (decimal)(_random.NextDouble() * 0.10 - 0.05);
        return Math.Clamp(currentHealth * factor, 0m, 100m);
    }

    /// <summary>
    /// Applies ±5% variance to a desirability value and clamps the result to [0, breedMax].
    /// </summary>
    /// <param name="currentDesirability">Current desirability value.</param>
    /// <param name="breedMax">Maximum desirability for the pet's breed (from pet_dictionary).</param>
    /// <returns>New desirability value after variance, clamped to [0, breedMax].</returns>
    public decimal ApplyDesirabilityVariance(decimal currentDesirability, decimal breedMax)
    {
        var factor = 1m + (decimal)(_random.NextDouble() * 0.10 - 0.05);
        return Math.Clamp(currentDesirability * factor, 0m, breedMax);
    }
}
