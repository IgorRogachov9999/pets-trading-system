# US-013.1: View Account Summary

**Epic:** EPIC-013 — Account Management
**Jira:** [PTS-71](https://igorrogachov9999.atlassian.net/browse/PTS-71)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want to see my account summary so that I have a single page showing my identity and financial position.

## Acceptance Criteria

- [ ] Account page shows: registered email, available cash, locked cash, portfolio value
- [ ] Portfolio value formula consistent with trader panel: availableCash + lockedCash + sum(intrinsicValue of owned pets)
- [ ] Account page is accessible from the trader panel (e.g., header link or profile menu)
- [ ] Data on account page is consistent with trader panel values (no rounding difference > $0.01)

## Business Rules

- BR-013-006: Account page must display identity and financial summary consistent with the trader panel

## Dependencies

- Blocked by: US-000.1 (must be authenticated)
- Blocks: US-013.2 (inventory view), US-013.3 (top up), US-013.4 (withdraw)
