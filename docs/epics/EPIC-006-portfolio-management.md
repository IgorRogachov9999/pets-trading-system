# EPIC-006: Portfolio & Inventory Management

> **Epic ID:** EPIC-006
> **Priority:** Must Have
> **Status:** Ready for Development

---

## Summary

Each authenticated trader has a private dashboard showing their current financial position and pet inventory. Portfolio value is calculated in real-time as `availableCash + lockedCash + sum(intrinsicValue of owned pets)`. The inventory shows all owned pets with their live fundamentals, flagging listed and expired pets. All values update automatically after every trade and every valuation tick. The account page (EPIC-013) provides additional account-level actions (top-up, withdraw) linked from the trader panel.

---

## End-to-End Workflow

```
Trader Panel Active → View Available Cash / Locked Cash / Portfolio Value → View Inventory → Drill into Pet Fundamentals (links to EPIC-009) → Values Auto-Refresh on Trade or Tick
```

---

## User Stories

### US-006.1 — View Portfolio Summary
> As a Trader, I want to see my available cash, locked cash, and total portfolio value at all times so that I can make informed trading decisions.

**Acceptance Criteria:**
- [ ] `availableCash`, `lockedCash`, and `portfolioValue` visible without navigation
- [ ] `portfolioValue = availableCash + lockedCash + sum(intrinsicValue of all owned pets)`
- [ ] All values shown in currency format with 2 decimal places
- [ ] Values update immediately after any trade
- [ ] Values update within 2 seconds of a valuation tick
- [ ] No data from other traders is visible in this panel

---

### US-006.2 — View Pet Inventory
> As a Trader, I want to see all pets I own with their current fundamentals so that I know what I hold.

**Acceptance Criteria:**
- [ ] All owned pets displayed regardless of listed/expired state
- [ ] Each pet shows: breed, type, current health (%), current age (years, 2 dp), current desirability, current intrinsic value ($)
- [ ] Listed pets are marked as "listed" with their asking price
- [ ] Expired pets (age ≥ lifespan) are marked as "expired" with intrinsicValue shown as $0.00
- [ ] Inventory updates immediately after purchase or trade
- [ ] Inventory updates within 2 seconds of a valuation tick

---

### US-006.3 — Understand Locked Cash
> As a Trader, I want to see my locked cash separately so that I know how much I have available to spend.

**Acceptance Criteria:**
- [ ] `lockedCash` is shown separately from `availableCash`
- [ ] `lockedCash` increases when a bid is placed
- [ ] `lockedCash` decreases when a bid is accepted, rejected, or withdrawn
- [ ] Tooltip or label clarifies: "Cash locked in active bids"
- [ ] `availableCash` never includes locked cash

---

## Business Rules

| ID | Rule |
|----|------|
| BR-006-001 | `portfolioValue = availableCash + lockedCash + sum(intrinsicValue of all owned pets)` |
| BR-006-002 | Portfolio value must be identical here and on the leaderboard for the same trader |
| BR-006-003 | Expired pets contribute $0 intrinsic value but remain in inventory and portfolio |
| BR-006-004 | `lockedCash` is not available for new bids or purchases |
| BR-006-005 | All portfolio values must refresh within 2 seconds of any state change |

---

## Intrinsic Value Formula

```
IntrinsicValue = BasePrice × (Health / 100) × (Desirability / 10) × (1 - Age / Lifespan)
```

Expired condition: `Age ≥ Lifespan` → `IntrinsicValue = 0`

---

## Out of Scope

- Historical portfolio value charts
- P&L tracking (unrealized gains/losses)
- Tax or fee calculations
- Exporting portfolio data
- Top-up / withdraw actions (handled in EPIC-013 — Account Management)

---

## Dependencies

- EPIC-001 (session initialized, starting cash set)
- EPIC-002 (pets added to inventory on purchase)
- EPIC-005 (inventory changes on trade acceptance)
- EPIC-011 (intrinsic values updated on lifecycle tick)
