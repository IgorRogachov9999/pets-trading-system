namespace PetsTrading.Domain.Entities;

/// <summary>
/// A notification record delivered to a trader's notification feed.
/// Notifications are created for the 6 defined WebSocket event types:
/// bid.received, bid.accepted, bid.rejected, outbid, trade.completed, listing.withdrawn.
/// Displayed chronologically in the Trader Panel.
/// </summary>
public sealed class Notification
{
    /// <summary>Unique identifier for this notification.</summary>
    public Guid Id { get; init; }

    /// <summary>The trader who receives this notification.</summary>
    public Guid TraderId { get; init; }

    /// <summary>
    /// Event type string. One of: bid.received, bid.accepted, bid.rejected,
    /// outbid, trade.completed, listing.withdrawn.
    /// </summary>
    public string EventType { get; init; } = string.Empty;

    /// <summary>Breed name of the pet involved in the event.</summary>
    public string PetBreed { get; init; } = string.Empty;

    /// <summary>Monetary amount relevant to the event (bid amount or trade price).</summary>
    public decimal Amount { get; init; }

    /// <summary>Email of the other party involved (buyer or seller).</summary>
    public string CounterpartyEmail { get; init; } = string.Empty;

    /// <summary>Human-readable message summarising the event.</summary>
    public string Message { get; init; } = string.Empty;

    /// <summary>UTC timestamp when this notification was created.</summary>
    public DateTimeOffset CreatedAt { get; init; }
}
