using PetsTrading.Domain.Entities;

namespace PetsTrading.Domain.Repositories;

/// <summary>
/// Persistence contract for <see cref="Listing"/> operations.
/// Implementations use Dapper against PostgreSQL with parameterised queries.
/// </summary>
public interface IListingRepository
{
    /// <summary>Returns an active listing by identifier, or null if not found or inactive.</summary>
    Task<Listing?> GetActiveByIdAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Returns the active listing for a specific pet, or null if no active listing exists.</summary>
    Task<Listing?> GetActiveByPetIdAsync(Guid petId, CancellationToken cancellationToken = default);

    /// <summary>Returns all currently active listings, newest first (for Market View).</summary>
    Task<IReadOnlyList<Listing>> GetAllActiveAsync(CancellationToken cancellationToken = default);

    /// <summary>Creates a new active listing and returns it with server-assigned fields.</summary>
    Task<Listing> CreateAsync(Listing listing, CancellationToken cancellationToken = default);

    /// <summary>
    /// Deactivates the listing within a caller-supplied transaction.
    /// Used on withdrawal and on trade execution.
    /// </summary>
    Task DeactivateAsync(Guid listingId, CancellationToken cancellationToken = default);
}
