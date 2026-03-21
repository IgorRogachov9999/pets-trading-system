namespace PetsTrading.Domain.Entities;

/// <summary>
/// An immutable record of a completed pet sale.
/// Created when a seller accepts a bid, triggering ownership transfer and cash settlement.
/// </summary>
public sealed class Trade
{
    /// <summary>Unique identifier for this trade.</summary>
    public Guid Id { get; init; }

    /// <summary>The listing that was fulfilled by this trade.</summary>
    public Guid ListingId { get; init; }

    /// <summary>The pet that changed ownership.</summary>
    public Guid PetId { get; init; }

    /// <summary>The trader who sold the pet.</summary>
    public Guid SellerId { get; init; }

    /// <summary>The trader who purchased the pet.</summary>
    public Guid BuyerId { get; init; }

    /// <summary>The final price at which the trade was executed (accepted bid amount).</summary>
    public decimal TradePrice { get; init; }

    /// <summary>UTC timestamp when the trade was executed.</summary>
    public DateTimeOffset ExecutedAt { get; init; }
}
