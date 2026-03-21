using PetsTrading.Domain.Enums;

namespace PetsTrading.Domain.Entities;

/// <summary>
/// A bid placed by a trader on an active listing.
/// At most one active bid per listing at any time (highest bid wins).
/// A new higher bid atomically replaces the previous one and releases its locked cash.
/// Traders cannot bid on their own listings.
/// </summary>
public sealed class Bid
{
    /// <summary>Unique identifier for this bid.</summary>
    public Guid Id { get; init; }

    /// <summary>The listing this bid is placed against.</summary>
    public Guid ListingId { get; init; }

    /// <summary>The trader who placed this bid.</summary>
    public Guid BidderId { get; init; }

    /// <summary>
    /// The bid amount. Must be less than or equal to the bidder's availableCash
    /// at the time of placement. This amount is locked in escrow while the bid is active.
    /// </summary>
    public decimal Amount { get; set; }

    /// <summary>Current lifecycle state of this bid.</summary>
    public BidStatus Status { get; set; }

    /// <summary>UTC timestamp when the bid was placed.</summary>
    public DateTimeOffset CreatedAt { get; init; }

    /// <summary>UTC timestamp of the last status change.</summary>
    public DateTimeOffset UpdatedAt { get; set; }
}
