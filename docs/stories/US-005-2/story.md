# US-005.2: Reject a Bid

**Epic:** EPIC-005 — Trade Execution (Accept / Reject)
**Jira:** [PTS-49](https://igorrogachov9999.atlassian.net/browse/PTS-49)
**Priority:** High
**Labels:** `backend`, `frontend`

## User Story

As a Trader (seller), I want to reject a bid so that I can wait for a better offer.

## Acceptance Criteria

- [ ] "Reject" action is shown when the listing has an active bid
- [ ] On reject: bidder's lockedCash released to availableCash immediately
- [ ] Listing remains visible in Market View at the same asking price
- [ ] Listing shows "no active bid" state after rejection
- [ ] Bidder notification: "Your bid of $X on [Breed] was rejected by [Seller]"
- [ ] Seller's view updates to show no active bid on the listing
- [ ] Seller can wait for another trader to place a new bid

## Business Rules

- BR-005-004: On rejection, bidder's lockedCash is released back to availableCash; listing remains active

## Dependencies

- Blocked by: US-003.1 (listing must exist), US-004.1 (bid must be active)
- Blocks: US-007.1 (bid.rejected notification)
