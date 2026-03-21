---
name: backend-skill
description: >
  Activate for ANY backend-related task: writing or reviewing .NET 10 / ASP.NET Core code,
  designing or fixing REST or WebSocket APIs, working with PostgreSQL (schema, queries,
  migrations, indexes, transactions), writing Dapper data-access code, AWS infrastructure
  (ECS Fargate, Lambda, API Gateway, Cognito, RDS, Secrets Manager, EventBridge, DynamoDB,
  CloudFront, ECR, WAF, VPC), Terraform IaC, Docker/container builds, GitHub Actions CI/CD,
  security hardening (OWASP, JWT, SQL injection, IAM), observability (CloudWatch, X-Ray,
  structured logging, health checks), microservices patterns, DDD, CQRS, or any code quality
  and database administration task in this project.
---

# Backend Skill

You are an expert backend engineer for the **Pets Trading System** — a real-time virtual pet
marketplace. Apply the guidance below for every backend task. Reference the appropriate file
for deep detail; keep this file as the authoritative entry point.

---

## Project-Specific Non-Negotiables

- **Dapper only — never EF Core.** All data access uses Dapper + parameterized SQL.
- **PostgreSQL is the single source of truth** for all financial data (cash, bids, trades).
- **WebSocket carries exactly 6 event types**: `bid.received`, `bid.accepted`, `bid.rejected`,
  `outbid`, `trade.completed`, `listing.withdrawn`. Nothing else goes over WebSocket.
- **REST polling every 5 s** handles all market/leaderboard/portfolio data. WebSocket events
  trigger `queryClient.invalidateQueries()` on the frontend.
- **Starting cash $150** per new trader; never adjustable via API.
- **Pet age is always derived** from `NOW - created_at`; never stored as an increment (ADR-016).
- **Intrinsic value formula**: `BasePrice × (Health/100) × (Desirability/10) × max(0, 1 - Age/Lifespan)`
- **Sequential actions are sufficient** for consistency — no distributed locking required.
- **JWT tokens come from Amazon Cognito** — validate using Cognito's public JWKS endpoint.
- **Secrets Manager + IAM** for all credentials — no hardcoded secrets anywhere.

---

## 1. API Design

**Reference**: [`references/api-design.md`](references/api-design.md)

- Design resource-oriented URLs (`/traders/{id}/inventory`, not `/getTraderInventory`).
- Use **OpenAPI 3.1** to document every endpoint before implementation.
- Return **RFC 7807 Problem Details** (`application/problem+json`) for all errors.
- Use **cursor-based pagination** for listings and trades (real-time data shifts under offset pagination).
- Version via URL path prefix (`/v1/`). Breaking changes require a new version.
- Enforce rate limits at both API Gateway (throttling) and application level.
- WebSocket routes: `$connect`, `$disconnect`, `$default` plus one route per event type.

Key HTTP status rules: `200` success with body, `201` created (include `Location` header),
`204` no body, `400` validation error, `401` missing/invalid token, `403` forbidden,
`404` not found, `409` conflict (e.g., bid already exists), `422` business rule violation,
`429` rate limited, `500` unexpected server error.

---

## 2. .NET 10 / ASP.NET Core

**Reference**: [`references/dotnet-aspnetcore.md`](references/dotnet-aspnetcore.md)

- Prefer **Minimal APIs** over MVC Controllers for new endpoints; keep route handlers thin.
- Register all services via **constructor injection**; avoid service locator pattern.
- Every I/O call must be `async/await`; pass `CancellationToken` through the full call chain.
- Use `ConfigureAwait(false)` in library/infrastructure code; omit in ASP.NET Core handlers.
- Expose `/health` (liveness) and `/ready` (readiness, checks DB) endpoints.
- Global error handling via `UseExceptionHandler` middleware returning Problem Details.
- Validate JWT with `AddJwtBearer` pointed at Cognito JWKS URI.
- Load secrets at startup from AWS Secrets Manager via the configuration provider.
- Lambda handler: implement `Amazon.Lambda.AspNetCoreServer.Hosting` or custom
  `ILambdaSerializer` handler depending on Lambda invocation type.

---

## 3. PostgreSQL + Dapper

**References**: [`references/database-postgres.md`](references/database-postgres.md) (schema/indexes/migrations) · [`references/dapper-advanced.md`](references/dapper-advanced.md) (Dapper API, transactions, multi-mapping, pitfalls)

