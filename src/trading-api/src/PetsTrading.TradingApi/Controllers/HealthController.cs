using Microsoft.AspNetCore.Mvc;
using PetsTrading.Application.Services;

namespace PetsTrading.TradingApi.Controllers;

/// <summary>
/// Liveness probe endpoint used by ECS health checks and API Gateway readiness validation.
/// Returns 200 when the process is up and able to handle requests.
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
    /// Returns a JSON body confirming the API is operational.
    /// </summary>
    /// <returns>HTTP 200 with <c>{ "message": "Pets Trading System API is running" }</c>.</returns>
    [HttpGet("health")]
    [ProducesResponseType(typeof(HealthResponse), StatusCodes.Status200OK)]
    public IActionResult GetHealth()
    {
        return Ok(new HealthResponse(_healthService.GetStatus()));
    }

    /// <summary>Response body for the health endpoint.</summary>
    public sealed record HealthResponse(string Message);
}
