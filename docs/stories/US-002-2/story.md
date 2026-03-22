# US-002.2: Purchase Pets from Supply

**Epic:** EPIC-002 — New Pet Supply Purchase
**Jira:** [PTS-38](https://igorrogachov9999.atlassian.net/browse/PTS-38)
**Priority:** High
**Labels:** `backend`, `frontend`

## User Story

As a Trader, I want to buy one or more pets from supply at retail price so that I can build my inventory.

## Acceptance Criteria

- [ ] Trader can select a breed and initiate purchase
- [ ] Retail price is deducted from availableCash immediately on purchase
- [ ] New pet instance added to trader's inventory with: age=0, health=100%, desirability=breed default
- [ ] Supply count for that breed decrements by 1 per pet purchased
- [ ] Multiple pets of the same breed can be purchased if cash and supply allow
- [ ] Trader's portfolioValue updates immediately after purchase

## Business Rules

- BR-002-001: Retail price is fixed per breed from the pet dictionary
- BR-002-002: Cash is deducted atomically on purchase
- BR-002-003: New pet created with initial attributes (age=0, health=100%)
- BR-002-004: Supply count decrements by 1 per purchase
- BR-002-005: Purchase bypasses bid/ask — no listing or bid involved

## Dependencies

- Blocked by: US-001.1 (session initialized)
- Blocks: US-003.1 (need pets in inventory)
