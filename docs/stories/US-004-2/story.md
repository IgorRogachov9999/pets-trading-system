# US-004.2: Only Highest Bid is Active Per Listing

**Epic:** EPIC-004 — Bid Placement & Management
**Jira:** [PTS-45](https://igorrogachov9999.atlassian.net/browse/PTS-45)
**Priority:** High
**Labels:** `backend`

## User Story

As the system, I want to ensure only the highest bid is active per listing so that the market is fair.

## Acceptance Criteria

- [ ] When a new bid arrives, it is compared to the current active bid
- [ ] If the new bid is higher: previous bid rejected atomically, previous bidder's cash released, new bid becomes active
- [ ] If the new bid is equal to or lower than the active bid: new bid rejected with error
- [ ] Previous bidder receives outbid notification immediately
- [ ] Seller receives new highest bid notification

## Business Rules

- BR-004-004: Only one active bid is allowed per listing at a time
- BR-004-005: A new bid must be strictly higher than the current active bid to replace it

## Dependencies

- Blocked by: US-004.1 (bidding must be possible first)
- Blocks: _none_
