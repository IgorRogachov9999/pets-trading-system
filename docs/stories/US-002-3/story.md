# US-002.3: Handle Purchase Rejection

**Epic:** EPIC-002 — New Pet Supply Purchase
**Jira:** [PTS-39](https://igorrogachov9999.atlassian.net/browse/PTS-39)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want to receive a clear error if I can't buy a pet so that I understand what's blocking me.

## Acceptance Criteria

- [ ] If availableCash < retail price: purchase rejected, error message shown, no state change
- [ ] If supply count = 0: purchase rejected, "Out of Stock" message shown
- [ ] Error messages are shown inline (not modal/blocking)
- [ ] Cash and supply remain unchanged after a rejected purchase

## Business Rules

_No specific business rules referenced._

## Dependencies

- Blocked by: US-001.1 (session initialized)
- Blocks: _none_
