# US-011.3: Expired Pet Handling

**Epic:** EPIC-011 — Pet Lifecycle Engine
**Jira:** [PTS-69](https://igorrogachov9999.atlassian.net/browse/PTS-69)
**Priority:** High
**Labels:** `backend`

## User Story

As the system, I want expired pets (age ≥ lifespan) to show intrinsicValue = 0 while remaining in inventory and tradeable.

## Acceptance Criteria

- [ ] Pets with age ≥ lifespan display intrinsicValue = $0.00 in all views
- [ ] Expired pets remain in the owner's inventory (not auto-removed)
- [ ] Expired pets can still be listed for sale
- [ ] Expired pets can still receive bids and be traded
- [ ] Expired pets are clearly flagged as "expired" in inventory and analysis views
- [ ] Portfolio value includes expired pets at $0 intrinsic value (not excluded)

## Business Rules

- BR-011-005: Expired pets (age ≥ lifespan) have intrinsicValue = 0 but remain tradeable and in inventory

## Dependencies

- Blocked by: US-011.1 (tick must be implemented first)
- Blocks: none
