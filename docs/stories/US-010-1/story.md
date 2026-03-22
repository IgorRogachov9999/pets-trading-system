# US-010.1: View Real-Time Leaderboard

**Epic:** EPIC-010 — Leaderboard
**Jira:** [PTS-65](https://igorrogachov9999.atlassian.net/browse/PTS-65)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want to see all registered traders ranked by portfolio value so that I can track relative performance and adjust strategy.

## Acceptance Criteria

- [ ] All registered traders displayed with their current portfolio value
- [ ] Ranked by descending portfolio value (highest first)
- [ ] Portfolio value formula consistent with trader panel: availableCash + lockedCash + sum(intrinsicValue of owned pets)
- [ ] Leaderboard updates within 2 seconds of any trade
- [ ] Leaderboard updates within 2 seconds of any valuation tick
- [ ] Leaderboard is visible to all logged-in traders (not private)
- [ ] Leaderboard shows trader email or display name as identifier

## Business Rules

- BR-010-001: All registered traders appear on the leaderboard
- BR-010-003: Ranked by descending portfolio value
- BR-010-004: Updates within 2 seconds of any trade
- BR-010-005: Updates within 2 seconds of any valuation tick

## Dependencies

- Blocked by: US-001.1 (session init), US-005.1 (portfolio changes on trade), US-011.1 (tick updates)
- Blocks: US-010.2 (consistency validation)
