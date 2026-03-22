# US-003.3: Withdraw a Listing

**Epic:** EPIC-003 — Secondary Market Listing Management
**Jira:** [PTS-42](https://igorrogachov9999.atlassian.net/browse/PTS-42)
**Priority:** High
**Labels:** `backend`, `frontend`

## User Story

As a Trader, I want to withdraw a listing so that I can take my pet off the market.

## Acceptance Criteria

- [ ] Withdrawal action available on any of the trader's active listings
- [ ] On withdrawal: listing removed from Market View immediately
- [ ] If an active bid exists: bid status set to "rejected", bidder's locked cash released to available cash
- [ ] Bidder receives notification: "Your bid of $X on [breed] was rejected (listing withdrawn by [Seller])"
- [ ] Seller receives no notification for their own withdrawal
- [ ] Pet returns to "unlisted" state in seller's inventory

## Business Rules

- BR-003-004: Withdrawing a listing rejects all active bids and returns pet to inventory

## Dependencies

- Blocked by: US-003.1 (listings must exist)
- Blocks: US-003.4
