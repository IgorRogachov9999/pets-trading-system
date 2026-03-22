# US-004.3: Cannot Bid on Own Listing

**Epic:** EPIC-004 — Bid Placement & Management
**Jira:** [PTS-46](https://igorrogachov9999.atlassian.net/browse/PTS-46)
**Priority:** High
**Labels:** `backend`, `frontend`

## User Story

As a Trader, I want the system to prevent me from bidding on my own listing so that self-dealing is impossible.

## Acceptance Criteria

- [ ] Bid action is not shown on listings owned by the active trader
- [ ] If a trader attempts to bid on their own listing (e.g., via API), the bid is rejected
- [ ] Error message indicates self-bidding is not allowed

## Business Rules

- BR-004-003: Traders cannot bid on their own listings

## Dependencies

- Blocked by: US-004.1 (bidding must be possible first)
- Blocks: _none_
