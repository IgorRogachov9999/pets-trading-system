# ADR-014: Microsoft Orleans Evaluated -- Retain PostgreSQL for State Management

## Status
Accepted

## Context
The team evaluated whether to adopt Microsoft Orleans (virtual actor model / grain-based distributed state) for state management, potentially replacing or supplementing RDS PostgreSQL (ADR-003) as the primary data layer.

Orleans maps naturally to the domain: each Trader, Pet, Listing, and Bid could be a grain with in-memory state, single-threaded execution (eliminating concurrency issues), and built-in timer support (replacing the lifecycle tick loop). Orleans Streams could replace EventBridge + Lambda for the notification pipeline.

Key considerations:
- The system has ~60 pets (20 breeds x 3 supply), a handful of traders, and a 1-minute tick interval
- The backend runs on ECS Fargate on AWS
- AWS has no managed Orleans hosting (unlike Azure Service Fabric or Azure Kubernetes Service)
- The current architecture uses PostgreSQL with SERIALIZABLE isolation for trading operations

### Note on data layer
The current primary database is **RDS PostgreSQL** (ADR-003), not DynamoDB. DynamoDB is used only for WebSocket connection tracking (ADR-007). Orleans would replace PostgreSQL as the state management layer, not DynamoDB.

## Decision
**Do not adopt Microsoft Orleans.** Retain RDS PostgreSQL as the primary data store with the existing service-oriented architecture.

### Reasons

1. **Operational complexity on AWS.** Orleans requires silo-to-silo communication (port 11111) and a cluster membership provider. On ECS Fargate with dynamic IP assignment, this requires:
   - AWS Cloud Map for service discovery, OR a DynamoDB/PostgreSQL membership provider where each silo self-registers
   - Security group rules allowing silo-to-silo traffic within the ECS service
   - Careful handling of silo graceful shutdown during ECS rolling deployments

   This is all solvable but represents significant infrastructure work with limited community precedent on Fargate.

2. **Scale does not justify the complexity.** The entire dataset (60 pets, handful of traders, ~100 listings at most) fits comfortably in PostgreSQL. Single-digit millisecond query times are achievable with proper indexing. Orleans' in-memory grain state provides microsecond improvements that are imperceptible at this scale.

3. **Hackathon risk profile.** If silo clustering fails during the demo, the entire system is down. PostgreSQL is battle-tested infrastructure with well-understood failure modes. Orleans on ECS Fargate is an uncommon deployment target with limited production references.

4. **Persistence still needed.** Orleans grains can be deactivated (evicted from memory) at any time. Grain state must be persisted to survive deactivation. The most natural persistence target on AWS is either DynamoDB (`Microsoft.Orleans.Persistence.DynamoDB`) or PostgreSQL (`Orleans.Persistence.AdoNet`). If using PostgreSQL for persistence, the database is still required -- Orleans becomes an in-memory caching layer with actor semantics on top, adding complexity without eliminating the database.

5. **Learning curve.** Even for experienced .NET developers, Orleans introduces concepts (grain lifecycle, activation/deactivation, reentrancy policies, stateless worker grains, silo configuration) that require study. Time spent learning Orleans is time not spent on domain features.

6. **Existing patterns are sufficient.** PostgreSQL SERIALIZABLE transactions handle bid concurrency. The lifecycle engine singleton with a PostgreSQL advisory lock handles tick coordination. The notification pipeline (EventBridge + Lambda) handles fan-out. These are proven, simple patterns.

## Consequences
**Easier:**
- No new infrastructure (no silo clustering, no membership provider, no Cloud Map)
- PostgreSQL remains the single source of truth -- queryable, debuggable, backupable
- Team works with familiar patterns (SQL, transactions, REST APIs)
- Deployment remains straightforward (ECS rolling update, no silo drain/graceful shutdown concerns)

**Harder:**
- Concurrency handled via database isolation levels (more complex SQL, potential contention under high load)
- Lifecycle tick loop remains a singleton service with advisory locking (less elegant than per-grain timers)
- No built-in actor-model benefits (must manually avoid race conditions in application code)
- Real-time notification pipeline remains multi-service (EventBridge -> Lambda -> API Gateway Management API)

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Orleans on ECS Fargate with DynamoDB membership + persistence** | Full Orleans stack. Highest developer experience but highest operational risk. Silo networking on Fargate is non-trivial |
| **Orleans on ECS Fargate with PostgreSQL membership + persistence** | Reuses existing RDS. Still requires silo-to-silo networking. Adds Orleans complexity without eliminating the database |
| **Orleans on EKS (Kubernetes)** | Better Orleans clustering support via Kubernetes membership provider. But EKS was rejected in favor of Fargate (ADR-002) for simplicity |
| **Dapr (Distributed Application Runtime)** | Sidecar-based actor model. Similar operational complexity to Orleans, less .NET-native |
| **Custom in-memory caching (MemoryCache + pub/sub)** | Lighter weight than Orleans but loses actor semantics. Does not solve the multi-instance coordination problem |

## Future Consideration
If the system evolves to production scale with hundreds of concurrent traders and sub-second tick intervals, Orleans becomes a compelling choice. The grain-per-entity model eliminates database contention for hot entities, and Orleans' built-in timers simplify the lifecycle engine. At that scale, the investment in silo clustering infrastructure (likely on EKS with the Kubernetes membership provider) pays for itself.

Additionally, Orleans 8 (expected with .NET 9) includes improvements to grain directory performance and simplified clustering that may reduce the operational overhead on non-Azure platforms.
