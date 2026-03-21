namespace PetsTrading.Domain.Entities;

/// <summary>
/// A unique pet instance owned by a trader.
/// Age is always derived from <c>NOW - CreatedAt</c> in years; the <c>Age</c> property
/// is a cache refreshed by the Lifecycle Lambda on every tick (ADR-016).
/// Intrinsic value formula: BasePrice x (Health/100) x (Desirability/10) x max(0, 1 - Age/Lifespan).
/// </summary>
public sealed class Pet
{
    /// <summary>Unique identifier for this pet instance.</summary>
    public Guid Id { get; init; }

    /// <summary>Foreign key into the read-only pet_dictionary table.</summary>
    public int DictionaryId { get; init; }

    /// <summary>Identifier of the trader who currently owns this pet.</summary>
    public Guid OwnerId { get; set; }

    /// <summary>
    /// Cached age in years derived from <c>NOW() - created_at</c>.
    /// This is a convenience cache written by the Lifecycle Lambda; never trust it
    /// for financial calculations — derive from <see cref="CreatedAt"/> directly.
    /// </summary>
    public decimal Age { get; set; }

    /// <summary>Current health value, range [0, 100]. Fluctuates ±5% per lifecycle tick.</summary>
    public decimal Health { get; set; }

    /// <summary>
    /// Current desirability value, range [0, breed max].
    /// Fluctuates ±5% per lifecycle tick.
    /// </summary>
    public decimal Desirability { get; set; }

    /// <summary>Calculated intrinsic value refreshed on every lifecycle tick.</summary>
    public decimal IntrinsicValue { get; set; }

    /// <summary>
    /// Indicates whether the pet has exceeded its breed lifespan.
    /// Cache derived as <c>Age >= Lifespan</c>; refreshed each tick.
    /// Expired pets have intrinsic value of 0 but remain tradeable.
    /// </summary>
    public bool IsExpired { get; set; }

    /// <summary>UTC timestamp when this pet instance was created — the source of truth for age.</summary>
    public DateTimeOffset CreatedAt { get; init; }

    /// <summary>UTC timestamp of the last update to this record.</summary>
    public DateTimeOffset UpdatedAt { get; set; }
}
