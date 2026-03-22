# US-013.3: Top Up Balance

**Epic:** EPIC-013 — Account Management
**Jira:** [PTS-73](https://igorrogachov9999.atlassian.net/browse/PTS-73)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want to add cash to my available balance so that I have more money to spend on pets and bids.

## Acceptance Criteria

- [ ] Top-up form accepts a positive dollar amount (> $0)
- [ ] On confirmation, availableCash INCREASES by the top-up amount
- [ ] A confirmation prompt is shown before the top-up executes: "Add $X to your balance? Your available cash will increase from $Y to $Z."
- [ ] On success: new (higher) balance is displayed immediately on the account page and in the trader panel
- [ ] Top-up amount must be > $0; zero or negative amounts are rejected with an error
- [ ] No upper limit on top-up amount (system is virtual)

## Business Rules

- BR-013-001: Balance mutations (top-up and withdraw) must be confirmed before execution
- BR-013-003: Top-up increases availableCash by the specified amount
- BR-013-005: Amount must be > $0; zero or negative amounts are rejected
- BR-013-007: Balance changes must be reflected immediately in all views

## Dependencies

- Blocked by: US-013.1 (account page must exist first)
- Blocks: none
