using Microsoft.AspNetCore.Mvc;

namespace PetsTrading.TradingApi.Controllers;

/// <summary>
/// Unauthenticated smoke-test endpoint used during frontend development and integration validation.
/// Returns a fixed JSON payload so the UI can confirm it has reached the Trading API.
/// This endpoint is intentionally anonymous — do not put business logic here.
/// </summary>
[ApiController]
[Route("api/v1")]
public sealed class TestController : ControllerBase
{
    /// <summary>
    /// Returns a fixed JSON message confirming the API is reachable.
    /// Useful for frontend smoke tests and local development without Cognito credentials.
    /// </summary>
    /// <returns>HTTP 200 with <c>{ "message": "Pets Trading System API is running" }</c>.</returns>
    [HttpGet("test")]
    [ProducesResponseType(typeof(TestResponse), StatusCodes.Status200OK)]
    public IActionResult GetTest()
    {
        return Ok(new TestResponse("Pets Trading System API is running"));
    }

    /// <summary>Response body for the test endpoint.</summary>
    public sealed record TestResponse(string Message);
}
