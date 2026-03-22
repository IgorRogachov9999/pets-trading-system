# US-013.2: View Inventory from Account Page

**Epic:** EPIC-013 — Account Management
**Jira:** [PTS-72](https://igorrogachov9999.atlassian.net/browse/PTS-72)
**Priority:** High
**Labels:** `frontend`

## User Story

As a Trader, I want to see my full pet inventory on my account page so that I have a complete picture of what I own.

## Acceptance Criteria

- [ ] All owned pets listed with: breed, type, health, age, desirability, intrinsic value, listed status, expired status
- [ ] Inventory matches the inventory shown in the trader panel exactly
- [ ] Expired pets shown with intrinsicValue = $0.00 and "Expired" label
- [ ] Listed pets shown with "Listed" label and asking price
- [ ] Inventory is read-only from the account page (no listing/bidding actions from here)

## Business Rules

- none specific; behaviour governed by domain model rules for pet display

## Dependencies

- Blocked by: US-013.1 (account page must exist first)
- Blocks: none
