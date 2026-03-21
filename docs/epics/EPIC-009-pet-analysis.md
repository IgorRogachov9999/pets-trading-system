# EPIC-009: Pet Analysis / Drill-Down View

> **Epic ID:** EPIC-009
> **Priority:** Must Have
> **Status:** Ready for Development

---

## Summary

Any trader can drill into a detailed fundamentals view for any pet — owned, listed, or belonging to another trader. The analysis view shows the pet's current age, health, desirability, maintenance cost, intrinsic value (with formula), and expired status. This view is the primary tool for making informed bid decisions.

---

## End-to-End Workflow

```
Trader Sees Pet (in Market View or Inventory) → Opens Analysis/Drill-Down → Views All Fundamentals → Sees Intrinsic Value Calculation → Decides Whether to Bid or List → Values Auto-Update on Tick
```

---

## User Stories

### US-009.1 — View Pet Fundamentals
> As a Trader, I want to view the detailed fundamentals of any pet so that I can determine whether a price is fair.

**Acceptance Criteria:**
- [ ] Analysis view accessible from Market View listings and inventory entries
- [ ] View shows: age (years, 2 dp), health (%), desirability (numeric), maintenance cost ($), intrinsic value ($), expired status (yes/no)
- [ ] Accessible for any pet — owned, listed by another trader, or from supply
- [ ] Intrinsic value shown matches formula: `BasePrice × (Health/100) × (Desirability/10) × (1 - Age/Lifespan)`
- [ ] Values reflect the most recent tick (not stale)

---

### US-009.2 — Understand Intrinsic Value Calculation
> As a Trader, I want to see how the intrinsic value is calculated so that I can understand the pet's true worth.

**Acceptance Criteria:**
- [ ] Intrinsic value formula is shown or accessible in the view
- [ ] Component values (BasePrice, Health, Desirability, Age, Lifespan) are all visible
- [ ] Calculated result matches the formula to within $0.01 rounding

---

### US-009.3 — Identify Expired Pets
> As a Trader, I want to see clearly when a pet is expired so that I know its intrinsic value is zero.

**Acceptance Criteria:**
- [ ] Expired status is prominently displayed when `age ≥ lifespan`
- [ ] Intrinsic value shows $0.00 for expired pets
- [ ] Expired pets can still be listed/traded — the view makes no restriction
- [ ] Age and lifespan values are both shown so the trader can verify

---

## Business Rules

| ID | Rule |
|----|------|
| BR-009-001 | Analysis view is read-only; no actions are taken from within it |
| BR-009-002 | View is accessible to all traders for all pets (not restricted to owned pets) |
| BR-009-003 | Intrinsic value must match the backend formula exactly (≤ $0.01 rounding tolerance) |
| BR-009-004 | Expired condition: `age ≥ lifespan` → `intrinsicValue = 0`, pet still tradeable |

---

## Intrinsic Value Formula

```
IntrinsicValue = BasePrice × (Health / 100) × (Desirability / 10) × (1 - Age / Lifespan)
```

**Example — Macaw (age=10.57, health=95.11%, desirability=9, base=$120, lifespan=50):**
```
IV = 120 × (95.11/100) × (9/10) × (1 - 10.57/50)
   = 120 × 0.9511 × 0.9 × 0.7886
   = $105.77
```

---

## Out of Scope

- Editing pet fundamentals from this view
- Comparing multiple pets side-by-side
- Historical intrinsic value charts
- Projected future value calculations

---

## Dependencies

- EPIC-003 (listed pets accessible from Market View)
- EPIC-006 (owned pets accessible from inventory)
- EPIC-011 (values update after lifecycle tick)
