# System Design Reference

## Design Template

Use this template when designing a new component, service, or feature. It keeps decisions explicit and reviewable.

```markdown
# Design: {Component or Feature Name}

## Requirements

### Functional
- What the component must do (user-facing behaviour)
- Core operations and their inputs/outputs

### Non-Functional
- Performance: response time target (p95)
- Availability: uptime / failover requirement
- Scalability: expected load, growth rate
- Security: auth, data sensitivity, compliance

### Constraints
- Infrastructure budget / AWS services available
- Team skills and existing stack
- Timeline

## High-Level Design

[ASCII diagram or description of components and data flow]

## Component Details

### [Component A]
- Technology choice and rationale
- Responsibilities
- Scaling approach

### [Component B]
...

## Key Decisions

| Decision | Rationale |
|---|---|
| [Choice made] | [Why this over alternatives] |

## Scaling Strategy

### Current (MVP)
- Describe initial deployment topology

### Future (10× growth)
- How to scale each bottleneck

## Security Considerations
- Auth/authz approach
- Data protection
- Network isolation

## Failure Modes

| Failure | Impact | Mitigation |
|---|---|---|
| [Component down] | [Effect on users] | [Recovery mechanism] |

## Open Questions
- Things still to be decided
```

---

## This Project: Key Design Decisions Already Made

### Trading API (ECS Fargate)

| Concern | Decision | Rationale |
|---|---|---|
| Runtime | .NET 10 + Minimal APIs | Performance, team skill |
| Data access | Dapper + PostgreSQL | ACID, no ORM overhead |
| Auth | Cognito JWT, validated in middleware | Offload auth management |
| WebSocket push | Direct API GW Management API call | No extra Lambda hop |
| Scaling | ECS Fargate auto-scaling on CPU/memory | Stateless, easy horizontal scale |

### Lifecycle Lambda

| Concern | Decision | Rationale |
|---|---|---|
| Trigger | EventBridge Scheduler, rate(1 minute) | Simple, no polling |
| Responsibilities | Health/desirability variance, age cache refresh | Isolated from user request path |
| State | Stateless — reads + writes PostgreSQL only | No DynamoDB or Redis needed |
| Package | Container image via ECR | Consistent with Trading API |

### Data Flow: Bid Placement

```
Client
  │ POST /v1/listings/{id}/bids
  ▼
API Gateway (REST) → Cognito authorizer
  ▼
Trading API (ECS)
  ├─ Validate request (FluentValidation)
  ├─ Begin PostgreSQL transaction
  │   ├─ SELECT listing FOR UPDATE
  │   ├─ Reject previous bid, release locked cash
  │   ├─ Deduct new bidder cash, insert new bid
  │   └─ COMMIT
  ├─ Push WebSocket notification (outbid → prev bidder, bid.received → seller)
  │   via API Gateway Management API + DynamoDB connection lookup
  └─ Return 201 Created
```

### Data Flow: Lifecycle Tick

```
EventBridge Scheduler (rate: 1 min)
  ▼
Lifecycle Lambda
  ├─ SELECT all pets from PostgreSQL
  ├─ For each pet:
  │   ├─ Apply ±5% health variance
  │   ├─ Apply ±5% desirability variance
  │   ├─ Derive age from (NOW - created_at)
  │   ├─ Calculate intrinsic_value
  │   └─ Set is_expired = (age >= lifespan)
  └─ Batch UPDATE pets (age cache, health, desirability, intrinsic_value, is_expired)
```

---

## Failure Mode Analysis

| Failure | Impact | Mitigation |
|---|---|---|
| RDS primary down | Full API outage | RDS Multi-AZ failover < 60 s |
| ECS task crash | Brief downtime | ECS desired count ≥ 2; ALB health check restarts |
| Lambda tick fails | Pets not updated for 1 min | Idempotent tick; next run catches up |
| DynamoDB throttle | WebSocket notification dropped | Polly retry; client re-polls via REST anyway |
| API Gateway WebSocket disconnect | Client misses live notification | Frontend re-polls every 5 s as safety net |
| Secrets Manager unavailable | App can't start | Cached secret in ECS task env on startup |
