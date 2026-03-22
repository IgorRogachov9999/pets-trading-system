# US-009.3: Identify Expired Pets

**Epic:** EPIC-009 — Pet Analysis / Drill-Down View
**Jira:** [PTS-64](https://igorrogachov9999.atlassian.net/browse/PTS-64)
**Priority:** High
**Labels:** `frontend`

## User Story

As a Trader, I want to see clearly when a pet is expired so that I know its intrinsic value is zero.

## Acceptance Criteria

- [ ] Expired status is prominently displayed when age ≥ lifespan
- [ ] Intrinsic value shows $0.00 for expired pets
- [ ] Expired pets can still be listed/traded — the view makes no restriction
- [ ] Age and lifespan values are both shown so the trader can verify

## Business Rules

- BR-009-004: Expired pets (Age ≥ Lifespan) have intrinsic value of $0.00 but remain tradeable

## Dependencies

- Blocked by: US-009.1 (pet fundamentals drill-down view)
- Blocks: none
