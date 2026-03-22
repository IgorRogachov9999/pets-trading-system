# US-004.5: Hold Multiple Active Bids Simultaneously

**Epic:** EPIC-004 — Bid Placement & Management
**Jira:** [PTS-50](https://igorrogachov9999.atlassian.net/browse/PTS-50)
**Priority:** High
**Labels:** `backend`, `frontend`

## User Story

As a Trader, I want to place bids on multiple different listings at the same time so that I can pursue multiple opportunities.

## Acceptance Criteria

- [ ] Trader can have active bids on multiple different pet listings simultaneously
- [ ] Each bid locks its respective amount in lockedCash
- [ ] Total lockedCash = sum of all active bid amounts
- [ ] availableCash is reduced accordingly so over-bidding is prevented
- [ ] Each bid is independent — withdrawing one does not affect others

## Business Rules

- BR-004-007: Locked cash from all active bids is summed and excluded from availableCash

## Dependencies

- Blocked by: US-003.1 (listings must exist)
- Blocks: _none_
