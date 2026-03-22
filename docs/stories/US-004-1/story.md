# US-004.1: Place a Bid

**Epic:** EPIC-004 — Bid Placement & Management
**Jira:** [PTS-44](https://igorrogachov9999.atlassian.net/browse/PTS-44)
**Priority:** High
**Labels:** `backend`, `frontend`

## User Story

As a Trader, I want to place a bid on a listed pet so that the seller can accept it and transfer ownership to me.

## Acceptance Criteria

- [ ] Bid action is visible on all listings not owned by the active trader
- [ ] Trader enters a bid amount (must be > $0)
- [ ] Bid amount must not exceed trader's availableCash (locked cash is excluded)
- [ ] On valid bid: amount moved from availableCash to lockedCash immediately
- [ ] Bid shows as "active" in the bidder's panel
- [ ] Seller receives notification: "New bid of $X from [Trader] on [Breed]"
- [ ] Bid above or below asking price is accepted (seller decides whether to accept)

## Business Rules

- BR-004-001: Bid amount must be > $0
- BR-004-002: Bid amount must not exceed bidder's availableCash
- BR-004-007: Locked cash from active bids is excluded from availableCash for future bids

## Dependencies

- Blocked by: US-003.1 (listings must exist)
- Blocks: US-004.2, US-004.3
