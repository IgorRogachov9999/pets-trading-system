using PetsTrading.Domain.Entities;
using PetsTrading.Domain.Enums;

namespace PetsTrading.Domain.Repositories;

/// <summary>
/// Persistence contract for <see cref="Bid"/> operations.
/// Implementations use Dapper against PostgreSQL with parameterised queries.
/// Financial mutations (bid placement, replacement) run inside explicit transactions.
/// </summary>
public interface IBidRepository
{
    /// <summary>Returns a bid by identifier, or null if not found.</summary>
    Task<Bid?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>
    /// Returns the current active bid for the given listing, or null if no active bid exists.
    /// At most one bid may be active per listing at any time.
    /// </summary>
    Task<Bid?> GetActiveByListingIdAsync(Guid listingId, CancellationToken cancellationToken = default);

    /// <summary>Returns all bids placed by the specified trader (for Trader Panel display).</summary>
    Task<IReadOnlyList<Bid>> GetByBidderAsync(Guid bidderId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Inserts a new bid within a caller-supplied transaction.
    /// Returns the inserted bid with server-assigned fields.
    /// </summary>
    Task<Bid> CreateAsync(Bid bid, CancellationToken cancellationToken = default);

    /// <summary>
    /// Updates the status of an existing bid within a caller-supplied transaction.
    /// Used for accept, reject, withdraw, and outbid state transitions.
    /// </summary>
    Task UpdateStatusAsync(Guid bidId, BidStatus status, CancellationToken cancellationToken = default);
}
