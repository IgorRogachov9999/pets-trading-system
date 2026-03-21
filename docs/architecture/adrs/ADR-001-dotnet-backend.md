# ADR-001: .NET 10 LTS for Backend Microservices

## Status
Accepted (Updated 2026-03-20 -- upgraded from .NET 8 to .NET 10 LTS)

## Context
The Pets Trading System requires a backend capable of handling real-time trading operations with ACID transaction guarantees, financial-precision arithmetic, and WebSocket support. The team needs a framework with strong typing, mature AWS SDK support, and the ability to build containerized microservices efficiently within a 4-day hackathon.

All compute runs as container images: ECS Fargate tasks pull images from ECR, and Lambda functions are deployed as container images (not zip packages with managed runtimes). This container-first deployment model removes any AWS managed runtime version constraint, allowing the team to adopt the latest .NET LTS release freely.

.NET 10, released November 2025 as an LTS release (supported through November 2028), offers meaningful improvements over .NET 8 for this architecture:
- Faster JIT compilation and reduced GC pauses benefit real-time trading workloads
- Smaller chiseled container base images reduce ECR storage and ECS pull times
- Improved ASP.NET Core minimal API performance and enhanced OpenAPI support
- Faster cold starts for container-based Lambda functions compared to .NET 8
- .NET 8 LTS support ends November 2026, making .NET 10 the forward-looking choice

## Decision
Use **.NET 10 LTS (C#)** with **ASP.NET Core** for all backend microservices (Trading API Service and Lifecycle Engine Service) and Lambda functions.

All services are deployed as container images via ECR. Lambda functions use container image deployment (not managed runtime), so there is no AWS Lambda runtime version constraint.

## Consequences
**Easier:**
- Strong type safety reduces runtime errors in financial calculations
- Excellent AWS SDK for .NET with first-class support for ECS, Cognito, Lambda, and EventBridge
- BackgroundService pattern ideal for the lifecycle tick loop
- Dapper ORM provides lightweight, high-performance database access (compatible via .NET Standard 2.0+)
- Native `decimal` type for precise monetary calculations
- Mature dependency injection and middleware pipeline
- .NET 10 performance improvements: faster JIT, lower memory overhead, improved container support
- Chiseled base images reduce container size (~30% smaller than .NET 8 full images)
- LTS support through November 2028 provides a longer support window than .NET 8 (November 2026)

**Harder:**
- Docker image sizes are larger than Go or Node.js alternatives (~150MB chiseled vs ~50MB)
- Lambda cold starts are slower than Node.js/Python (~2s container-based vs ~500ms), though improved over .NET 8
- Smaller community pool of AWS-specific examples compared to Node.js

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Stay on .NET 8 LTS** | Support ends November 2026; .NET 10 offers measurable performance and container improvements at no migration cost |
| **Node.js (Express/NestJS)** | Weaker type safety; floating-point arithmetic risks for financial calculations |
| **Go** | Team less familiar; no native ORM matching Dapper's convenience |
| **Python (FastAPI)** | Performance concerns under load; GIL limitations for concurrent tick processing |
| **Java (Spring Boot)** | Heavier framework; slower startup for containers; more boilerplate |
