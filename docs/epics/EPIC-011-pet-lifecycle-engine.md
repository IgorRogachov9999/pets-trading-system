# EPIC-011: Pet Lifecycle Engine

> **Epic ID:** EPIC-011
> **Priority:** Must Have
> **Status:** Ready for Development

---

## Summary

A backend tick loop runs every 60 seconds (configurable via environment variable). On each tick, every pet's age increments, health and desirability change by a random ±5% variance (clamped to valid ranges), and intrinsic value is recalculated. Updated values are pushed to all connected clients within 2 seconds. This creates a time-sensitive market where pet values fluctuate continuously.

---

## End-to-End Workflow

```
Tick Interval Fires → For Each Pet: Age++ / Health ±5% / Desirability ±5% → Intrinsic Value Recalculated → All Connected Clients Notified → Panels Refresh (portfolio, inventory, leaderboard)
```

---

## User Stories

### US-011.1 — Automatic Valuation Updates
> As the system, I want to update every pet's fundamentals on a configurable interval so that the market reflects a dynamic environment.

**Acceptance Criteria:**
- [ ] Tick interval is configurable via environment variable (default: 60 seconds)
- [ ] Every pet (across all traders and supply) is updated on each tick
- [ ] Age increments by: `tickIntervalSeconds / (365 × 24 × 3600)` years per tick
- [ ] Health changes by a random value in [-5%, +5%] of current health; clamped to [0%, 100%]
- [ ] Desirability changes by a random value in [-5%, +5%] of current value; clamped to [0, breed max]
- [ ] Intrinsic value recalculated for every pet after each tick

---

### US-011.2 — Push Updates to All Clients
> As a Trader, I want all panels to refresh automatically after a tick so that I see current data without manual reload.

**Acceptance Criteria:**
- [ ] All trader panels refresh within 2 seconds of tick completion
- [ ] Portfolio values recalculated and pushed immediately
- [ ] Leaderboard values recalculated and pushed immediately
- [ ] Inventory intrinsic values updated in place (no page reload)
- [ ] No manual refresh action required from the trader

---

### US-011.3 — Expired Pet Handling
> As the system, I want expired pets (age ≥ lifespan) to show intrinsicValue = 0 while remaining in inventory and tradeable.

**Acceptance Criteria:**
- [ ] Pets with `age ≥ lifespan` display `intrinsicValue = $0.00` in all views
- [ ] Expired pets remain in the owner's inventory (not auto-removed)
- [ ] Expired pets can still be listed for sale
- [ ] Expired pets can still receive bids and be traded
- [ ] Expired pets are clearly flagged as "expired" in inventory and analysis views
- [ ] Portfolio value includes expired pets at $0 intrinsic value (not excluded)

---

### US-011.4 — Health and Desirability Boundaries
> As the system, I want health and desirability to stay within valid bounds regardless of variance.

**Acceptance Criteria:**
- [ ] Health never falls below 0% or rises above 100%
- [ ] Desirability never falls below 0 or rises above breed-default value (open question: or 10?)
- [ ] Clamping is applied after variance calculation, not before
- [ ] A pet at 0% health continues to exist and age; it is not "dead" or removed

---

## Business Rules

| ID | Rule |
|----|------|
| BR-011-001 | Tick interval default is 60 seconds; configurable via `TICK_INTERVAL_SECONDS` env var |
| BR-011-002 | Age increment per tick = `tickIntervalSeconds / (365 × 24 × 3600)` years |
| BR-011-003 | Health variance: ±5% of current value, clamped to [0%, 100%] |
| BR-011-004 | Desirability variance: ±5% of current value, clamped to [0, breed max] |
| BR-011-005 | Expired condition: `age ≥ lifespan` → `intrinsicValue = 0`; pet remains in system |
| BR-011-006 | Intrinsic value formula: `BasePrice × (Health/100) × (Desirability/10) × (1 - Age/Lifespan)` |
| BR-011-007 | All connected clients must receive updated values within 2 seconds of tick completion |

---

## Open Questions

| ID | Question | Impact |
|----|----------|--------|
| OQ-011-001 | Is desirability clamped to [0, breed_default] or [0, 10]? | High-desirability pets (Macaw=9) may or may not exceed their default |
| OQ-011-002 | Should tick interval be configurable at runtime (UI) or only at startup (env var)? | Affects whether a settings panel is needed |

---

## Out of Scope

- Manual health/desirability adjustments
- Breed-specific health or aging curves
- Death/removal of pets at 0% health
- Veterinary actions or maintenance spending

---

## Dependencies

- EPIC-001 (pets initialized at session start)
- EPIC-002 (pets created at purchase with age=0, health=100%)
- EPIC-006 (portfolio values depend on intrinsic values)
- EPIC-010 (leaderboard refreshes on tick)
