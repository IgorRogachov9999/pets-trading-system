# Architecture Documentation -- Pets Trading System

> **Version:** 1.0
> **Date:** 2026-03-20
> **Status:** Proposed
> **Author:** Solution Architect (AI-assisted)

---

## Document Index

This is the root document for the Pets Trading System architecture documentation, structured using the **arc42** template with **C4 model** diagrams and **Architecture Decision Records (ADRs)**.

### arc42 Sections


| #   | Section                                                      | Description                                        |
| --- | ------------------------------------------------------------ | -------------------------------------------------- |
| 01  | [Introduction and Goals](./01-introduction-and-goals.md)     | Requirements overview, quality goals, stakeholders |
| 02  | [Constraints](./02-constraints.md)                           | Technical, organizational, and legal constraints   |
| 03  | [Context and Scope](./03-context-and-scope.md)               | System boundary, external interfaces, C4 Level 1   |
| 04  | [Solution Strategy](./04-solution-strategy.md)               | Technology decisions, decomposition approach       |
| 05  | [Building Block View](./05-building-block-view.md)           | C4 Level 2 + Level 3 diagrams                      |
| 06  | [Runtime View](./06-runtime-view.md)                         | Key scenarios and sequence flows                   |
| 07  | [Deployment View](./07-deployment-view.md)                   | Infrastructure, network topology, CI/CD            |
| 08  | [Cross-cutting Concepts](./08-cross-cutting-concepts.md)     | Security, logging, error handling, consistency     |
| 09  | [Architecture Decisions](./09-architecture-decisions.md)     | ADR index                                          |
| 10  | [Quality Requirements](./10-quality-requirements.md)         | Quality tree, SLOs, fitness functions              |
| 11  | [Risks and Technical Debt](./11-risks-and-technical-debt.md) | Known risks and mitigation                         |
| 12  | [Glossary](./12-glossary.md)                                 | Domain terms and acronyms                          |


### Architecture Decision Records


| ADR                                                        | Title                                           |
| ---------------------------------------------------------- | ----------------------------------------------- |
| [ADR-001](./adrs/ADR-001-dotnet-backend.md)                | .NET for Backend Microservices                  |
| [ADR-002](./adrs/ADR-002-ecs-fargate-compute.md)           | ECS Fargate for Container Orchestration         |
| [ADR-003](./adrs/ADR-003-rds-postgresql.md)                | RDS PostgreSQL for Primary Database             |
| [ADR-004](./adrs/ADR-004-react-frontend.md)                | React for Frontend SPA                          |
| [ADR-005](./adrs/ADR-005-api-gateway.md)                   | AWS API Gateway for API Management              |
| [ADR-006](./adrs/ADR-006-cognito-auth.md)                  | Amazon Cognito for Authentication               |
| [ADR-007](./adrs/ADR-007-websocket-realtime.md)            | WebSocket via API Gateway for Real-Time Updates |
| [ADR-008](./adrs/ADR-008-lambda-event-driven.md)           | AWS Lambda for Event-Driven Functions           |
| [ADR-009](./adrs/ADR-009-terraform-iac.md)                 | Terraform for Infrastructure as Code            |
| [ADR-010](./adrs/ADR-010-github-actions-cicd.md)           | GitHub Actions for CI/CD Pipeline               |
| [ADR-011](./adrs/ADR-011-cloudwatch-xray-observability.md) | CloudWatch + X-Ray for Observability            |
| [ADR-012](./adrs/ADR-012-vpc-network-topology.md)          | VPC Network Topology Design                     |


### C4 Diagrams

- [C4 Level 1 -- System Context](./03-context-and-scope.md#c4-level-1--system-context-diagram)
- [C4 Level 2 -- Container Diagram](./05-building-block-view.md#c4-level-2--container-diagram)
- [C4 Level 3 -- Component Diagrams](./05-building-block-view.md#c4-level-3--component-diagrams)
- [Infrastructure Diagram](./07-deployment-view.md#infrastructure-diagram)
- [Network Topology](./07-deployment-view.md#network-topology)

