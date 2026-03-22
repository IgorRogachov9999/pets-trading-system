# US-007.2: View Notification Feed

**Epic:** EPIC-007 — Real-Time Notifications
**Jira:** [PTS-58](https://igorrogachov9999.atlassian.net/browse/PTS-58)
**Priority:** High
**Labels:** `frontend`

## User Story

As a Trader, I want to see my notifications in chronological order so that I can track what happened.

## Acceptance Criteria

- [ ] Notifications displayed in chronological order (most recent at top or bottom, consistently)
- [ ] Each notification shows: timestamp (or sequence), event description, amount, counterparty
- [ ] Unread notifications are visually distinguished (badge, bold, highlight)
- [ ] Notification feed accessible without leaving the trader panel

## Business Rules

- None (UI presentation layer; business rules covered in US-007.1)

## Dependencies

- Blocked by: US-003.3 (listing withdrawn event), US-004.1 (bid placed event), US-005.1 (bid accepted/trade completed events)
- Blocks: none
