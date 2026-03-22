# US-009.1: View Pet Fundamentals in Drill-Down

**Epic:** EPIC-009 — Pet Analysis / Drill-Down View
**Jira:** [PTS-62](https://igorrogachov9999.atlassian.net/browse/PTS-62)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want to view the detailed fundamentals of any pet so that I can determine whether a price is fair.

## Acceptance Criteria

- [ ] Analysis view accessible from Market View listings and inventory entries
- [ ] View shows: age (years, 2 dp), health (%), desirability (numeric), maintenance cost ($), intrinsic value ($), expired status (yes/no)
- [ ] Accessible for any pet — owned, listed by another trader, or from supply
- [ ] Intrinsic value shown matches formula: BasePrice × (Health/100) × (Desirability/10) × (1 - Age/Lifespan)
- [ ] Values reflect the most recent tick (not stale)

## Business Rules

- BR-009-001: Age is derived from `(NOW - created_at)`; never stored as an increment
- BR-009-002: Health and desirability fluctuate ±5% per tick
- BR-009-003: Intrinsic value = BasePrice × (Health/100) × (Desirability/10) × max(0, 1 - Age/Lifespan)
- BR-009-004: Expired pets (Age ≥ Lifespan) have intrinsic value of $0.00 but remain tradeable

## Dependencies

- Blocked by: US-003.1 (listed pets accessible from Market View), US-006.2 (inventory access)
- Blocks: US-009.2 (intrinsic value calculation breakdown), US-009.3 (expired pet identification)
