# US-007.3: Notifications Are Private

**Epic:** EPIC-007 — Real-Time Notifications
**Jira:** [PTS-59](https://igorrogachov9999.atlassian.net/browse/PTS-59)
**Priority:** High
**Labels:** `backend`, `frontend`

## User Story

As a Trader, I want to ensure other traders cannot see my notifications so that my bid activity is private.

## Acceptance Criteria

- [ ] Switching trader panels does not show the previous trader's notifications
- [ ] Trader A's notification panel contains only events relevant to Trader A
- [ ] No shared/global notification view

## Business Rules

- BR-007-001: Notifications are private and scoped to the recipient trader only

## Dependencies

- Blocked by: US-003.3 (listing withdrawn event), US-004.1 (bid placed event), US-005.1 (bid accepted/trade completed events)
- Blocks: none
