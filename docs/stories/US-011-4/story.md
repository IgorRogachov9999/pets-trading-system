# US-011.4: Health and Desirability Boundaries

**Epic:** EPIC-011 — Pet Lifecycle Engine
**Jira:** [PTS-70](https://igorrogachov9999.atlassian.net/browse/PTS-70)
**Priority:** High
**Labels:** `backend`

## User Story

As the system, I want health and desirability to stay within valid bounds regardless of variance.

## Acceptance Criteria

- [ ] Health never falls below 0% or rises above 100%
- [ ] Desirability never falls below 0 or rises above breed-default value
- [ ] Clamping is applied after variance calculation, not before
- [ ] A pet at 0% health continues to exist and age; it is not "dead" or removed

## Business Rules

- BR-011-003: Health variance is ±5% of current value, clamped to [0%, 100%]
- BR-011-004: Desirability variance is ±5% of current value, clamped to [0, breed max]

## Dependencies

- Blocked by: US-011.1 (tick must be implemented first)
- Blocks: none
