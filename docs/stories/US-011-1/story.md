# US-011.1: Automatic Pet Valuation Updates (Tick)

**Epic:** EPIC-011 — Pet Lifecycle Engine
**Jira:** [PTS-67](https://igorrogachov9999.atlassian.net/browse/PTS-67)
**Priority:** High
**Labels:** `backend`, `devops`

## User Story

As the system, I want to update every pet's fundamentals on a configurable interval so that the market reflects a dynamic environment.

## Acceptance Criteria

- [ ] Tick interval is configurable via environment variable TICK_INTERVAL_SECONDS (default: 60 seconds)
- [ ] Every pet (across all traders and supply) is updated on each tick
- [ ] Age increments by: tickIntervalSeconds / (365 × 24 × 3600) years per tick
- [ ] Health changes by a random value in [-5%, +5%] of current health; clamped to [0%, 100%]
- [ ] Desirability changes by a random value in [-5%, +5%] of current value; clamped to [0, breed max]
- [ ] Intrinsic value recalculated for every pet after each tick
- [ ] Age is always derived from (NOW - created_at) — never stored as an increment (ADR-016)
- [ ] pets.age column is a cache refreshed each tick

## Business Rules

- BR-011-001: Tick interval is configurable via TICK_INTERVAL_SECONDS
- BR-011-002: Every pet is updated on each tick
- BR-011-003: Health variance is ±5% of current value, clamped to [0%, 100%]
- BR-011-004: Desirability variance is ±5% of current value, clamped to [0, breed max]
- BR-011-006: Intrinsic value recalculated for every pet after each tick

## Dependencies

- Blocked by: US-001.1 (pets initialized at session start)
- Blocks: US-011.2 (push updates), US-011.3 (expired pet handling), US-011.4 (boundary clamping)