- All financial mutations (bid placement, bid replacement, trade execution) run inside
  **explicit transactions** with `SELECT ... FOR UPDATE` row locking.
- Use `NpgsqlDataSource` for connection pooling; never create raw `NpgsqlConnection` directly.
- Add `DefaultTypeMap.MatchNamesWithUnderscores = true` at startup — maps PostgreSQL
  `snake_case` columns to C# `PascalCase` properties automatically.
- Always use **parameterized queries** (`@param` syntax with Dapper) — no string concatenation.
- Index every foreign key, every column in `WHERE`/`ORDER BY` on hot paths (listings, bids, trades).
- `pets.age` is a **cached column** refreshed by the Lifecycle Lambda; never trust it for
  real-time calculations — derive from `created_at` when precision matters.
- Migrations: plain SQL files versioned by timestamp prefix, applied in CI before deploy.
- Use `EXPLAIN ANALYZE` on all non-trivial queries before merging.
- Use `QueryMultipleAsync` for dashboard-style endpoints that need multiple related datasets
  in one round-trip (e.g., trader portfolio + notifications).

---

## 4. AWS Infrastructure

**Reference**: [`references/aws-infrastructure.md`](references/aws-infrastructure.md)

| Component | Details |
|---|---|
| Trading API | ECS Fargate, .NET 10 container image, ECR |
| Lifecycle Engine | Lambda + EventBridge Scheduler (rate: 1 min) |
| API layer | API Gateway REST + WebSocket; WAF + Cognito authorizer |
| Database | RDS PostgreSQL 16 Multi-AZ, private subnet `10.0.x.x/24` |
| WebSocket tracking | DynamoDB `connections` table (`traderId` → `connectionId`, TTL) |
| Frontend hosting | S3 + CloudFront |
| Secrets | AWS Secrets Manager; IAM roles for passwordless access |
| VPC endpoints | ECR, S3, Secrets Manager, CloudWatch, X-Ray, Execute API (7 total) |

- Define all infra in **Terraform**; never use the console for resource creation.
- ECS task roles and Lambda execution roles follow **least-privilege** IAM.
- ECS tasks in private-app subnets; RDS in private-db subnets; ALB in public subnets.
- WAF rules on API Gateway: block common attack patterns, rate-limit by IP.

---

## 5. Architecture, Project Structure & Design Patterns

**References**: [`references/clean-architecture.md`](references/clean-architecture.md) · [`references/architecture-patterns.md`](references/architecture-patterns.md) · [`references/system-design.md`](references/system-design.md) · [`references/adr-reference.md`](references/adr-reference.md) · [`references/nfr-checklist.md`](references/nfr-checklist.md)

- Use **Clean Architecture** layering: `Domain → Application → Infrastructure → Api`.
  Never reference `Infrastructure` from `Api` directly — always through Application interfaces.
- **MediatR CQRS**: Commands in `Application/{Context}/Commands/`, Queries in `Application/{Context}/Queries/`.
  Each command folder contains the command record, handler, and FluentValidation validator.
- **Minimal APIs** in `Api/Endpoints/` — thin mappers to MediatR commands/queries.
- See `clean-architecture.md` for the full solution folder structure and code examples.
- Use `architecture-patterns.md` when choosing between Monolith / Microservices / CQRS / Serverless.
- Use `system-design.md` template when designing a new feature or component.
- New hard-to-reverse architectural decisions → write an ADR. See `adr-reference.md` for format.
  Existing ADRs are in `docs/architecture/adrs/` (ADR-001 through ADR-017).
- Before implementing a feature, verify its NFRs against `nfr-checklist.md` (performance, availability, security, cost).

---

## 6. Microservices & Service Boundaries

**Reference**: [`references/microservices.md`](references/microservices.md)

- **Trading API** owns all business logic. The Lifecycle Lambda is a background tick only.
- Enforce **bounded contexts**: Traders, Pets, Listings/Bids, Trades, Notifications.
- Push WebSocket notifications **directly from the Trading API** after transaction commit via
  API Gateway Management API. No separate notification service.
- Implement **graceful shutdown** in ECS (catch `SIGTERM`, drain in-flight requests).
- Financial operations must be **idempotent** where the client may retry (use idempotency keys).
- Add circuit breakers / retry with exponential backoff for DynamoDB and Secrets Manager calls.
- Use **X-Ray segments/subsegments** to trace the full request path across API Gateway → ECS → RDS.

---

## 7. Security

**Reference**: [`references/security.md`](references/security.md)

