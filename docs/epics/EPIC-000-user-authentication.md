# EPIC-000: User Authentication

> **Epic ID:** EPIC-000
> **Priority:** Must Have
> **Status:** Ready for Development

---

## Summary

Traders access the Pets Trading System by registering an account with an email address and password, then logging in. Each authenticated session represents one independent trader. On logout, the session is invalidated and the trader's state is preserved in persistent storage. On the next login, the trader resumes from where they left off.

---

## End-to-End Workflow

**Registration:**
```
User Visits App → Not Authenticated → Registration Form → Submit Email + Password → Account Created → Starting Cash $150 Assigned → Redirected to Trader Panel
```

**Login:**
```
User Visits App → Not Authenticated → Login Form → Submit Credentials → Credentials Validated → Session Created → Trader Panel Loaded with Saved State
```

**Logout:**
```
Trader Clicks Logout → Session Invalidated → Trader State Saved to DB → Redirected to Login Page
```

---

## User Stories

### US-000.1 — Register a New Account
> As a new user, I want to create an account with my email and password so that I can participate in the trading session.

**Acceptance Criteria:**
- [ ] Registration form requires: email address, password
- [ ] Email must be a valid format (contains @, has domain); duplicate emails are rejected
- [ ] Password must be at least 8 characters
- [ ] On successful registration: account created, $150 starting cash assigned, empty inventory
- [ ] User is immediately logged in after successful registration (no separate login step required)
- [ ] Redirected to trader panel on success
- [ ] Error messages shown for: duplicate email, invalid email format, password too short

---

### US-000.2 — Log In to Existing Account
> As a registered user, I want to log in with my email and password so that I can access my trader panel and resume trading.

**Acceptance Criteria:**
- [ ] Login form requires: email and password
- [ ] On correct credentials: session created, redirected to trader panel
- [ ] Trader panel loads saved state from last session (cash, inventory, notifications, active listings, active bids)
- [ ] On incorrect credentials: generic error shown ("Invalid email or password"); no hint as to which field is wrong
- [ ] On successful login, session token persists until explicit logout
- [ ] Unauthenticated requests to protected pages are redirected to login

---

### US-000.3 — Log Out
> As a Trader, I want to log out so that my session is ended and my state is saved for next time.

**Acceptance Criteria:**
- [ ] Logout action is accessible from the trader panel (e.g., header, menu)
- [ ] On logout: session invalidated server-side, redirected to login page
- [ ] State (cash, inventory, bids, listings) is persisted automatically — no data loss on logout
- [ ] After logout, the browser back button does not expose the previous trader panel
- [ ] Another user can log in on the same browser after logout

---

### US-000.4 — Protect All Trader Routes
> As the system, I want to ensure only authenticated users can access trading functionality so that data is not exposed publicly.

**Acceptance Criteria:**
- [ ] All trading routes (panel, market, leaderboard, analysis) require an authenticated session
- [ ] Unauthenticated requests to protected routes return a redirect to /login
- [ ] Session expiry (e.g., 24 hours inactivity) redirects the user to login with a message

---

## Business Rules

| ID | Rule |
|----|------|
| BR-000-001 | Each account is identified by a unique email address |
| BR-000-002 | Passwords are stored as cryptographic hashes (never plaintext) |
| BR-000-003 | A new account starts with exactly $150 available cash and an empty inventory |
| BR-000-004 | Session tokens must be invalidated on logout |
| BR-000-005 | Login failure returns a generic message; it does not reveal whether the email exists |
| BR-000-006 | There is no limit on the total number of registered traders |
| BR-000-007 | A trader can only be logged in as themselves; no impersonation |

---

## Out of Scope

- Social login (Google, GitHub, OAuth)
- Multi-factor authentication
- Password reset / forgot password flow
- Email verification on registration
- Rate limiting login attempts (security hardening)
- Role-based access control (all traders have the same permissions)
- Admin accounts

---

## Dependencies

- None (this is the prerequisite for all other epics)

---

## Notes

Authentication is the entry point for all traders. Because the number of traders is now unlimited, the leaderboard (EPIC-010) must dynamically display all registered and active traders, not a fixed set.
