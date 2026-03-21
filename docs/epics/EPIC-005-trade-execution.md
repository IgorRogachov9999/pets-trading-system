# EPIC-005: Trade Execution (Accept / Reject)

> **Epic ID:** EPIC-005
> **Priority:** Must Have
> **Status:** Ready for Development

---

## Summary

When a bid is placed on a seller's listing, the seller can accept or reject it. Accepting executes the trade immediately: ownership transfers, cash transfers, the listing closes, and all panels refresh. Rejecting releases the bidder's locked cash and keeps the listing open for further bids.

---

## End-to-End Workflow

**Accept Flow:**
```
Seller Views Active Bid → Chooses Accept → Ownership Transferred → Cash Transferred → Listing Removed → Both Parties Notified → All Panels Refresh
```

**Reject Flow:**
```
Seller Views Active Bid → Chooses Reject → Bidder's Cash Released → Listing Remains Open → Bidder Notified
```

---

## User Stories

### US-005.1 — Accept a Bid
> As a Trader (seller), I want to accept a bid so that the trade executes and I receive payment.

**Acceptance Criteria:**
- [ ] "Accept" action is shown when the listing has an active bid
- [ ] On accept: pet removed from seller's inventory immediately
- [ ] On accept: pet added to buyer's inventory immediately
- [ ] On accept: bid amount moved from buyer's `lockedCash` to seller's `availableCash`
- [ ] Listing removed from Market View immediately
- [ ] Market View records the trade amount as the most recent trade price for that breed
- [ ] Seller notification: "Trade completed — [Breed] sold to [Buyer] for $X"
- [ ] Buyer notification: "Bid accepted — [Breed] purchased from [Seller] for $X"
- [ ] All trader panels and leaderboard refresh within 2 seconds

---

### US-005.2 — Reject a Bid
> As a Trader (seller), I want to reject a bid so that I can wait for a better offer.

**Acceptance Criteria:**
- [ ] "Reject" action is shown when the listing has an active bid
- [ ] On reject: bidder's `lockedCash` released to `availableCash` immediately
- [ ] Listing remains visible in Market View at the same asking price
- [ ] Listing shows "no active bid" state after rejection
- [ ] Bidder notification: "Your bid of $X on [Breed] was rejected by [Seller]"
- [ ] Seller's view updates to show no active bid on the listing
- [ ] Seller can wait for another trader to place a new bid

---

### US-005.3 — No Action When No Bid
> As a Trader (seller), I cannot accept or reject if there is no active bid.

**Acceptance Criteria:**
- [ ] Accept and Reject actions are hidden/disabled when no bid exists on the listing
- [ ] Seller sees a clear state indicator: "No active bid"

---

## Business Rules

| ID | Rule |
|----|------|
| BR-005-001 | Trade executes immediately on acceptance — no pending/settlement phase |
| BR-005-002 | Ownership and cash transfer are atomic — both happen or neither happens |
| BR-005-003 | The most recent trade price for a breed is recorded in the Market View on every accepted trade |
| BR-005-004 | Rejecting a bid releases locked cash but keeps the listing open |
| BR-005-005 | All UI panels must refresh within 2 seconds of a completed trade |

---

## State After Trade Execution

| Entity | Before | After Accept |
|--------|--------|--------------|
| Pet | In seller's inventory, listed | In buyer's inventory, unlisted |
| Seller cash | `availableCash = X` | `availableCash = X + bid` |
| Buyer cash | `lockedCash = bid` | `lockedCash = 0` (bid amount) |
| Listing | Active in Market View | Removed |
| Trade price | Previous value (or none) | Updated to accepted bid amount |

---

## Out of Scope

- Counter-offers / negotiation
- Partial acceptance
- Escrow or settlement delay
- Trade history / audit log beyond "most recent trade price"

---

## Dependencies

- EPIC-003 (listing must exist)
- EPIC-004 (bid must be active)
- EPIC-006 (inventory and portfolio update)
- EPIC-007 (notifications)
- EPIC-008 (market view update, trade price recorded)
- EPIC-010 (leaderboard refresh)
