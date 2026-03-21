# ADR-016: Absolute Timestamp-Based Pet Aging

## Status
Accepted

## Context
The original design incremented pet age on every tick: `pet.age += tick_interval / (365 * 24 * 3600)`. This tick-based approach has several drawbacks:

- **Drift accumulation**: If ticks are delayed or skipped (Lambda timeout, transient failure), pets age slower than real time. Over many missed ticks, ages diverge significantly from wall-clock time.
- **Non-determinism**: The age of a pet depends on how many ticks have successfully executed since creation, making it difficult to verify correctness or reproduce values.
- **Migration fragility**: Changing the tick interval (e.g., from 60s to 30s) would change the aging rate unless explicitly compensated.
- **Query complexity**: Determining a pet's "true" age requires trusting that every tick since creation executed successfully.

## Decision
Derive pet age from an **absolute timestamp calculation**: `age = (NOW() - created_at)` converted to years.

Implementation details:
- The `pets.created_at` column (already present) is the single source of truth for age
- The `pets.age` column is retained as a **cache column**, refreshed on every lifecycle tick for query convenience (avoids computing age in every SELECT)
- `is_expired` is derived: `age >= lifespan` (also refreshed each tick)
- Health and desirability variance remains **tick-based** (random +/-5% per tick) -- these are intentionally stochastic and do not need wall-clock derivation
- The intrinsic value formula is unchanged: `BasePrice * (Health/100) * (Desirability/10) * max(0, 1 - Age/Lifespan)`
- The Lifecycle Lambda computes `age = EXTRACT(EPOCH FROM (NOW() - created_at)) / (365.25 * 24 * 3600)` on each tick

## Consequences
**Easier:**
- Pet age is always correct regardless of missed ticks -- no drift accumulation
- Age can be independently verified: `SELECT created_at` is sufficient to compute current age
- Tick interval changes do not affect aging rate
- Simpler mental model: age = elapsed real time since creation
- Queries that need current age can compute it on the fly without waiting for a tick

**Harder:**
- The cached `age` column may be up to 60 seconds stale between ticks (acceptable for display purposes)
- Two different update mechanisms in one tick: timestamp-derived age vs. random-walk health/desirability (conceptual asymmetry, but justified by their different natures)

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Tick-incremented age (original)** | Drift accumulation on missed ticks, non-deterministic, fragile under interval changes |
| **Remove `age` column entirely, always compute** | Adds `NOW() - created_at` to every query; cached column is cheaper for frequent reads |
| **Timestamp-based age for all attributes (health, desirability)** | Health and desirability are intentionally stochastic (random walk); deriving them from timestamps would require a deterministic PRNG seeded per pet, adding complexity for no business benefit |
