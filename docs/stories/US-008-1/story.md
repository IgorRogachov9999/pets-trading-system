# US-008.1: Browse Active Listings in Market View

**Epic:** EPIC-008 — Market View
**Jira:** [PTS-55](https://igorrogachov9999.atlassian.net/browse/PTS-55)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want to see all current listings in a shared market view so that I can identify buying opportunities.

## Acceptance Criteria

- [ ] All active listings are visible to all traders simultaneously
- [ ] Each listing shows: breed, type, seller (trader name), asking price, most recent trade price for that breed
- [ ] Default sort: newest listing first (by time of creation)
- [ ] Listings appear in real-time when created; disappear when withdrawn or sold
- [ ] All trader panels see the same market data (no per-trader filtering)

## Business Rules

- BR-008-001: All active listings are shared and visible across all trader sessions
- BR-008-002: Each listing row includes breed, type, seller name, and asking price
- BR-008-004: Default sort order is newest listing first by creation time
- BR-008-005: Listings are removed from the view immediately upon withdrawal or sale

## Dependencies

- Blocked by: US-003.1 (listings created/withdrawn)
- Blocks: US-008.4 (real-time market view updates)
