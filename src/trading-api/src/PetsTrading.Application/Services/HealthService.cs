namespace PetsTrading.Application.Services;

/// <summary>
/// Returns basic application health status.
/// Expanded in later stories to include database readiness checks.
/// </summary>
public sealed class HealthService
{
    /// <summary>Returns the ECS health check sentinel string.</summary>
    public string GetStatus() => "Healthy";
}
