# US-000.3: Log Out

**Epic:** EPIC-000 — User Authentication
**Jira:** [PTS-31](https://igorrogachov9999.atlassian.net/browse/PTS-31)
**Priority:** High
**Labels:** `backend`, `frontend`, `authentication`

## User Story

As a Trader, I want to log out so that my session is ended and my state is saved for next time.

## Acceptance Criteria

- [ ] Logout action is accessible from the trader panel (e.g., header, menu)
- [ ] On logout: session invalidated server-side, redirected to login page
- [ ] State (cash, inventory, bids, listings) is persisted automatically — no data loss on logout
- [ ] After logout, the browser back button does not expose the previous trader panel
- [ ] Another user can log in on the same browser after logout

## Business Rules

- BR-000-004: Session invalidated server-side on logout

## Dependencies

- Blocked by: US-000.2
- Blocks: none
