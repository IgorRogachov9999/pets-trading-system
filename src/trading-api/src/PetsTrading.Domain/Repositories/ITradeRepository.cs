using PetsTrading.Domain.Entities;

namespace PetsTrading.Domain.Repositories;

/// <summary>
/// Persistence contract for immutable <see cref="Trade"/> records.
/// Implementations use Dapper against PostgreSQL with parameterised queries.
/// </summary>
public interface ITradeRepository
{
    /// <summary>Returns a trade by identifier, or null if not found.</summary>
    Task<Trade?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Returns the most recent trades, newest first (for Market View "most recent trade price").</summary>
    Task<IReadOnlyList<Trade>> GetRecentAsync(int limit, CancellationToken cancellationToken = default);

    /// <summary>Returns all trades involving the specified trader as buyer or seller.</summary>
    Task<IReadOnlyList<Trade>> GetByTraderAsync(Guid traderId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Inserts a completed trade record within a caller-supplied transaction.
    /// Returns the inserted record with server-assigned fields.
    /// </summary>
    Task<Trade> CreateAsync(Trade trade, CancellationToken cancellationToken = default);
}
