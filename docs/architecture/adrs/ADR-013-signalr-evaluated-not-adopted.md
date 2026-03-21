# ADR-013: SignalR Evaluated -- Retain API Gateway WebSocket API

## Status
Accepted

## Context
The team evaluated whether to replace AWS API Gateway WebSocket API with ASP.NET Core SignalR for real-time communication. SignalR is the .NET-native real-time framework with excellent developer ergonomics (strongly-typed hubs, automatic transport negotiation, built-in group management). The question is whether these benefits justify the additional infrastructure and operational complexity on AWS.

Key considerations:
- The system requires real-time push for trade events, bid notifications, lifecycle tick updates, and leaderboard refreshes (< 2 seconds latency)
- The backend runs on ECS Fargate with 2+ tasks behind an ALB
- AWS has **no managed SignalR service** equivalent to Azure SignalR Service
- All client traffic currently routes through API Gateway (REST + WebSocket)

## Decision
**Retain API Gateway WebSocket API** (as documented in ADR-007). Do not adopt SignalR.

### Reasons

1. **Backplane requirement.** SignalR on multi-instance ECS Fargate requires a backplane (Redis via ElastiCache) to relay messages across instances. Without it, a message published on Fargate Task A will not reach clients connected to Fargate Task B. ElastiCache Redis adds infrastructure cost, provisioning, security group rules, and monitoring.

2. **Sticky sessions.** SignalR's negotiate endpoint must be handled by the same instance that will hold the WebSocket connection. This requires ALB sticky sessions, which conflict with even load distribution and complicate rolling deployments.

3. **Traffic path split.** Adopting SignalR means WebSocket traffic bypasses API Gateway (clients connect directly to ALB). This loses WAF protection on real-time connections and creates two different ingress paths (API Gateway for REST, ALB for WebSocket).

4. **No managed offering.** Azure SignalR Service offloads connection management, backplane, and scaling to a managed service. On AWS, all of this is self-managed. The operational burden negates SignalR's developer experience advantage.

5. **Hackathon context.** The glue code for API Gateway WebSocket (Lambda handlers, DynamoDB connection table) is straightforward boilerplate. Transport fallback (SignalR's key advantage over raw WebSocket) is unnecessary in a controlled demo environment.

## Consequences
**Easier:**
- No additional infrastructure (no ElastiCache Redis)
- Consistent traffic routing through API Gateway for all client communication
- WAF protection on both REST and WebSocket endpoints
- Simpler deployment (no sticky sessions, no backplane health monitoring)

**Harder:**
- Developer experience remains lower -- manual message serialization, no strongly-typed hub methods
- No automatic transport fallback (WebSocket-only; clients on restrictive networks may fail)
- Connection management remains manual (DynamoDB table, GoneException handling)

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **SignalR on ECS with ElastiCache Redis backplane** | Adds ElastiCache Redis, sticky sessions, split traffic path. Operational complexity not justified for hackathon |
| **SignalR on ECS with SNS/SQS custom backplane** | Non-standard, high implementation effort, no community support |
| **Azure SignalR Service (cross-cloud)** | Project is committed to AWS. Cross-cloud networking adds latency and cost |
| **AWS AppSync Subscriptions** | GraphQL subscription model; team prefers REST + WebSocket (rejected in ADR-007) |

## Future Consideration
If this system evolves to production with a .NET team and an existing Redis cluster, revisiting SignalR would be worthwhile. The developer ergonomics are significantly better for complex real-time scenarios (presence tracking, group-based messaging, reconnection with message replay). At that point, the ElastiCache Redis backplane cost is amortized across other caching use cases.
