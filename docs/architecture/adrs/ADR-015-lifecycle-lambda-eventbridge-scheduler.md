# ADR-015: Lambda + EventBridge Scheduler for Lifecycle Engine

## Status
Accepted

## Context
The Lifecycle Engine was originally designed as an ECS Fargate singleton running a `BackgroundService` with an internal timer loop (ADR-002). This approach introduces several operational concerns:

- **Singleton coordination**: Only one ECS task should process ticks to avoid duplicate updates. This requires a PostgreSQL advisory lock and careful ECS desired-count management.
- **Idle compute**: The Lifecycle Engine is active for only a few hundred milliseconds every 60 seconds, yet an ECS Fargate task runs (and is billed) continuously.
- **ALB health check overhead**: The singleton requires a health-check endpoint and ALB target group solely to keep ECS from restarting a "healthy but idle" container.
- **Failure detection**: If the internal timer stalls (but the container remains healthy), ticks silently stop. ECS health checks cannot detect this.

The Lifecycle Engine workload is a textbook fit for scheduled serverless invocation: short-duration, stateless, periodic, and idempotent.

## Decision
Replace the ECS Fargate singleton BackgroundService with an **AWS Lambda function** triggered by an **Amazon EventBridge Scheduler** rule at a fixed rate of 1 minute.

- The Lambda function uses a **.NET 10 container image** (consistent with ADR-008 and the Trading API Service image build pipeline).
- On each invocation the Lambda: reads all pets from PostgreSQL, applies health/desirability variance, recalculates intrinsic values (age derived from `created_at` per ADR-016), writes updated values back, and exits.
- No EventBridge event is published after the tick completes -- the frontend polls for updated data (see ADR-017).
- The Lambda runs inside the VPC (private app subnets) to reach RDS via the existing security group rules.

## Consequences
**Easier:**
- No singleton coordination -- EventBridge guarantees exactly one invocation per schedule tick
- No idle compute cost -- billed only for execution duration (typically < 1 second)
- No ALB target group, health check endpoint, or ECS task definition for Lifecycle Engine
- Failure is immediately visible: Lambda errors surface in CloudWatch Metrics and can trigger alarms
- Simpler CI/CD pipeline -- one fewer ECS service to deploy; Lambda updated by pushing a new container image to ECR

**Harder:**
- 15-minute Lambda execution limit (not a concern -- tick processing completes in < 5 seconds for 60 pets)
- Cold start latency for .NET container images (mitigated by SnapStart or provisioned concurrency if needed; 60-second interval means warm instances are likely retained)
- Lambda VPC networking requires NAT Gateway or VPC endpoints for AWS API calls (already provisioned for ECS)

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **ECS Fargate singleton (current)** | Idle compute waste, singleton coordination complexity, silent timer stall risk |
| **ECS Scheduled Task** | ECS RunTask has higher cold-start latency (pull image + start container); more expensive than Lambda for sub-second workloads |
| **Step Functions with Wait state** | Adds orchestration complexity for a single-step periodic task |
| **CloudWatch Events (legacy)** | EventBridge Scheduler is the successor with richer scheduling features (time windows, retries) |
