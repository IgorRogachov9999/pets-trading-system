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
    options.AddPolicy("FrontendPolicy", policy =>
    {
        policy
            .WithOrigins(
                "https://d2681j5g1s1ydv.cloudfront.net", // CloudFront distribution (production)
                "http://localhost:5173",                  // Vite dev server
                "http://localhost:3000"                   // Alternative local dev port
            )
            .AllowAnyMethod()
            .AllowAnyHeader()
            .AllowCredentials();
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

// CORS must come before authentication and authorization so preflight OPTIONS
// requests are handled before any auth middleware can reject them.
app.UseCors("FrontendPolicy");
app.MapControllers();

app.Run();

// Expose Program as a partial class so WebApplicationFactory can reference it
// in test projects without requiring InternalsVisibleTo.
public partial class Program { }
