# EPIC-013: Account Management

> **Epic ID:** EPIC-013
> **Priority:** Must Have
> **Status:** Ready for Development

---

## Summary

Each authenticated trader has an account page where they can view a summary of their account, see their full inventory, top up their balance (which **increases** `availableCash`), and withdraw money (which **decreases** `availableCash`). The account page is the personal hub for the trader, distinct from the live trading panel. All changes persist immediately to the database.

---

## End-to-End Workflow

**View Account:**
```
Trader Logs In → Navigates to Account Page → Views Profile (email, current cash, portfolio value) → Views Inventory
```

**Top-Up Balance (increases availableCash):**
```
Trader on Account Page → Enters Top-Up Amount → Confirms → availableCash INCREASES by that amount → Trader Panel Reflects Higher Balance
```

**Withdraw Balance (decreases availableCash):**
```
Trader on Account Page → Enters Withdrawal Amount → Confirms → availableCash DECREASES by that amount → Trader Panel Reflects Lower Balance
```

---

## User Stories

### US-013.1 — View Account Summary
> As a Trader, I want to see my account summary so that I have a single page showing my identity and financial position.

**Acceptance Criteria:**
- [ ] Account page shows: registered email, available cash, locked cash, portfolio value
- [ ] Portfolio value formula consistent with trader panel: `availableCash + lockedCash + sum(intrinsicValue of owned pets)`
- [ ] Account page is accessible from the trader panel (e.g., header link or profile menu)
- [ ] Data on account page is consistent with trader panel values (no rounding difference > $0.01)

---

### US-013.2 — View Inventory from Account Page
> As a Trader, I want to see my full pet inventory on my account page so that I have a complete picture of what I own.

**Acceptance Criteria:**
- [ ] All owned pets listed with: breed, type, health, age, desirability, intrinsic value, listed status, expired status
- [ ] Inventory matches the inventory shown in the trader panel exactly
- [ ] Expired pets shown with intrinsicValue = $0.00 and "Expired" label
- [ ] Listed pets shown with "Listed" label and asking price
- [ ] Inventory is read-only from the account page (no listing/bidding actions from here)

---

### US-013.3 — Top Up Balance (Increases availableCash)
> As a Trader, I want to add cash to my available balance so that I have more money to spend on pets and bids.

**Acceptance Criteria:**
- [ ] Top-up form accepts a positive dollar amount (> $0)
- [ ] On confirmation, `availableCash` **increases** by the top-up amount — the balance goes up
- [ ] A confirmation prompt is shown before the top-up executes: "Add $X to your balance? Your available cash will increase from $Y to $Z."
- [ ] On success: new (higher) balance is displayed immediately on the account page and in the trader panel
- [ ] Top-up amount must be > $0; zero or negative amounts are rejected with an error
- [ ] No upper limit on top-up amount (system is virtual)

---

### US-013.4 — Withdraw Balance (Decreases availableCash)
> As a Trader, I want to withdraw cash from my available balance so that I can reduce my exposure in the system.

**Acceptance Criteria:**
- [ ] Withdrawal form accepts a positive dollar amount (> $0)
- [ ] Withdrawal amount cannot exceed `availableCash` (locked cash is not withdrawable)
- [ ] On confirmation, `availableCash` **decreases** by the withdrawal amount — the balance goes down
- [ ] A confirmation prompt is shown before withdrawal executes: "Withdraw $X from your balance? Your available cash will decrease from $Y to $Z."
- [ ] On success: new (lower) balance is displayed immediately on the account page and in the trader panel
- [ ] On failure (amount > availableCash): error message shown, balance is unchanged
- [ ] Withdrawal of $0 or negative amount is rejected

---

## Business Rules

| ID | Rule |
|----|------|
| BR-013-001 | Top-up and withdrawal operate on `availableCash` only; `lockedCash` is never affected |
| BR-013-002 | Withdrawal cannot exceed the trader's current `availableCash` |
| BR-013-003 | Top-up amount must be > $0; it **increases** `availableCash` |
| BR-013-004 | Withdrawal amount must be > $0 and ≤ `availableCash`; it **decreases** `availableCash` |
| BR-013-005 | Both top-up and withdrawal are instant; no pending/settlement state |
| BR-013-006 | Account page data must always reflect the same state as the trader panel (no stale data) |
| BR-013-007 | Top-up and withdrawal changes are persisted immediately to durable storage |

---

## Out of Scope

- Payment processing or real-money integration
- Withdrawal to an external wallet or bank account
- Transaction fees on top-up or withdrawal
- Transfer of funds between traders via account page (done through trading)
- Account deletion
- Changing email or password (post-MVP)

---

## Dependencies

- EPIC-000 (authentication — user must be logged in to access account page)
- EPIC-006 (portfolio formula used consistently)
- EPIC-011 (intrinsic values must be current on account page inventory)
