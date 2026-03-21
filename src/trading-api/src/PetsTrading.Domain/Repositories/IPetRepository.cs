using PetsTrading.Domain.Entities;

namespace PetsTrading.Domain.Repositories;

/// <summary>
/// Persistence contract for <see cref="Pet"/> instance and <see cref="PetDictionary"/> operations.
/// Implementations use Dapper against PostgreSQL with parameterised queries.
/// </summary>
public interface IPetRepository
{
    /// <summary>Returns a pet instance by identifier, or null if not found.</summary>
    Task<Pet?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Returns all pets owned by the specified trader.</summary>
    Task<IReadOnlyList<Pet>> GetByOwnerAsync(Guid ownerId, CancellationToken cancellationToken = default);

    /// <summary>Returns all pet instances (used by Lifecycle Lambda for batch updates).</summary>
    Task<IReadOnlyList<Pet>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <summary>Inserts a new pet instance and returns it with server-assigned fields.</summary>
    Task<Pet> CreateAsync(Pet pet, CancellationToken cancellationToken = default);

    /// <summary>Transfers ownership of a pet within a caller-supplied transaction.</summary>
    Task UpdateOwnerAsync(Guid petId, Guid newOwnerId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Batch-updates the cached age, health, desirability, intrinsic value, and is_expired
    /// for all pets after a lifecycle tick.
    /// </summary>
    Task BatchUpdateLifecycleAsync(IReadOnlyList<Pet> pets, CancellationToken cancellationToken = default);

    /// <summary>Returns a breed entry from the read-only dictionary.</summary>
    Task<PetDictionary?> GetDictionaryEntryAsync(int dictionaryId, CancellationToken cancellationToken = default);

    /// <summary>Returns all 20 breed entries from the read-only dictionary.</summary>
    Task<IReadOnlyList<PetDictionary>> GetAllDictionaryEntriesAsync(CancellationToken cancellationToken = default);
}
