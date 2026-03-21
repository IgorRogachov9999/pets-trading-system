# arc42: 11 -- Risks and Technical Debt

## 11.1 Identified Risks

| ID | Risk | Probability | Impact | Mitigation |
|----|------|------------|--------|-----------|
| R-001 | **Shared database between services** -- Lifecycle Lambda and Trading API share PostgreSQL, creating coupling | High | Medium | Acceptable for hackathon. Document as tech debt. If needed later, extract to database-per-service with event-driven sync. |
| R-003 | **WebSocket connection limits** -- API Gateway WebSocket has 500 concurrent connections per route (default) | Low | Medium | Sufficient for hackathon (10-20 traders). For production: request quota increase or use AppSync. |
| R-004 | **Cold start latency on Lambda** -- .NET Lambda cold starts can exceed 3 seconds | Medium | Low | 60-second invocation interval keeps Lambda warm after first invocation. Lifecycle tick latency is not user-facing. Trade notification push from Trading API (ECS) has no cold start. |
| R-005 | **RDS Multi-AZ failover duration** -- ~60 second outage during automatic failover | Low | Medium | Acceptable for hackathon. ECS services and Lambda will automatically reconnect. |
| R-006 | **Terraform state management** -- Remote state in S3 must be initialized before first apply | Low | Low | Document initialization steps. Use S3 backend with DynamoDB locking. |
| R-007 | **Time pressure** -- 4-day hackathon; full architecture may not be implemented | High | High | Prioritize core trading mechanics over infrastructure polish. Use simplified deployment if needed. |
| R-008 | **Cost during hackathon** -- NAT Gateways, Multi-AZ RDS, Fargate running costs | Medium | Low | Use dev environment (single AZ, no NAT) during development. Deploy full prod only for demo. |
| R-009 | **Poll interval vs tick interval alignment** -- Frontend polls every 5s; lifecycle tick runs every 60s. Polls between ticks return identical data. | Low | Low | Acceptable -- consistent polling simplifies frontend logic. Could add `If-None-Match` / ETag caching to reduce payload on unchanged responses. |

## 11.2 Technical Debt Register

| ID | Debt | Incurred Why | Impact | Remediation Plan |
|----|------|-------------|--------|-----------------|
| TD-001 | **Shared database** between Trading API and Lifecycle Lambda | Hackathon time constraint; avoids eventual consistency complexity | Service coupling; schema changes affect both services | Extract separate databases with CDC or event-driven sync |
| TD-002 | **No rate limiting** on individual trader actions | Not required for demo load | Trader could spam bids or purchases | Add per-trader rate limits via API Gateway usage plans |
| TD-003 | **No pagination** on notification/trade history endpoints | Demo scale is small | Memory issues with large datasets | Add cursor-based pagination |
| TD-004 | **No automated database migrations** | Manual SQL scripts for hackathon | Schema drift risk | Add FluentMigrator or EF Core migrations |
| TD-005 | **WebSocket connection tracking in DynamoDB** | API Gateway WebSocket pattern requires external connection store | Additional AWS service; cost | Acceptable -- this is the standard pattern; usage is now minimal (trade events only) |
| TD-006 | **No dead letter queue for failed WebSocket pushes** | Hackathon simplification | Lost WebSocket notification on push failure | Acceptable -- notification is persisted in PostgreSQL regardless; trader sees it on next poll |
| TD-007 | **No blue-green or canary deployment** | Rolling update sufficient for hackathon | Brief service interruption during deploy | Add CodeDeploy with blue-green for ECS |
| TD-008 | **Frontend calculates no values** -- depends entirely on backend | Intentional (single source of truth for formula) | Perceived latency between tick and UI update (up to 5s poll interval) | Could add optimistic updates with validation |
| TD-009 | **Polling overhead for unchanged data** | Simplicity of hybrid approach (ADR-017) | 11 of 12 polls per minute return identical lifecycle data (tick runs once per 60s) | Add HTTP ETag/conditional GET to return 304 Not Modified when data unchanged |

## 11.3 Open Architectural Questions

| ID | Question | Impact | Recommended Resolution |
|----|----------|--------|----------------------|
| OQ-001 | Desirability clamp: [0, breed_default] or [0, 10]? | Affects high-desirability pet values | Recommend [0, breed_default] -- prevents value inflation beyond design intent |
| OQ-005 | Notification retention: indefinite or time-limited? | Storage growth over time | Recommend keep all for hackathon; add TTL index for production |
| OQ-007 | Leaderboard: show offline traders? | Affects query and display | Recommend show all registered traders (requirement says "all registered traders") |
| OQ-008 | Display name vs email on leaderboard? | Registration form and display | Recommend email for hackathon simplicity; add optional display name later |
