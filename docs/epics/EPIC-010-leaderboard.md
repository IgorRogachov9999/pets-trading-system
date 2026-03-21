# EPIC-010: Leaderboard

> **Epic ID:** EPIC-010
> **Priority:** Must Have
> **Status:** Ready for Development

---

## Summary

The leaderboard provides a real-time competitive ranking of all registered traders by their total portfolio value. It is visible to all logged-in traders and updates automatically after every trade and every valuation tick. Portfolio value uses the same formula as the individual trader panel to ensure consistency. The number of traders on the leaderboard is dynamic — it grows as new traders register.

---

## End-to-End Workflow

```
Any State Change (trade / tick) → Backend Recalculates All Portfolio Values → Leaderboard Updated → Pushed to All Clients → Rankings Re-sorted Within 2 Seconds
```

---

## User Stories

### US-010.1 — View Real-Time Leaderboard
> As a Trader, I want to see all registered traders ranked by portfolio value so that I can track relative performance and adjust strategy.

**Acceptance Criteria:**
- [ ] All registered traders displayed with their current portfolio value
- [ ] Ranked by descending portfolio value (highest first)
- [ ] Portfolio value formula consistent with trader panel: `availableCash + lockedCash + sum(intrinsicValue of owned pets)`
- [ ] Leaderboard updates within 2 seconds of any trade
- [ ] Leaderboard updates within 2 seconds of any valuation tick
- [ ] Leaderboard is visible to all logged-in traders (not private)
- [ ] Leaderboard shows trader email or display name as identifier

---

### US-010.2 — Leaderboard Consistency
> As a judge, I want the leaderboard values to match each trader's panel value so that scoring is unambiguous.

**Acceptance Criteria:**
- [ ] Portfolio value on leaderboard = portfolio value shown on that trader's panel (same formula, same data)
- [ ] No rounding discrepancy > $0.01 between panel and leaderboard for the same trader
- [ ] Rankings re-sort immediately when values change

---

## Business Rules

| ID | Rule |
|----|------|
| BR-010-001 | Portfolio formula: `availableCash + lockedCash + sum(intrinsicValue of owned pets)` |
| BR-010-002 | Leaderboard is consistent with each trader's private panel — same formula, same data |
| BR-010-003 | Leaderboard updates within 2 seconds of any trade or valuation tick |
| BR-010-004 | All registered traders always shown; no trader is hidden regardless of rank |
| BR-010-005 | Trader is identified by their registered email or a chosen display name |

---

## Optional Enhancements (Could Have)

- Visual delta indicators (↑↓) showing rank changes
- Breakdown of portfolio components (cash vs. pets)
- Historical rank position

---

## Out of Scope

- Individual pet inventory visible on leaderboard
- Private trader data on leaderboard
- Weighted scoring beyond portfolio value

---

## Dependencies

- EPIC-001 (all 3 traders initialized)
- EPIC-005 (portfolio values change on trade)
- EPIC-006 (portfolio formula)
- EPIC-011 (valuation tick changes intrinsic values)
