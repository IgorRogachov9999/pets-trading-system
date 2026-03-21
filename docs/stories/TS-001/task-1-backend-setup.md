# Task 1: Backend — .NET 10 API Skeleton

**Jira**: [PTS-18](https://igorrogachov9999.atlassian.net/browse/PTS-18)
**Story**: [TS-001](./story.md)
**Label**: `backend`
**Depends on**: nothing

## What to Build

### `src/trading-api/TradingApi/` — ASP.NET Core Web API
- .NET 10 ASP.NET Core Web API project
- Single endpoint: `GET /api/health` → `200 OK`, body `{"message": "Pets Trading System API is running"}`
- CORS: allow any origin (local dev)
- Port 8080, structured logging
- `Dockerfile` (multi-stage, .NET 10, publish to `/app`)

### `src/trading-api/TradingApi.Tests/` — xUnit
- At least one test using `WebApplicationFactory<Program>`
- Verifies health endpoint returns 200 with expected JSON

### `src/trading-api/TradingApi.sln`

## API Contract (used by frontend)

```
GET /api/health
Response: 200 OK
Body: { "message": "Pets Trading System API is running" }
Auth: None
```

## Acceptance Criteria

- `dotnet build src/trading-api/TradingApi.sln` succeeds
- `dotnet test src/trading-api/TradingApi.sln` passes
- `docker build src/trading-api/` produces a valid image
