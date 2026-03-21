namespace PetsTrading.Domain.Enums;

/// <summary>
/// Lifecycle states for a <see cref="Entities.Bid"/>.
/// Only one bid may be in the <see cref="Active"/> state per listing at any time.
/// </summary>
public enum BidStatus
{
    /// <summary>The bid is the current highest bid and is awaiting seller action.</summary>
    Active,

    /// <summary>The seller accepted this bid; a trade has been executed.</summary>
    Accepted,

    /// <summary>The seller explicitly rejected this bid; locked cash is released.</summary>
    Rejected,

    /// <summary>The bidder voluntarily withdrew their bid; locked cash is released.</summary>
    Withdrawn,

    /// <summary>
    /// A higher bid was placed on the same listing; this bid's locked cash is released
    /// and an outbid WebSocket notification is sent to the previous bidder.
    /// </summary>
    Outbid
}
