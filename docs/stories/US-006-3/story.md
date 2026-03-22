# US-006.3: Understand Locked Cash Separately

**Epic:** EPIC-006 — Portfolio & Inventory Management
**Jira:** [PTS-54](https://igorrogachov9999.atlassian.net/browse/PTS-54)
**Priority:** High
**Labels:** `frontend`

## User Story

As a Trader, I want to see my locked cash separately so that I know how much I have available to spend.

## Acceptance Criteria

- [ ] lockedCash is shown separately from availableCash
- [ ] lockedCash increases when a bid is placed
- [ ] lockedCash decreases when a bid is accepted, rejected, or withdrawn
- [ ] Tooltip or label clarifies: "Cash locked in active bids"
- [ ] availableCash never includes locked cash

## Business Rules

- BR-006-004: lockedCash is the sum of all active bid amounts placed by the trader; it is always separate from availableCash

## Dependencies

- Blocked by: US-001.1 (session initialized — trader account must exist)
- Blocks: none
