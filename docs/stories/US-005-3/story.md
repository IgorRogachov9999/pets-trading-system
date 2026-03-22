# US-005.3: No Accept/Reject When No Active Bid

**Epic:** EPIC-005 — Trade Execution (Accept / Reject)
**Jira:** [PTS-51](https://igorrogachov9999.atlassian.net/browse/PTS-51)
**Priority:** High
**Labels:** `frontend`

## User Story

As a Trader (seller), I cannot accept or reject if there is no active bid.

## Acceptance Criteria

- [ ] Accept and Reject actions are hidden/disabled when no bid exists on the listing
- [ ] Seller sees a clear state indicator: "No active bid"

## Business Rules

- None (UI guard enforcing existing business rules)

## Dependencies

- Blocked by: US-005.1 (accept action must exist before it can be conditionally hidden)
- Blocks: none
