# US-006.2: View Pet Inventory

**Epic:** EPIC-006 — Portfolio & Inventory Management
**Jira:** [PTS-53](https://igorrogachov9999.atlassian.net/browse/PTS-53)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want to see all pets I own with their current fundamentals so that I know what I hold.

## Acceptance Criteria

- [ ] All owned pets displayed regardless of listed/expired state
- [ ] Each pet shows: breed, type, current health (%), current age (years, 2 dp), current desirability, current intrinsic value ($)
- [ ] Listed pets are marked as "listed" with their asking price
- [ ] Expired pets (age ≥ lifespan) are marked as "expired" with intrinsicValue shown as $0.00
- [ ] Inventory updates immediately after purchase or trade
- [ ] Inventory updates within 2 seconds of a valuation tick

## Business Rules

- BR-006-003: Inventory displays all pets owned by the trader regardless of their listing or expiry state

## Dependencies

- Blocked by: US-001.1 (session initialized — trader account must exist)
- Blocks: none
