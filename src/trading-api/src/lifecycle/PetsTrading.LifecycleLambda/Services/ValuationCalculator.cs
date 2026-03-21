namespace PetsTrading.LifecycleLambda.Services;

/// <summary>
/// Computes the intrinsic value of a pet using the canonical formula:
/// <c>IntrinsicValue = BasePrice x (Health/100) x (Desirability/10) x max(0, 1 - Age/Lifespan)</c>
/// Age is always derived from <c>NOW - created_at</c> in years (ADR-016).
/// Expired pets (Age >= Lifespan) always have an intrinsic value of 0.
/// </summary>
public sealed class ValuationCalculator
{
    /// <summary>
    /// Calculates the intrinsic value for a pet.
    /// </summary>
    /// <param name="basePrice">Breed base price from pet_dictionary.</param>
    /// <param name="health">Current pet health in the range [0, 100].</param>
    /// <param name="desirability">Current pet desirability value.</param>
    /// <param name="ageInYears">
    /// Pet age in years, derived from <c>NOW() - created_at</c>.
    /// Never pass a stored counter; always compute from the timestamp.
    /// </param>
    /// <param name="lifespanInYears">Breed lifespan from pet_dictionary.</param>
    /// <returns>Calculated intrinsic value; zero for expired pets.</returns>
    public decimal Calculate(
        decimal basePrice,
        decimal health,
        decimal desirability,
        decimal ageInYears,
        int lifespanInYears)
    {
        var ageFactor = Math.Max(0m, 1m - ageInYears / lifespanInYears);
        return basePrice * (health / 100m) * (desirability / 10m) * ageFactor;
    }

    /// <summary>
    /// Derives whether a pet is expired based on age vs lifespan.
    /// This is a cache helper; the canonical check is always <c>age >= lifespan</c>.
    /// </summary>
    /// <param name="ageInYears">Pet age in years derived from the timestamp.</param>
    /// <param name="lifespanInYears">Breed lifespan from pet_dictionary.</param>
    /// <returns>True when the pet has reached or exceeded its breed lifespan.</returns>
    public bool IsExpired(decimal ageInYears, int lifespanInYears) =>
        ageInYears >= lifespanInYears;
}
