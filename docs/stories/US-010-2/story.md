# US-010.2: Leaderboard Consistency with Trader Panel

**Epic:** EPIC-010 — Leaderboard
**Jira:** [PTS-66](https://igorrogachov9999.atlassian.net/browse/PTS-66)
**Priority:** High
**Labels:** `backend`

## User Story

As a judge, I want the leaderboard values to match each trader's panel value so that scoring is unambiguous.

## Acceptance Criteria

- [ ] Portfolio value on leaderboard = portfolio value shown on that trader's panel (same formula, same data)
- [ ] No rounding discrepancy > $0.01 between panel and leaderboard for the same trader
- [ ] Rankings re-sort immediately when values change

## Business Rules

- BR-010-002: Portfolio value on leaderboard must match the value on the trader's own panel within $0.01

## Dependencies

- Blocked by: US-001.1 (session init), US-005.1 (portfolio changes on trade), US-011.1 (tick updates)
- Blocks: none
