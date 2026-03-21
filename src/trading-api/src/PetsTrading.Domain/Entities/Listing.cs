namespace PetsTrading.Domain.Entities;

/// <summary>
/// A marketplace listing created by a trader to sell one of their pets.
/// At most one active listing is allowed per pet at any time.
/// Withdrawing a listing rejects all active bids and returns the pet to inventory.
/// </summary>
public sealed class Listing
{
    /// <summary>Unique identifier for this listing.</summary>
    public Guid Id { get; init; }

    /// <summary>The pet being listed for sale. One active listing per pet maximum.</summary>
    public Guid PetId { get; init; }

    /// <summary>The trader offering this pet for sale.</summary>
    public Guid SellerId { get; init; }

    /// <summary>Minimum acceptable price. Must be greater than zero.</summary>
    public decimal AskingPrice { get; set; }

    /// <summary>
    /// Indicates whether this listing is currently open for bids.
    /// Set to false when withdrawn or when a trade completes.
    /// </summary>
    public bool IsActive { get; set; }

    /// <summary>UTC timestamp when the listing was created.</summary>
    public DateTimeOffset CreatedAt { get; init; }
}
