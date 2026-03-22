using System.Net;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace PetsTrading.TradingApi.Tests;

/// <summary>
/// Integration-style tests for the GET /api/v1/health endpoint using WebApplicationFactory.
/// These tests run the full ASP.NET Core pipeline in-process — no network required.
/// ECS health checks require the response body to contain exactly "Healthy" as plain text.
/// </summary>
public sealed class HealthEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public HealthEndpointTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    /// <summary>
    /// GET /api/v1/health must return HTTP 200 with plain-text "Healthy"
    /// so that the ECS health check command can match the expected string.
    /// </summary>
    [Fact]
    public async Task GetHealth_WhenApiIsRunning_Returns200WithPlainTextHealthy()
    {
        // Act
        var response = await _client.GetAsync("/api/v1/health");

        // Assert — status code
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        // Assert — content type is plain text
        response.Content.Headers.ContentType?.MediaType.Should().Be("text/plain");

        // Assert — body is exactly "Healthy"
        var body = await response.Content.ReadAsStringAsync();
        body.Trim().Should().Be("Healthy");
    }
}
