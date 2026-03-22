# US-001.2: Restore State on Returning Login

**Epic:** EPIC-001 — Session Initialization
**Jira:** [PTS-34](https://igorrogachov9999.atlassian.net/browse/PTS-34)
**Priority:** High
**Labels:** `backend`

## User Story

As a Trader, I want my previous state restored — including all pet value changes that happened while I was offline — when I log in so that I always see accurate, current data.

## Acceptance Criteria

- [ ] On login, available cash matches the value at last logout/state save
- [ ] On login, inventory is exactly as it was at last logout
- [ ] On login, active listings are restored (still visible in Market View)
- [ ] On login, active bids are restored (locked cash is still locked)
- [ ] On login, notification history is restored (chronological order preserved)
- [ ] All pet fundamentals (age, health, desirability, intrinsic value) reflect every tick that fired while the trader was offline
- [ ] Expired pets that crossed their lifespan threshold while the trader was offline are shown as expired on next login

## Business Rules

- BR-INIT-004: State is persisted in durable storage and restored on login
- BR-INIT-007: Pet fundamentals reflect all ticks that fired while offline

## Dependencies

- Blocked by: US-000.2, US-001.1
- Blocks: none
