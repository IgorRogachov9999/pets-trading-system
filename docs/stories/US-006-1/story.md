# US-006.1: View Portfolio Summary

**Epic:** EPIC-006 — Portfolio & Inventory Management
**Jira:** [PTS-52](https://igorrogachov9999.atlassian.net/browse/PTS-52)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want to see my available cash, locked cash, and total portfolio value at all times so that I can make informed trading decisions.

## Acceptance Criteria

- [ ] availableCash, lockedCash, and portfolioValue visible without navigation
- [ ] portfolioValue = availableCash + lockedCash + sum(intrinsicValue of all owned pets)
- [ ] All values shown in currency format with 2 decimal places
- [ ] Values update immediately after any trade
- [ ] Values update within 2 seconds of a valuation tick
- [ ] No data from other traders is visible in this panel

## Business Rules

- BR-006-001: Portfolio value is defined as availableCash + lockedCash + sum(intrinsicValue of owned pets)
- BR-006-004: lockedCash is the sum of all active bid amounts placed by the trader
- BR-006-005: Portfolio data is private and scoped to the authenticated trader

## Dependencies

- Blocked by: US-001.1 (session initialized — trader account must exist)
- Blocks: none
