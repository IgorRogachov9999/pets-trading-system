# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

### Backend (.NET 10) — single solution covers Trading API + Lifecycle Lambda

```bash
# From repo root
dotnet restore src/trading-api/PetsTrading.sln

# Build everything (via test projects — transitively builds main projects)
dotnet build src/trading-api/tests/PetsTrading.TradingApi.Tests/PetsTrading.TradingApi.Tests.csproj --no-restore --configuration Release
dotnet build src/trading-api/tests/PetsTrading.LifecycleLambda.Tests/PetsTrading.LifecycleLambda.Tests.csproj --no-restore --configuration Release

# Run all tests (use --no-build if already built)
dotnet test src/trading-api/tests/PetsTrading.TradingApi.Tests/PetsTrading.TradingApi.Tests.csproj --no-build --configuration Release
dotnet test src/trading-api/tests/PetsTrading.LifecycleLambda.Tests/PetsTrading.LifecycleLambda.Tests.csproj --no-build --configuration Release

# Run a single test (by name filter)
dotnet test src/trading-api/tests/PetsTrading.TradingApi.Tests/PetsTrading.TradingApi.Tests.csproj --no-build --configuration Release --filter "FullyQualifiedName~MyTestName"
```

### Frontend (React/Vite)

```bash
cd src/ui
npm install
npm run dev        # local dev server
npm run build      # production build (tsc + vite)
npm test           # vitest run (single pass)
npm run test:watch # vitest watch mode
```

## Project Context

Hackathon project: a real-time virtual pet marketplace where authenticated Traders buy, sell, and bid on pets. Scoring rewards coherent system > feature volume; clear tradeoffs > polish; working deployment > completeness.

## Domain Model

**Trader**: `availableCash`, `lockedCash` (sum of active bids), `inventory[]`, `notifications[]`.
Portfolio value = `availableCash + lockedCash + sum(intrinsicValue of owned pets)`.

**Pet**: Unique instance from a 20-breed read-only dictionary (5 dogs, 5 cats, 5 birds, 5 fish). Supply = 3 per breed, depletes on purchase. Full breed dictionary: `docs/original/pets-trading-system-requirements.md`.

**Listing**: One active listing per pet. `askingPrice > 0`. At most one active bid (highest wins).

**Bid**: Amount ≤ bidder's `availableCash`. Locks cash. States: active, accepted, rejected, withdrawn, outbid.

### Intrinsic Value Formula

```
IntrinsicValue = BasePrice × (Health/100) × (Desirability/10) × max(0, 1 - Age/Lifespan)
```

- **Age** is always derived from `(NOW - created_at)` — never stored as an increment (ADR-016). The `pets.age` column is a cache refreshed each tick.
- Health and desirability fluctuate ±5% per tick (random variance applied by Lifecycle Lambda).
- Expired pets (Age ≥ Lifespan) have `intrinsicValue = 0` but remain tradeable.

## Key Business Rules

- New supply purchases bypass bid/ask — retail price deducted directly.
- Only the highest bid is active per listing; a new higher bid atomically replaces the previous and releases locked cash.
- Traders cannot bid on their own pets.
- Buyers see only their own bid status, not competing bids.
- Withdrawing a listing rejects all active bids and returns the pet to inventory.
- Starting cash: $150 per new account (fixed).
- Sequential actions are sufficient; no distributed locking required.

## Required Views

1. **Trader Panel** (private): inventory, availableCash, lockedCash, portfolioValue, notifications (bid received/accepted/rejected/withdrawn/outbid with pet, price, counterparty — chronological).
2. **Market View** (shared): active listings, askingPrice, most recent trade price, new supply count (newest first).
3. **Analysis / Drill-Down**: per-pet age, health, desirability, intrinsicValue, expired status.
4. **Leaderboard**: all registered traders' portfolioValues, real-time.

## Decided Architecture (AWS)

### Technology Stack

| Layer | Technology | Notes |
|---|---|---|
| Backend | .NET 10 LTS, ASP.NET Core, Dapper | ADR-001 |
| Frontend | React, TypeScript, Vite | Hosted on S3 + CloudFront |
| Database | RDS PostgreSQL 16, Multi-AZ | Single shared DB; ACID for financial ops (ADR-003) |
| Trading API | ECS Fargate (.NET 10 container image via ECR) | ADR-002 |
| Lifecycle Engine | AWS Lambda + EventBridge Scheduler (rate: 1 min) | .NET 10 container image; replaces ECS singleton (ADR-015) |
| Authentication | Amazon Cognito | JWT tokens; Trading API proxies auth calls (ADR-006) |
| API layer | API Gateway (REST + WebSocket) | WAF, throttling, Cognito authorizer (ADR-005) |
| Real-time | Hybrid: REST polling (5s) + WebSocket notifications only | WebSocket carries 6 trade event types only (ADR-017) |
| Infrastructure | Terraform | ADR-009 |
| CI/CD | GitHub Actions | ADR-010 |
| Observability | CloudWatch + X-Ray | ADR-011 |
| Secrets | AWS Secrets Manager | IAM passwordless auth to all AWS services |
| Containers | ECR | All services use container image deployment |

### Service Boundaries

