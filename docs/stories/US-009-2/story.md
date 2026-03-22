# US-009.2: Understand Intrinsic Value Calculation

**Epic:** EPIC-009 — Pet Analysis / Drill-Down View
**Jira:** [PTS-63](https://igorrogachov9999.atlassian.net/browse/PTS-63)
**Priority:** High
**Labels:** `frontend`

## User Story

As a Trader, I want to see how the intrinsic value is calculated so that I can understand the pet's true worth.

## Acceptance Criteria

- [ ] Intrinsic value formula is shown or accessible in the view
- [ ] Component values (BasePrice, Health, Desirability, Age, Lifespan) are all visible
- [ ] Calculated result matches the formula to within $0.01 rounding

## Business Rules

- Formula: IntrinsicValue = BasePrice × (Health/100) × (Desirability/10) × max(0, 1 - Age/Lifespan)

## Dependencies

- Blocked by: US-009.1 (pet fundamentals drill-down view)
- Blocks: none
