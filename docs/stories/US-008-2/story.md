# US-008.2: View Most Recent Trade Price per Breed

**Epic:** EPIC-008 — Market View
**Jira:** [PTS-57](https://igorrogachov9999.atlassian.net/browse/PTS-57)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want to see the most recent trade price for each breed so that I can benchmark a fair bid.

## Acceptance Criteria

- [ ] Most recent trade price shown per breed (not per pet instance)
- [ ] Trade price updates immediately when a trade completes
- [ ] If no trade has occurred for a breed this session: shows "—" or empty
- [ ] Trade price is visible on the listing row without extra navigation

## Business Rules

- BR-008-003: Trade price is tracked and displayed per breed; shows the last completed trade amount

## Dependencies

- Blocked by: US-005.1 (trade price updated on trade completion)
- Blocks: US-008.4 (real-time market view updates)
