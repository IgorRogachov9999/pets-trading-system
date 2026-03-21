# EPIC-003: Secondary Market Listing Management

> **Epic ID:** EPIC-003
> **Priority:** Must Have
> **Status:** Ready for Development

---

## Summary

Traders can list pets they own for sale on the secondary market at a self-determined asking price. Listed pets remain visible in the shared Market View until sold or withdrawn. A trader may withdraw a listing at any time, which automatically rejects any active bid and releases the bidder's locked cash.

---

## End-to-End Workflow

**Create Listing:**
```
Select Pet from Inventory → Set Asking Price → Confirm → Pet Appears in Market View → Bidding Opens
```

**Withdraw Listing:**
```
Select Active Listing → Initiate Withdrawal → Active Bid Rejected (if exists) → Locked Cash Released → Listing Removed → Pet Returns to Unlisted State
```

1. Trader selects a pet from their inventory (must not already be listed)
2. Trader sets asking price (must be > $0)
3. Pet appears in shared Market View immediately
4. Other traders can now bid
5. Seller can accept/reject bids or withdraw the listing at any time
6. Withdrawal: listing removed, any active bid rejected, bidder notified, cash released

---

## User Stories

### US-003.1 — List a Pet for Sale
> As a Trader, I want to list a pet at an asking price so that other traders can bid on it.

**Acceptance Criteria:**
- [ ] Trader can initiate a listing from any unlisted pet in their inventory
- [ ] Asking price input is required; must be a positive number > $0
- [ ] Listed pet appears in the shared Market View immediately after creation
- [ ] Listed pet remains visible in trader's inventory (ownership not transferred)
- [ ] Pet is marked as "listed" with its asking price in the inventory view
- [ ] Asking price of $0 or negative is rejected with an error message
- [ ] A pet that already has an active listing cannot be listed again

---

### US-003.2 — View Own Active Listings
> As a Trader, I want to see all my active listings and their bid status so that I can manage them.

**Acceptance Criteria:**
- [ ] Seller can see all their currently listed pets and asking prices
- [ ] Seller can see whether a bid exists (yes/no indicator) on each listing
- [ ] Seller can view the bid amount and bidder when choosing to act on it
- [ ] Seller cannot see other traders' bid amounts from the Market View
- [ ] Listed pets are visually distinguished from unlisted pets in inventory

---

### US-003.3 — Withdraw a Listing
> As a Trader, I want to withdraw a listing so that I can take my pet off the market.

**Acceptance Criteria:**
- [ ] Withdrawal action available on any of the trader's active listings
- [ ] On withdrawal: listing removed from Market View immediately
- [ ] If an active bid exists: bid status set to "rejected", bidder's locked cash released to available cash
- [ ] Bidder receives notification: "Your bid of $X on [breed] was rejected (listing withdrawn by [Seller])"
- [ ] Seller receives no notification for their own withdrawal
- [ ] Pet returns to "unlisted" state in seller's inventory

---

### US-003.4 — Relist a Pet After Withdrawal
> As a Trader, I want to relist a pet after withdrawing it so that I can adjust my asking price.

**Acceptance Criteria:**
- [ ] After withdrawal, pet is available for relisting immediately
- [ ] Trader can set a new asking price on relist
- [ ] No cooldown or restriction on relisting the same pet

---

## Business Rules

| ID | Rule |
|----|------|
| BR-003-001 | `askingPrice` must be > 0; zero or negative values are rejected |
| BR-003-002 | Only one active listing per pet instance at any time |
| BR-003-003 | Listing does not transfer ownership — the pet still belongs to the seller until a bid is accepted |
| BR-003-004 | Withdrawing a listing automatically rejects any active bid and releases locked cash immediately |
| BR-003-005 | Seller cannot see other traders' bid amounts in the market view; they can only see bid existence |
| BR-003-006 | A trader can have multiple different pets listed simultaneously |

---

## Out of Scope

- Setting expiry dates on listings
- Auction-style auto-close (e.g., listing closes after 24 hours)
- Minimum bid enforcement (seller sets asking price but bidder can bid any amount)
- Listing fees or commissions

---

## Dependencies

- EPIC-001 (session active)
- EPIC-002 (inventory must contain pets before listing)
- EPIC-004 (bidding depends on listings existing)
- EPIC-007 (notifications sent on withdrawal)
- EPIC-008 (market view displays listings)
