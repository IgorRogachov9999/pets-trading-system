namespace PetsTrading.Domain.Entities;

/// <summary>
/// Represents a registered marketplace participant.
/// Portfolio value = AvailableCash + LockedCash + sum(pet intrinsic values).
/// Starting cash is always $150 for new accounts (fixed per business rules).
/// </summary>
public sealed class Trader
{
    /// <summary>Unique identifier for the trader.</summary>
    public Guid Id { get; init; }

    /// <summary>Amazon Cognito subject identifier (sub claim from JWT).</summary>
    public string CognitoSub { get; init; } = string.Empty;

    /// <summary>Email address registered with Cognito.</summary>
    public string Email { get; init; } = string.Empty;

    /// <summary>
    /// Cash available for new bids or supply purchases.
    /// Decremented when a bid is placed; incremented when a bid is rejected/withdrawn.
    /// </summary>
    public decimal AvailableCash { get; set; }

    /// <summary>
    /// Sum of all active bid amounts currently held in escrow.
    /// Released atomically when a bid is accepted, rejected, or outbid.
    /// </summary>
    public decimal LockedCash { get; set; }

    /// <summary>UTC timestamp when the trader account was created.</summary>
    public DateTimeOffset CreatedAt { get; init; }

    /// <summary>UTC timestamp of the last modification to this record.</summary>
    public DateTimeOffset UpdatedAt { get; set; }
}
