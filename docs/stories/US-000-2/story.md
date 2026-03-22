# US-000.2: Log In to Existing Account

**Epic:** EPIC-000 — User Authentication
**Jira:** [PTS-30](https://igorrogachov9999.atlassian.net/browse/PTS-30)
**Priority:** High
**Labels:** `backend`, `frontend`, `authentication`

## User Story

As a registered user, I want to log in with my email and password so that I can access my trader panel and resume trading.

## Acceptance Criteria

- [ ] Login form requires: email and password
- [ ] On correct credentials: session created, redirected to trader panel
- [ ] Trader panel loads saved state from last session (cash, inventory, notifications, active listings, active bids)
- [ ] On incorrect credentials: generic error shown ("Invalid email or password"); no hint as to which field is wrong
- [ ] On successful login, session token persists until explicit logout
- [ ] Unauthenticated requests to protected pages are redirected to login

## Business Rules

- BR-000-004: Session token persists until explicit logout
- BR-000-005: Generic error message on failed login

## Dependencies

- Blocked by: US-000.1
- Blocks: US-000.3, US-001.2, US-001.3