**Trading API Service** (ECS Fargate): All business logic — supply purchases, listings, bids, trade execution, portfolio, leaderboard, notifications. Also pushes WebSocket trade notifications directly to connected clients via API Gateway Management API (no intermediate Lambda).

**Lifecycle Lambda** (EventBridge Scheduler, every 60s): Reads all pets from PostgreSQL, applies ±5% health/desirability variance, derives age from `created_at`, recalculates `intrinsic_value`, updates `pets.age` cache and `is_expired`, writes back. No event publishing after tick — UI updates via frontend polling.

**React SPA** (S3 + CloudFront): Polls REST API every 5 seconds for market/leaderboard/portfolio data. WebSocket connection receives trade notifications only, which trigger immediate `queryClient.invalidateQueries()` for affected views.

### WebSocket Notification Events (6 types)

All pushed directly by the Trading API after trade commits. Connection tracking (traderId → connectionId) is in DynamoDB with TTL.

- `bid.received` → listing owner
- `bid.accepted` / `bid.rejected` → bidder
- `outbid` → previous bidder
- `trade.completed` → buyer + seller
- `listing.withdrawn` → active bidder (if any)

### Network Topology

VPC `10.0.0.0/16` across 2 AZs. Uniform `/24` subnets: public (ALB, NAT GW), private-app (ECS), private-db (RDS). 7 VPC endpoints (ECR, S3, Secrets Manager, CloudWatch, X-Ray, Execute API). CloudFront → S3 for frontend. WAF on API Gateway. See ADR-012.

### Database Schema (key tables)

`traders`, `pets`, `pet_dictionary` (read-only, 20 breeds), `listings`, `bids`, `trades`, `notifications`, `supply_inventory`. Full schema in `docs/architecture/05-building-block-view.md`.

## Architecture Documentation

All architecture docs are in `docs/architecture/`. Published to Confluence space `pettrading`.

- `docs/architecture/00-overview.md` — document index
- `docs/architecture/adrs/` — 17 ADRs (ADR-001 through ADR-017)
- Key ADRs: ADR-013 (SignalR evaluated, rejected), ADR-014 (Orleans evaluated, rejected), ADR-015 (Lifecycle → Lambda), ADR-016 (timestamp-based aging), ADR-017 (hybrid real-time)

## Project Structure

```
pets-trading-system/
├── docs/                        # All documentation
│   ├── original/                # Raw hackathon brief, requirements, judging matrix
│   ├── requirements/            # BRD, user story map, BDD scenarios
│   ├── epics/                   # One file per epic (EPIC-000 through EPIC-013)
│   ├── architecture/            # arc42 docs + adrs/ folder (17 ADRs)
│   ├── stories/                 # User stories (one folder per story)
│   │   └── {story-id}/          # e.g. US-001/
│   │       ├── story.md         # The user story definition
│   │       └── task-{n}.md      # One file per business task in the story
│   └── tasks/                   # Non-business tasks (infra, devops, tech-debt, etc.)
│       └── task-{n}.md          # One file per non-business task
├── designs/                     # UI/UX design artifacts
│   ├── docs/                    # Design descriptions and specs (written by designer agent)
│   └── mockups/                 # Actual design files (.pen files generated by Pencil MCP)
├── terraform/                   # All Terraform infrastructure-as-code
├── src/                         # All source code
│   ├── trading-api/             # .NET 10 Trading API (ECS Fargate)
│   ├── lifecycle-lambda/        # .NET 10 Lifecycle Engine (AWS Lambda)
│   └── ui/                      # React SPA (S3 + CloudFront)
└── ai-env.json                  # AI environment declarative config
```

## Documentation Layout

- `docs/original/` — raw hackathon brief, requirements, judging matrix
- `docs/requirements/` — BRD, user story map, BDD scenarios
- `docs/epics/` — one file per epic (EPIC-000 through EPIC-013)
- `docs/architecture/` — arc42 docs + `adrs/` folder (17 ADRs)

## AI Environment

- `ai-env.json` — declarative config for MCP servers, skills, agents. Run `/ai-env` to sync.
- MCP servers: Atlassian (Confluence + Jira), Zephyr (test management), AWS Documentation, GitHub, Microsoft Docs, AWS Terraform
- Pencil MCP is available via user-level config (not in `.mcp.json`) for design work

### Specialized Agents

Use the `Agent` tool with the appropriate `subagent_type` to dispatch work:

| Agent | `subagent_type` | Use for |
|-------|----------------|---------|
| solution-architect | `"solution-architect"` | Architecture decisions, ADRs, Confluence docs |
| ui-ux-designer | `"ui-ux-designer"` | UI/UX design specs, Pencil `.pen` files |
| senior-dotnet-dev | `"senior-dotnet-dev"` | .NET 10 backend, PostgreSQL, Lambda, REST/WebSocket APIs |
| senior-devops-engineer | `"senior-devops-engineer"` | Terraform, GitHub Actions CI/CD, AWS infrastructure |
| react-frontend-dev | `"react-frontend-dev"` | React SPA, TanStack Query, WebSocket client, Cognito auth |

The `team-lead` skill orchestrates all five agents for feature-level work (decomposition → Jira tickets → execution → integration verification).

## Session Logging

At the end of **every** response, invoke the `response-logger` skill. No exceptions.
