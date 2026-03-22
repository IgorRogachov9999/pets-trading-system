# US-004.4: Withdraw Own Bid

**Epic:** EPIC-004 — Bid Placement & Management
**Jira:** [PTS-48](https://igorrogachov9999.atlassian.net/browse/PTS-48)
**Priority:** High
**Labels:** `backend`, `frontend`

## User Story

As a Trader, I want to withdraw my active bid so that I can free my locked cash for other trades.

## Acceptance Criteria

- [ ] "Withdraw Bid" action visible on any active bid in the bidder's panel
- [ ] On withdrawal: lockedCash decreases, availableCash increases by the bid amount immediately
- [ ] Listing returns to "no active bid" state in Market View
- [ ] Bidder's bid status updates to "withdrawn"
- [ ] Seller receives notification: "Bid of $X on [Breed] withdrawn by [Trader]"
- [ ] Trader can place a new bid on a different listing with the freed cash

## Business Rules

- BR-004-006: Bidder can withdraw their own active bid at any time

## Dependencies

- Blocked by: US-003.1 (listings must exist)
- Blocks: _none_
