# ADR-008: AWS Lambda for Event-Driven Functions

## Status
Accepted

## Context
The system needs to fan out real-time notifications to WebSocket-connected traders when trading events occur. This fan-out logic is event-driven (triggered by trades, bids, ticks) and stateless. Running it as part of the ECS services would couple notification delivery to request processing.

## Decision
Use **AWS Lambda (.NET 10)** deployed as container images (via ECR) for event-driven notification fan-out, triggered by **Amazon EventBridge** events published by the Trading API Service and Lifecycle Engine. Container image deployment eliminates any AWS managed runtime version constraint.

## Consequences
**Easier:**
- Pay-per-invocation; zero cost when no events are firing
- Automatic scaling to handle burst notification volumes
- Clean separation of concerns: ECS handles business logic, Lambda handles push delivery
- EventBridge provides filtered routing (different Lambda handlers for different event types)
- No infrastructure to manage

**Harder:**
- .NET Lambda cold starts (~2-3 seconds) may delay first notification after idle period
- Lambda execution context is ephemeral; no persistent connections
- 15-minute maximum execution time (sufficient for fan-out)
- Debugging distributed Lambda + EventBridge flows requires X-Ray tracing

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Fan-out within ECS service** | Couples notification delivery to API request lifecycle; blocks API response |
| **SQS + ECS consumer** | Adds polling overhead; Lambda is more natural for event-driven fan-out |
| **SNS direct to WebSocket** | SNS cannot push to WebSocket connections directly |
| **Step Functions** | Orchestration overkill for simple fan-out pattern |
