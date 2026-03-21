using PetsTrading.Domain.Entities;

namespace PetsTrading.Domain.Repositories;

/// <summary>
/// Persistence contract for <see cref="Notification"/> records.
/// Implementations use Dapper against PostgreSQL with parameterised queries.
/// </summary>
public interface INotificationRepository
{
    /// <summary>
    /// Returns all notifications for the specified trader, ordered chronologically (newest first).
    /// Used by the Trader Panel notification feed.
    /// </summary>
    Task<IReadOnlyList<Notification>> GetByTraderAsync(Guid traderId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Inserts a new notification within a caller-supplied transaction.
    /// Returns the inserted record with server-assigned fields.
    /// </summary>
    Task<Notification> CreateAsync(Notification notification, CancellationToken cancellationToken = default);
}
