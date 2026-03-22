using Microsoft.AspNetCore.Mvc;
using PetsTrading.Application.Services;

namespace PetsTrading.TradingApi.Controllers;

/// <summary>
/// Liveness probe endpoint used by ECS health checks and API Gateway readiness validation.
/// Returns 200 plain-text "Healthy" so ECS can match the expected string without JSON parsing.
/// </summary>
[ApiController]
[Route("api/v1")]
public sealed class HealthController : ControllerBase
{
    private readonly HealthService _healthService;

    /// <summary>Initialises the controller with the application health service.</summary>
    public HealthController(HealthService healthService)
    {
        _healthService = healthService;
    }

    /// <summary>
    /// Returns plain-text "Healthy" confirming the process is up and ready to serve requests.
    /// ECS health checks match against this exact string.
    /// </summary>
    /// <returns>HTTP 200 with plain-text body <c>Healthy</c>.</returns>
    [HttpGet("health")]
    [ProducesResponseType(typeof(string), StatusCodes.Status200OK)]
    public IActionResult GetHealth()
    {
        return Content(_healthService.GetStatus(), "text/plain");
    }
}
