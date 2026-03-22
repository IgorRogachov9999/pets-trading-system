# US-002.1: Browse Available Supply

**Epic:** EPIC-002 — New Pet Supply Purchase
**Jira:** [PTS-37](https://igorrogachov9999.atlassian.net/browse/PTS-37)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want to see all 20 breeds with their prices and remaining counts so that I can decide what to buy.

## Acceptance Criteria

- [ ] All 20 breeds listed (5 dogs, 5 cats, 5 birds, 5 fish)
- [ ] Each entry shows: breed name, type, retail price, quantity remaining
- [ ] Breeds with 0 remaining are shown as "Out of Stock" (not hidden)
- [ ] Prices exactly match the pet dictionary (e.g., Labrador=$100, Goldfish=$5)
- [ ] Supply counts update in real-time as purchases are made

## Business Rules

_No specific business rules referenced._

## Dependencies

- Blocked by: US-001.1 (session initialized)
- Blocks: US-002.2
