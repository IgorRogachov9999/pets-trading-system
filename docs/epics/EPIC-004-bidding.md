# EPIC-004: Bid Placement & Management

> **Epic ID:** EPIC-004
> **Priority:** Must Have
> **Status:** Ready for Development

---

## Summary

Traders can place bids on any listed pet they do not own. A bid locks the bid amount in the trader's `lockedCash`. Only one bid is active per listing at any time — if a new higher bid arrives, it atomically replaces the previous bid and releases the prior bidder's locked cash. Bidders can withdraw their own active bids at any time to reclaim their locked cash.

---

## End-to-End Workflow

**Place Bid:**
```
Browse Market → Select Listing → Enter Bid Amount → Validate Cash → Lock Cash → Bid Active → Seller Notified
```

**Outbid Flow:**
```
New Higher Bid Received → Previous Bid Replaced → Previous Bidder's Cash Released → Previous Bidder Notified → New Bid Active
```

**Withdraw Bid:**
```
Select Active Bid → Confirm Withdrawal → Cash Released → Seller Notified → Listing Returns to No-Bid State
```

---

## User Stories

### US-004.1 — Place a Bid
> As a Trader, I want to place a bid on a listed pet so that the seller can accept it and transfer ownership to me.

**Acceptance Criteria:**
- [ ] Bid action is visible on all listings not owned by the active trader
- [ ] Trader enters a bid amount (must be > $0)
- [ ] Bid amount must not exceed trader's `availableCash` (locked cash is excluded)
- [ ] On valid bid: amount moved from `availableCash` to `lockedCash` immediately
- [ ] Bid shows as "active" in the bidder's panel
- [ ] Seller receives notification: "New bid of $X from [Trader] on [Breed]"
- [ ] Bid above or below asking price is accepted (seller decides whether to accept)

---

### US-004.2 — Only Highest Bid is Active
> As the system, I want to ensure only the highest bid is active per listing so that the market is fair.

**Acceptance Criteria:**
- [ ] When a new bid arrives, it is compared to the current active bid
- [ ] If the new bid is higher: previous bid rejected atomically, previous bidder's cash released, new bid becomes active
- [ ] If the new bid is equal to or lower than the active bid: new bid rejected with error
- [ ] Previous bidder receives outbid notification immediately
- [ ] Seller receives new highest bid notification

---

### US-004.3 — Cannot Bid on Own Listing
> As a Trader, I want the system to prevent me from bidding on my own listing so that self-dealing is impossible.

**Acceptance Criteria:**
- [ ] Bid action is not shown on listings owned by the active trader
- [ ] If a trader attempts to bid on their own listing (e.g., via keyboard), the bid is rejected
- [ ] Error message indicates self-bidding is not allowed

---

### US-004.4 — Withdraw Own Bid
> As a Trader, I want to withdraw my active bid so that I can free my locked cash for other trades.

**Acceptance Criteria:**
- [ ] "Withdraw Bid" action visible on any active bid in the bidder's panel
- [ ] On withdrawal: `lockedCash` decreases, `availableCash` increases by the bid amount immediately
- [ ] Listing returns to "no active bid" state in Market View
- [ ] Bidder's bid status updates to "withdrawn"
- [ ] Seller receives notification: "Bid of $X on [Breed] withdrawn by [Trader]"
- [ ] Trader can place a new bid on a different listing with the freed cash

---

### US-004.5 — Bid on Multiple Listings Simultaneously
> As a Trader, I want to place bids on multiple different listings at the same time so that I can pursue multiple opportunities.

**Acceptance Criteria:**
- [ ] Trader can have active bids on multiple different pet listings simultaneously
- [ ] Each bid locks its respective amount in `lockedCash`
- [ ] Total `lockedCash` = sum of all active bid amounts
- [ ] `availableCash` is reduced accordingly so over-bidding is prevented
- [ ] Each bid is independent — withdrawing one does not affect others

---

## Business Rules

| ID | Rule |
|----|------|
| BR-004-001 | Bid amount must be > 0 |
| BR-004-002 | Bid amount must be ≤ trader's `availableCash` at time of bid (locked cash is not available) |
| BR-004-003 | Traders cannot bid on their own listings |
| BR-004-004 | Only one active bid per listing; new higher bid atomically replaces the previous |
| BR-004-005 | A bid equal to or lower than the current active bid is rejected |
| BR-004-006 | Withdrawing a bid immediately releases locked cash back to available cash |
| BR-004-007 | Traders can hold active bids on multiple different listings simultaneously |

---

## State Transitions

```
[No Bid] → place bid → [Active]
[Active] → outbid by higher bid → [Outbid] (cash released)
[Active] → bidder withdraws → [Withdrawn] (cash released)
[Active] → seller accepts → [Accepted] (cash transferred to seller)
[Active] → seller rejects → [Rejected] (cash released)
[Active] → seller withdraws listing → [Rejected] (cash released)
```

---

## Out of Scope

- Bid increments / minimum raise rules
- Automatic bidding / proxy bids
- Bid history (only current active bid tracked per listing)
- Bid timestamps visible to seller

---

## Dependencies

- EPIC-001 (session active)
- EPIC-003 (listings must exist)
- EPIC-005 (seller accepts/rejects bids)
- EPIC-006 (portfolio values update with locked cash changes)
- EPIC-007 (notifications: bid received, outbid, withdrawn)
