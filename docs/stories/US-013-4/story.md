# US-013.4: Withdraw Balance

**Epic:** EPIC-013 — Account Management
**Jira:** [PTS-74](https://igorrogachov9999.atlassian.net/browse/PTS-74)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want to withdraw cash from my available balance so that I can reduce my exposure in the system.

## Acceptance Criteria

- [ ] Withdrawal form accepts a positive dollar amount (> $0)
- [ ] Withdrawal amount cannot exceed availableCash (locked cash is not withdrawable)
- [ ] On confirmation, availableCash DECREASES by the withdrawal amount
- [ ] A confirmation prompt is shown before withdrawal executes: "Withdraw $X from your balance? Your available cash will decrease from $Y to $Z."
- [ ] On success: new (lower) balance is displayed immediately on the account page and in the trader panel
- [ ] On failure (amount > availableCash): error message shown, balance is unchanged
- [ ] Withdrawal of $0 or negative amount is rejected

## Business Rules

- BR-013-001: Balance mutations (top-up and withdraw) must be confirmed before execution
- BR-013-002: Withdrawal amount cannot exceed availableCash
- BR-013-004: Withdrawal decreases availableCash by the specified amount
- BR-013-005: Amount must be > $0; zero or negative amounts are rejected
- BR-013-007: Balance changes must be reflected immediately in all views

## Dependencies

- Blocked by: US-013.1 (account page must exist first)
- Blocks: none
