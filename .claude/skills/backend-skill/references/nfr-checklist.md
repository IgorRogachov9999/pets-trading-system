# Non-Functional Requirements Checklist

Use this checklist when designing features, reviewing PRs, or preparing for production.

---

## Performance

| Requirement | Target for This Project |
|---|---|
| API p95 response time | < 200 ms for read endpoints; < 500 ms for write (bid/trade) |
| WebSocket notification latency | < 500 ms after trade commit |
| Lifecycle Lambda duration | < 10 s per tick (for ~60 pets) |
| RDS query time | < 50 ms for indexed queries; < 100 ms for leaderboard |
| Frontend polling round-trip | < 1 s end-to-end (5 s interval) |

---

## Scalability

| Dimension | Expected Range |
|---|---|
| Concurrent traders | ~20 (hackathon); design for 200 |
| Active listings at once | ≤ 60 (3 per breed × 20 breeds) |
| Requests per second | < 100 peak |
| PostgreSQL connections | ECS tasks × pool size ≤ RDS `max_connections` |
| WebSocket connections | 1 per trader session |

Scale-out path: increase ECS desired task count → increase `Maximum Pool Size` only within RDS `max_connections` headroom.

---

## Availability

| Target | Allowed Downtime/Year | Approach |
|---|---|---|
| 99.9% | 8.76 h | RDS Multi-AZ + ECS desired count ≥ 2 |

- **RPO** (Recovery Point Objective): 0 — PostgreSQL Multi-AZ with synchronous replication.
- **RTO** (Recovery Time Objective): < 5 min — RDS Multi-AZ failover + ECS task restart.
- Automated RDS snapshots: daily, 7-day retention.

---

## Security

| Concern | Requirement |
|---|---|
| Authentication | Cognito JWT; validate signature, `exp`, `iss`, `aud`, `token_use` |
| Authorization | JWT claim `sub` = `traderId`; enforce at service layer |
| Transport | TLS 1.2+ everywhere; no plaintext |
| Secrets | AWS Secrets Manager; IAM roles — no hardcoded credentials |
| SQL injection | Dapper parameterized queries only |
| Input validation | FluentValidation on every request DTO |
| CORS | CloudFront origin only |
| WAF | API Gateway — block OWASP top 10, rate-limit by IP |
| Audit | Structured log entry for every financial mutation |

Compliance: no PCI DSS / HIPAA in scope. GDPR: trader email via Cognito only; no PII in application DB.

---

## Reliability

| Concern | Requirement |
|---|---|
| Idempotency | Bid placement accepts `Idempotency-Key` header; duplicate requests return cached result |
| Transaction safety | All financial mutations inside explicit PostgreSQL transactions |
| Retry on transient errors | Polly: 3 retries, exponential backoff for DynamoDB and Secrets Manager |
| Circuit breaker | Open after 5 consecutive failures on DynamoDB WebSocket push |
| Graceful shutdown | ECS SIGTERM → drain in-flight requests (30 s timeout) before exit |

---

## Observability

| Signal | Implementation |
|---|---|
| Structured logs | `Microsoft.Extensions.Logging` (JSON), CloudWatch Logs |
| Distributed tracing | AWS X-Ray — every inbound request + Dapper subsegments |
| Metrics | CloudWatch custom metrics (EMF) for trade volume, active bids, Lambda tick duration |
| Health endpoints | `/health` (liveness), `/ready` (DB connectivity check) |
| Alarms | API 5xx > 1%, P99 latency > 1 s, Lambda error rate > 5%, RDS CPU > 80% |
| Dashboards | CloudWatch Dashboard with all KPIs |

---

## Maintainability

| Practice | Target |
|---|---|
| Deployment frequency | On every merge to `main` via GitHub Actions |
| Deployment strategy | Rolling update via ECS (min healthy = 100%) |
| Test coverage | Domain layer ≥ 95%, Application layer ≥ 80% |
| Code review | All PRs reviewed before merge; CI gate: build + tests pass |
| SQL migrations | Plain SQL files, timestamp-prefixed, applied in CI before deploy |
| Secrets rotation | Automatic via Secrets Manager rotation Lambda |

---

## Cost

| Resource | Optimisation |
|---|---|
| RDS | `db.t3.micro` for dev; `db.t3.small` Multi-AZ for prod |
| ECS Fargate | 256 CPU / 512 MB per task; scale to 0 in dev environments |
| Lambda | No provisioned concurrency needed (60 s trigger interval) |
| DynamoDB | On-demand billing; TTL on connections table clears stale entries |
| CloudFront | Free tier for S3 SPA origin at hackathon traffic levels |

Set AWS Budget alert at $50/month; review Reserved Instance pricing after 3 months.
