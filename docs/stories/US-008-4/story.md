# US-008.4: Market View Updates in Real-Time

**Epic:** EPIC-008 — Market View
**Jira:** [PTS-61](https://igorrogachov9999.atlassian.net/browse/PTS-61)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want the market view to reflect the current state automatically so that I don't miss trading events.

## Acceptance Criteria

- [ ] New listing appears in Market View within 1 second of being created
- [ ] Listing disappears within 1 second of being withdrawn or sold
- [ ] Trade price updates within 1 second of a trade completing
- [ ] Supply count updates within 1 second of a purchase
- [ ] No manual refresh required

## Business Rules

- Per ADR-017: frontend uses REST polling every 5 seconds for market data and WebSocket for trade event notifications; WebSocket events trigger immediate cache invalidation

## Dependencies

- Blocked by: US-008.1 (browse active listings), US-008.2 (trade price per breed), US-008.3 (supply count per breed)
- Blocks: none
