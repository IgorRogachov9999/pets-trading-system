using System.Net;
using System.Text.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace PetsTrading.TradingApi.Tests;

/// <summary>
/// Integration-style tests for the GET /api/v1/test endpoint using WebApplicationFactory.
/// These tests run the full ASP.NET Core pipeline in-process — no network required.
/// The test endpoint is unauthenticated and exists solely for frontend smoke tests.
/// </summary>
public sealed class TestEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public TestEndpointTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    /// <summary>
    /// GET /api/v1/test must return HTTP 200 with a JSON body containing the
    /// fixed "message" field so frontends can confirm API reachability without credentials.
    /// </summary>
    [Fact]
    public async Task GetTest_WhenApiIsRunning_Returns200WithExpectedJsonMessage()
    {
        // Arrange
        const string expectedMessage = "Pets Trading System API is running";

        // Act
        var response = await _client.GetAsync("/api/v1/test");

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
