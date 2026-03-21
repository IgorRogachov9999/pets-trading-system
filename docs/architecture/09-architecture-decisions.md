# arc42: 09 -- Architecture Decisions

## ADR Index

All major architectural decisions are documented as Architecture Decision Records (ADRs). Each ADR captures the context, decision, consequences, and alternatives considered.

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [ADR-001](./adrs/ADR-001-dotnet-backend.md) | .NET 10 LTS for Backend Microservices | Accepted (Updated) | 2026-03-20 |
| [ADR-002](./adrs/ADR-002-ecs-fargate-compute.md) | ECS Fargate for Container Orchestration | Accepted (Updated -- Trading API only; Lifecycle moved to Lambda per ADR-015) | 2026-03-20 |
| [ADR-003](./adrs/ADR-003-rds-postgresql.md) | RDS PostgreSQL for Primary Database | Accepted | 2026-03-20 |
| [ADR-004](./adrs/ADR-004-react-frontend.md) | React for Frontend SPA | Accepted | 2026-03-20 |
| [ADR-005](./adrs/ADR-005-api-gateway.md) | AWS API Gateway for API Management | Accepted | 2026-03-20 |
| [ADR-006](./adrs/ADR-006-cognito-auth.md) | Amazon Cognito for Authentication | Accepted | 2026-03-20 |
| [ADR-007](./adrs/ADR-007-websocket-realtime.md) | WebSocket via API Gateway for Real-Time Updates | Accepted (Updated -- trade notifications only per ADR-017) | 2026-03-20 |
| [ADR-008](./adrs/ADR-008-lambda-event-driven.md) | AWS Lambda for Event-Driven Functions | Accepted | 2026-03-20 |
| [ADR-009](./adrs/ADR-009-terraform-iac.md) | Terraform for Infrastructure as Code | Accepted | 2026-03-20 |
| [ADR-010](./adrs/ADR-010-github-actions-cicd.md) | GitHub Actions for CI/CD Pipeline | Accepted | 2026-03-20 |
| [ADR-011](./adrs/ADR-011-cloudwatch-xray-observability.md) | CloudWatch + X-Ray for Observability | Accepted | 2026-03-20 |
| [ADR-012](./adrs/ADR-012-vpc-network-topology.md) | VPC Network Topology Design | Accepted | 2026-03-20 |
| [ADR-013](./adrs/ADR-013-signalr-evaluated-not-adopted.md) | SignalR Evaluated -- Retain API Gateway WebSocket API | Accepted | 2026-03-20 |
| [ADR-014](./adrs/ADR-014-orleans-evaluated-not-adopted.md) | Microsoft Orleans Evaluated -- Retain PostgreSQL for State Management | Accepted | 2026-03-20 |
| [ADR-015](./adrs/ADR-015-lifecycle-lambda-eventbridge-scheduler.md) | Lambda + EventBridge Scheduler for Lifecycle Engine | Accepted | 2026-03-21 |
| [ADR-016](./adrs/ADR-016-absolute-timestamp-pet-aging.md) | Absolute Timestamp-Based Pet Aging | Accepted | 2026-03-21 |
| [ADR-017](./adrs/ADR-017-hybrid-realtime-polling-websocket.md) | Hybrid Real-Time Architecture -- REST Polling + WebSocket Trade Notifications | Accepted | 2026-03-21 |
