# US-001.1: Initialize State for New Trader

**Epic:** EPIC-001 — Session Initialization
**Jira:** [PTS-33](https://igorrogachov9999.atlassian.net/browse/PTS-33)
**Priority:** High
**Labels:** `backend`

## User Story

As the system, I want to initialize a new trader's state on first login so that they start with the correct starting conditions.

## Acceptance Criteria

- [ ] New trader account starts with exactly $150 availableCash
- [ ] New trader starts with $0 lockedCash
- [ ] New trader starts with an empty inventory
- [ ] New trader starts with an empty notifications list
- [ ] Supply pool (60 pets, 3 per breed) is shared across all traders and initialized once at system startup

## Business Rules

- BR-INIT-001: New trader starts with $150 availableCash
- BR-INIT-002: Supply pool initialized once at system startup (3 per breed, 60 total)
- BR-INIT-006: New trader starts with empty inventory and notifications

## Dependencies

- Blocked by: US-000.1
- Blocks: US-001.2, US-001.3, US-001.4
