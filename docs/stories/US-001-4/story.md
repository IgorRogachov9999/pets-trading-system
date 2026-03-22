# US-001.4: Persistent Supply State

**Epic:** EPIC-001 — Session Initialization
**Jira:** [PTS-36](https://igorrogachov9999.atlassian.net/browse/PTS-36)
**Priority:** High
**Labels:** `backend`, `devops`

## User Story

As the system, I want the supply pool to persist across server restarts so that traders do not lose supply progress.

## Acceptance Criteria

- [ ] Supply counts are stored in durable storage, not in-memory
- [ ] After server restart, supply counts reflect all purchases made before the restart
- [ ] Supply starts at 3 per breed only on the very first system initialization (seed)
- [ ] Supply count of 0 for any breed persists — it does not reset on server restart

## Business Rules

- BR-INIT-002: Supply pool is stored in durable storage and seeded only once

## Dependencies

- Blocked by: US-001.1
- Blocks: none
