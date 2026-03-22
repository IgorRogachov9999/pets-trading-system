# US-005.1: Accept a Bid

**Epic:** EPIC-005 — Trade Execution (Accept / Reject)
**Jira:** [PTS-47](https://igorrogachov9999.atlassian.net/browse/PTS-47)
**Priority:** High
**Labels:** `backend`, `frontend`

## User Story

As a Trader (seller), I want to accept a bid so that the trade executes and I receive payment.

## Acceptance Criteria

- [ ] "Accept" action is shown when the listing has an active bid
- [ ] On accept: pet removed from seller's inventory immediately
- [ ] On accept: pet added to buyer's inventory immediately
- [ ] On accept: bid amount moved from buyer's lockedCash to seller's availableCash
- [ ] Listing removed from Market View immediately
- [ ] Market View records the trade amount as the most recent trade price for that breed
- [ ] Seller notification: "Trade completed — [Breed] sold to [Buyer] for $X"
- [ ] Buyer notification: "Bid accepted — [Breed] purchased from [Seller] for $X"
- [ ] All trader panels and leaderboard refresh within 2 seconds

## Business Rules

- BR-005-001: Trade execution transfers pet ownership atomically
- BR-005-002: Bid amount moves from buyer's lockedCash to seller's availableCash on accept
- BR-005-003: Listing is removed from Market View upon trade completion
- BR-005-005: Most recent trade price is recorded per breed on Market View

## Dependencies

- Blocked by: US-003.1 (listing must exist), US-004.1 (bid must be active)
- Blocks: US-007.1 (trade.completed and bid.accepted notifications)
