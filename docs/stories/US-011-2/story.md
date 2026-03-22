# US-011.2: Push Valuation Updates to All Clients

**Epic:** EPIC-011 — Pet Lifecycle Engine
**Jira:** [PTS-68](https://igorrogachov9999.atlassian.net/browse/PTS-68)
**Priority:** High
**Labels:** `backend`, `frontend`

## User Story

As a Trader, I want all panels to refresh automatically after a tick so that I see current data without manual reload.

## Acceptance Criteria

- [ ] All trader panels refresh within 2 seconds of tick completion
- [ ] Portfolio values recalculated and pushed immediately
- [ ] Leaderboard values recalculated and pushed immediately
- [ ] Inventory intrinsic values updated in place (no page reload)
- [ ] No manual refresh action required from the trader

## Implementation Note

Per ADR-017, frontend polls REST every 5s for updated values; WebSocket only carries trade event notifications.

## Business Rules

- BR-011-007: All trader panels must reflect updated values within 2 seconds of tick completion

## Dependencies

- Blocked by: US-011.1 (tick must be implemented first)
- Blocks: none
