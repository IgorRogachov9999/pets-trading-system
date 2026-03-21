# EPIC-002: New Pet Supply Purchase

> **Epic ID:** EPIC-002
> **Priority:** Must Have
> **Status:** Ready for Development

---

## Summary

Traders can buy new pets directly from the system's fixed supply at a set retail price. This is the primary way to build an initial inventory. It bypasses the bid/ask mechanism — cash is deducted immediately and the pet is added to inventory. Supply is limited to 3 units per breed and depletes permanently during the session.

---

## End-to-End Workflow

```
View Supply → Select Breed → Confirm Purchase → Cash Deducted → Pet Added to Inventory → Supply Count Decremented → Market View Updated
```

1. Trader opens the supply view (part of Market View or dedicated panel)
2. All 20 breeds displayed with type, retail price, remaining count
3. Trader selects a breed and quantity to buy
4. System validates: sufficient cash + supply available
5. On success: cash deducted, new pet instance created (age=0, health=100%), added to inventory, supply count decremented
6. Supply count update is reflected in real-time for all traders

---

## User Stories

### US-002.1 — Browse Available Supply
> As a Trader, I want to see all 20 breeds with their prices and remaining counts so that I can decide what to buy.

**Acceptance Criteria:**
- [ ] All 20 breeds listed (5 dogs, 5 cats, 5 birds, 5 fish)
- [ ] Each entry shows: breed name, type, retail price, quantity remaining
- [ ] Breeds with 0 remaining are shown as "Out of Stock" (not hidden)
- [ ] Prices exactly match the pet dictionary (e.g., Labrador=$100, Goldfish=$5)
- [ ] Supply counts update in real-time as purchases are made

---

### US-002.2 — Purchase One or More Pets
> As a Trader, I want to buy one or more pets from supply at retail price so that I can build my inventory.

**Acceptance Criteria:**
- [ ] Trader can select a breed and initiate purchase
- [ ] Retail price is deducted from `availableCash` immediately on purchase
- [ ] New pet instance added to trader's inventory with: `age=0`, `health=100%`, `desirability=breed default`
- [ ] Supply count for that breed decrements by 1 per pet purchased
- [ ] Multiple pets of the same breed can be purchased if cash and supply allow
- [ ] Trader's `portfolioValue` updates immediately after purchase

---

### US-002.3 — Handle Purchase Rejection
> As a Trader, I want to receive a clear error if I can't buy a pet so that I understand what's blocking me.

**Acceptance Criteria:**
- [ ] If `availableCash < retail price`: purchase rejected, error message shown, no state change
- [ ] If supply count = 0: purchase rejected, "Out of Stock" message shown
- [ ] Error messages are shown inline (not modal/blocking)
- [ ] Cash and supply remain unchanged after a rejected purchase

---

## Business Rules

| ID | Rule |
|----|------|
| BR-002-001 | New supply purchases use fixed retail price — no bidding or negotiation |
| BR-002-002 | Purchase is not a secondary market trade — it does not generate a trade notification or market price record |
| BR-002-003 | Each new pet starts with `age=0`, `health=100%`, `desirability=breed default value` |
| BR-002-004 | Supply depletes per breed per purchase; once 0, no further purchases of that breed are possible |
| BR-002-005 | A trader can buy multiple pets simultaneously if cash and supply allow |

---

## Pet Dictionary — Retail Prices

| Type | Breed | Lifespan | Desirability | BasePrice |
|------|-------|----------|--------------|-----------|
| Dog | Labrador | 12y | 8 | $100 |
| Dog | Beagle | 13y | 7 | $90 |
| Dog | Poodle | 14y | 9 | $110 |
| Dog | Bulldog | 10y | 6 | $80 |
| Dog | Pit Bull | 11y | 5 | $70 |
| Cat | Siamese | 15y | 9 | $90 |
| Cat | Persian | 14y | 8 | $85 |
| Cat | Maine Coon | 16y | 7 | $80 |
| Cat | Bengal | 12y | 6 | $75 |
| Cat | Sphynx | 13y | 5 | $70 |
| Bird | Parakeet | 8y | 7 | $25 |
| Bird | Canary | 10y | 6 | $20 |
| Bird | Cockatiel | 12y | 8 | $30 |
| Bird | Macaw | 50y | 9 | $120 |
| Bird | Lovebird | 15y | 5 | $15 |
| Fish | Goldfish | 10y | 5 | $5 |
| Fish | Betta | 5y | 6 | $6 |
| Fish | Guppy | 3y | 4 | $4 |
| Fish | Angelfish | 8y | 7 | $8 |
| Fish | Clownfish | 6y | 8 | $10 |

---

## Out of Scope

- Buying multiple breeds in one transaction (each breed is a separate action)
- Discounts or dynamic pricing from supply
- Restocking supply during a session
- Returning pets to supply

---

## Dependencies

- EPIC-001 (session initialized, trader panel active)
- EPIC-006 (portfolio and inventory must update after purchase)
- EPIC-008 (market view must reflect supply count changes)
