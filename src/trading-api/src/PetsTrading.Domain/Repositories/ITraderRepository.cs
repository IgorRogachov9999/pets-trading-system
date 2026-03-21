using PetsTrading.Domain.Entities;

namespace PetsTrading.Domain.Repositories;

/// <summary>
/// Persistence contract for <see cref="Trader"/> aggregate operations.
/// Implementations use Dapper against PostgreSQL with parameterised queries.
/// </summary>
public interface ITraderRepository
{
    /// <summary>Returns a trader by their internal identifier, or null if not found.</summary>
    Task<Trader?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Returns a trader by their Cognito subject claim, or null if not found.</summary>
    Task<Trader?> GetByCognitoSubAsync(string cognitoSub, CancellationToken cancellationToken = default);

    /// <summary>Returns all traders, ordered by portfolio value descending (for leaderboard).</summary>
    Task<IReadOnlyList<Trader>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <summary>Inserts a new trader record with $150 starting cash.</summary>
    Task<Trader> CreateAsync(Trader trader, CancellationToken cancellationToken = default);

    /// <summary>Persists cash balance changes atomically within a caller-supplied transaction.</summary>
    Task UpdateCashAsync(Guid traderId, decimal availableCash, decimal lockedCash, CancellationToken cancellationToken = default);
}
