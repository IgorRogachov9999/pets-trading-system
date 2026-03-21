# ADR-002: ECS Fargate for Container Orchestration

## Status
Accepted (Updated -- see note below)

## Context
The backend services need a container orchestration platform that supports long-running services (Trading API) and persistent background tasks (Lifecycle Engine tick loop). The solution should minimize operational overhead within a hackathon timeline while supporting auto-scaling, health checks, and integration with ALB.

> **Update (2026-03-21):** The Lifecycle Engine workload has been moved from ECS Fargate to AWS Lambda + EventBridge Scheduler (see [ADR-015](./ADR-015-lifecycle-lambda-eventbridge-scheduler.md)). ECS Fargate remains the compute platform for the **Trading API Service** only. The rationale, consequences, and alternatives below still apply to the Trading API Service.

## Decision
Use **Amazon ECS with Fargate** launch type for running containerized .NET microservices.

## Consequences
**Easier:**
- No cluster management or EC2 instance provisioning
- Integrated with ALB for load balancing and health checks
- IAM task roles for fine-grained AWS service access (no credentials in containers)
- Auto-scaling based on CPU/memory metrics
- CloudWatch Logs integration via awslogs driver
- ECS service automatically restarts failed tasks (critical for singleton Lifecycle Engine)

**Harder:**
- Less flexibility than EKS for complex orchestration patterns
- Fargate pricing is ~20% higher than self-managed EC2 for equivalent compute
- No SSH access to running containers for debugging (use ECS Exec instead)
- Container startup time slightly higher than EC2 launch type

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **EKS (Kubernetes)** | Excessive complexity for hackathon; cluster management overhead; longer setup time |
| **Lambda-only** | Cannot run persistent tick loop; 15-minute execution limit; cold start latency for .NET |
| **App Runner** | Limited control over networking (no VPC placement at the time); no background service support |
| **EC2 with Docker Compose** | Manual instance management; no auto-healing; no integration with ALB target groups |
