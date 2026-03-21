namespace PetsTrading.Domain.Entities;

/// <summary>
/// Read-only breed reference data. Seeded once; 20 breeds total
/// (5 dogs, 5 cats, 5 birds, 5 fish). Supply = 3 per breed.
/// Never modified by application logic.
/// </summary>
public sealed class PetDictionary
{
    /// <summary>Serial primary key (1-20).</summary>
    public int Id { get; init; }

    /// <summary>Pet category: Dog, Cat, Bird, or Fish.</summary>
    public string Type { get; init; } = string.Empty;

    /// <summary>Breed name, unique within a type.</summary>
    public string Breed { get; init; } = string.Empty;

    /// <summary>Maximum age in years before the pet is considered expired.</summary>
    public int Lifespan { get; init; }

    /// <summary>Base desirability score used as the ceiling for clamping after variance.</summary>
    public decimal Desirability { get; init; }

    /// <summary>Maintenance cost (informational; not used in current formula).</summary>
    public decimal Maintenance { get; init; }

    /// <summary>Retail price deducted directly from availableCash on supply purchase.</summary>
    public decimal BasePrice { get; init; }

    /// <summary>Initial supply count per breed (always 3).</summary>
    public int InitialSupply { get; init; }
}
