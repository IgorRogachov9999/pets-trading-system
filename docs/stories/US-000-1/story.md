# US-000.1: Register a New Account

**Epic:** EPIC-000 — User Authentication
**Jira:** [PTS-29](https://igorrogachov9999.atlassian.net/browse/PTS-29)
**Priority:** High
**Labels:** `backend`, `frontend`, `authentication`

## User Story

As a new user, I want to create an account with my email and password so that I can participate in the trading session.

## Acceptance Criteria

- [ ] Registration form requires: email address, password
- [ ] Email must be a valid format (contains @, has domain); duplicate emails are rejected
- [ ] Password must be at least 8 characters
- [ ] On successful registration: account created, $150 starting cash assigned, empty inventory
- [ ] User is immediately logged in after successful registration (no separate login step required)
- [ ] Redirected to trader panel on success
- [ ] Error messages shown for: duplicate email, invalid email format, password too short

## Business Rules

- BR-000-001: Valid email format required
- BR-000-002: Duplicate emails are rejected
- BR-000-003: Password minimum 8 characters

## Dependencies

- Blocked by: none
- Blocks: US-000.2, US-000.3, US-000.4, US-001.1, US-001.3
