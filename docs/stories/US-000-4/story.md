# US-000.4: Protect All Trader Routes

**Epic:** EPIC-000 — User Authentication
**Jira:** [PTS-32](https://igorrogachov9999.atlassian.net/browse/PTS-32)
**Priority:** High
**Labels:** `backend`, `frontend`, `authentication`

## User Story

As the system, I want to ensure only authenticated users can access trading functionality so that data is not exposed publicly.

## Acceptance Criteria

- [ ] All trading routes (panel, market, leaderboard, analysis) require an authenticated session
- [ ] Unauthenticated requests to protected routes return a redirect to /login
- [ ] Session expiry (e.g., 24 hours inactivity) redirects the user to login with a message

## Business Rules

- none

## Dependencies

- Blocked by: US-000.1, US-000.2
- Blocks: none
