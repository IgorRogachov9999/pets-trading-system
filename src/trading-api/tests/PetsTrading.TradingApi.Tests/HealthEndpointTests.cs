using System.Net;
using System.Text.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace PetsTrading.TradingApi.Tests;

/// <summary>
/// Integration-style tests for the GET /api/health endpoint using WebApplicationFactory.
/// These tests run the full ASP.NET Core pipeline in-process — no network required.
/// </summary>
public sealed class HealthEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public HealthEndpointTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    /// <summary>
    /// GET /api/health must return HTTP 200 with a JSON body containing
    /// the exact "message" field defined in the acceptance criteria.
    /// </summary>
    [Fact]
    public async Task GetHealth_WhenApiIsRunning_Returns200WithExpectedMessage()
    {
        // Arrange
        const string expectedMessage = "Pets Trading System API is running";

        // Act
        var response = await _client.GetAsync("/api/health");

        // Assert — status code
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        // Assert — content type is JSON
        response.Content.Headers.ContentType?.MediaType.Should().Be("application/json");

        // Assert — body contains the expected message field
        var body = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(body);
        doc.RootElement.GetProperty("message").GetString()
            .Should().Be(expectedMessage);
    }
}
