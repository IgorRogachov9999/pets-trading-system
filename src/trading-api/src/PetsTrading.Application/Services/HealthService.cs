namespace PetsTrading.Application.Services;

/// <summary>
/// Returns basic application health status.
/// Expanded in later stories to include database readiness checks.
/// </summary>
public sealed class HealthService
{
    /// <summary>Returns a status message indicating the application is operational.</summary>
    public string GetStatus() => "Pets Trading System API is running";
}