- Validate **all** input at the API boundary; reject unknown fields.
- Use Dapper parameterization — SQL injection is never acceptable.
- JWT validation: verify signature (Cognito JWKS), `exp`, `iss`, `aud`, and `token_use`.
- Configure **CORS** to allow only the CloudFront distribution origin.
- Never log JWT tokens, passwords, or PII.
- Audit-log every financial mutation (bid, trade, withdrawal) with trader ID and timestamp.
- Prevent self-bidding at the service layer, not just the DB.
- Apply the **principle of least privilege** to every IAM role and policy.
- Rotate secrets via Secrets Manager rotation Lambdas; never store secrets in env vars or code.

---

## 8. Monitoring & Observability

**Reference**: [`references/monitoring.md`](references/monitoring.md)

- Emit **structured JSON logs** to CloudWatch Logs via `Microsoft.Extensions.Logging` or Serilog.
- Trace every request with **AWS X-Ray** (`AWSXRayRecorder`); instrument Dapper calls as subsegments.
- Define CloudWatch **alarms** for: API 5xx rate > 1%, P99 latency > 1 s, Lambda error rate,
  RDS CPU > 80%, DynamoDB throttling.
- Expose `/metrics` or use CloudWatch custom metrics for business KPIs:
  trade volume, active listings count, active bid count, Lambda tick duration.
- Lambda cold start: keep package size small, use provisioned concurrency only if tick latency
  SLA demands it.
- Use **CloudWatch Dashboards** to surface the above metrics for ops visibility.

---

## 9. Docker & Containers

**Reference**: [`references/dotnet-aspnetcore.md`](references/dotnet-aspnetcore.md) (Docker section)

- Use **multi-stage Dockerfile**: `sdk` stage for build/publish, `aspnet` stage for runtime.
- Pin base image tags (e.g., `mcr.microsoft.com/dotnet/aspnet:10.0`); never use `latest`.
- Run as non-root user inside the container.
- Set `ASPNETCORE_URLS=http://+:8080` and expose port 8080; no TLS termination in the container
  (ALB handles TLS).
- Push to ECR using GitHub Actions OIDC role (no static AWS credentials in CI).
- ECS task definition: set CPU/memory limits, healthcheck command, log driver `awslogs`.

---

## 10. Code Quality & Testing

**References**: [`references/unit-testing.md`](references/unit-testing.md) · [`references/automapper.md`](references/automapper.md)

- Every public method has XML doc comments (`///`).
- Follow **SOLID** principles; keep controllers/handlers under 50 lines.
- **Unit tests** use xUnit + FluentAssertions + Moq + AutoFixture with the **AAA pattern** (Arrange /
  Act / Assert). Test naming: `MethodName_WhenCondition_ExpectedOutcome`. See `unit-testing.md`.
- **Domain tests** are pure in-memory (no I/O); target 95%+ coverage on domain layer.
- **Service tests** mock repositories with NSubstitute; verify orchestration behaviour.
- **Integration tests** use `Testcontainers.PostgreSql` to run Dapper repositories against
  a real PostgreSQL 16 container. Never mock the database.
- Use **Test Data Builders** (`TraderBuilder`, `ListingBuilder`, `PetBuilder`) — keeps tests
  resilient to domain model changes and eliminates repetitive setup code.
- **AutoMapper** handles all Domain → DTO mappings. Mappings live in `Profile` classes, one
  per bounded context. Every profile must have a `config.AssertConfigurationIsValid()` test.
  See `automapper.md` for profile structure and mapping conventions.
- Code review checklist: error handling, input validation, no secrets, async all the way,
  parameterized queries, meaningful log messages, no `Console.Write`.
- Keep `async void` out of production code; use `async Task` everywhere.

---

## 11. Database Administration

**Reference**: [`references/database-postgres.md`](references/database-postgres.md) (DBA section)

- RDS Multi-AZ: primary in AZ-A, standby in AZ-B; automatic failover < 60 s.
- Automated backups: 7-day retention; test restore quarterly.
- Parameter group: set `work_mem`, `shared_buffers`, `max_connections` appropriate for
  Fargate task count and Npgsql pool size.
- Performance Insights enabled; set slow query threshold to 1 s.
- Never run `DROP TABLE` / `TRUNCATE` in production without a snapshot backup first.
- Index maintenance: run `REINDEX CONCURRENTLY` and `VACUUM ANALYZE` as scheduled Lambda tasks
  if RDS auto-vacuum does not keep up with trading workload.
