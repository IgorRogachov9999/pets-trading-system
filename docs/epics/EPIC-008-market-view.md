# EPIC-008: Market View

> **Epic ID:** EPIC-008
> **Priority:** Must Have
> **Status:** Ready for Development

---

## Summary

The Market View is a shared, read-only panel visible to all traders simultaneously. It displays all active listings (newest first), the most recent trade price per breed, and the remaining new supply count per breed. The view updates in real-time as listings are created, withdrawn, or traded.

---

## End-to-End Workflow

```
Trader Opens Market View → See Active Listings (newest first) → See Most Recent Trade Price per Breed → See Supply Count per Breed → Click Into Listing to Bid or Analyse → View Updates in Real-Time
```

---

## User Stories

### US-008.1 — Browse Active Listings
> As a Trader, I want to see all current listings in a shared market view so that I can identify buying opportunities.

**Acceptance Criteria:**
- [ ] All active listings are visible to all traders simultaneously
- [ ] Each listing shows: breed, type, seller (trader name), asking price, most recent trade price for that breed
- [ ] Default sort: newest listing first (by time of creation)
- [ ] Listings appear in real-time when created; disappear when withdrawn or sold
- [ ] All trader panels see the same market data (no per-trader filtering)

---

### US-008.2 — View Most Recent Trade Price
> As a Trader, I want to see the most recent trade price for each breed so that I can benchmark a fair bid.

**Acceptance Criteria:**
- [ ] Most recent trade price shown per breed (not per pet instance)
- [ ] Trade price updates immediately when a trade completes
- [ ] If no trade has occurred for a breed this session: shows "—" or empty
- [ ] Trade price is visible on the listing row without extra navigation

---

### US-008.3 — View New Supply Count
> As a Trader, I want to see how many new pets remain in supply per breed so that I can decide between supply and secondary market.

**Acceptance Criteria:**
- [ ] Supply count per breed visible in or alongside Market View
- [ ] Shows exact remaining count (e.g., "2 remaining")
- [ ] Count decrements in real-time as purchases are made by any trader
- [ ] Shows "Out of Stock" when count reaches 0

---

### US-008.4 — Market View Updates in Real-Time
> As a Trader, I want the market view to reflect the current state automatically so that I don't miss trading events.

**Acceptance Criteria:**
- [ ] New listing appears in Market View within 1 second of being created
- [ ] Listing disappears within 1 second of being withdrawn or sold
- [ ] Trade price updates within 1 second of a trade completing
- [ ] Supply count updates within 1 second of a purchase
- [ ] No manual refresh required

---

## Business Rules

| ID | Rule |
|----|------|
| BR-008-001 | Market View is shared — all traders see the same data simultaneously |
| BR-008-002 | Default listing order is newest first (by listing creation time) |
| BR-008-003 | Most recent trade price is per-breed, not per pet instance |
| BR-008-004 | Sellers' bid amounts are not shown in Market View (only asking price) |
| BR-008-005 | Expired pets can be listed and appear in Market View like any other listing |

---

## Optional Enhancements (Could Have)

- Sorting by price, breed, or type
- Filtering by type (Dog/Cat/Bird/Fish)
- Highlighting newly added listings
- Visual indicator for expired pet listings

---

## Out of Scope

- Bid history or audit trail in Market View
- Price charts or historical data
- Watchlists or alerts for specific breeds
- Seller identity hidden (sellers are visible)

---

## Dependencies

- EPIC-003 (listings created/withdrawn)
- EPIC-005 (trade price updated on accepted bid)
- EPIC-002 (supply count updated on purchase)
- EPIC-011 (valuation tick may affect listed pet values shown in analysis)
