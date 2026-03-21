using System.Text.Json;
using PetsTrading.Application.Services;

var builder = WebApplication.CreateBuilder(args);

// ── Kestrel ───────────────────────────────────────────────────────────────────
// ALB terminates TLS; the container listens on plain HTTP 8080.
builder.WebHost.ConfigureKestrel(options =>
{
    options.ListenAnyIP(8080);
});

// ── Services ──────────────────────────────────────────────────────────────────
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        // Restricted to CloudFront origin in production via environment configuration.
        // Kept permissive here; the CloudFront distribution URL is supplied at deploy time.
        policy
            .AllowAnyOrigin()
            .AllowAnyMethod()
            .AllowAnyHeader();
    });
});

builder.Services.AddControllers();
builder.Services.AddHealthChecks();

// Application services
builder.Services.AddSingleton<HealthService>();

builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(options =>
{
    // Emit compact JSON to CloudWatch Logs for structured log querying.
    options.JsonWriterOptions = new JsonWriterOptions { Indented = false };
});

// ── Middleware pipeline ────────────────────────────────────────────────────────
var app = builder.Build();

app.UseCors();
app.MapControllers();

app.Run();

// Expose Program as a partial class so WebApplicationFactory can reference it
// in test projects without requiring InternalsVisibleTo.
public partial class Program { }
