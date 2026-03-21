# EPIC-001: Session Initialization

> **Epic ID:** EPIC-001
> **Priority:** Must Have
> **Status:** Ready for Development

---

## Summary

After a trader authenticates (EPIC-000), the system loads their persistent trader state from storage and renders their private trader panel. The system supports any number of registered traders, each with an independent account. On first login, a trader starts with $150 available cash and an empty inventory; on subsequent logins, the last saved state is restored and any tick-driven changes (age, health, desirability, intrinsic value) that occurred while the trader was offline are reflected immediately. The tick loop runs continuously on the server, independent of any individual trader's session.

---

## End-to-End Workflow

**First Login (new account):**
```
Account Created → Trader Panel Initialized → $150 Cash, Empty Inventory Written to DB → Tick Loop Running → Ready to Trade
```

**Returning Login:**
```
Trader Logs In → Backend Loads Trader State from DB → Trader Panel Rendered with Saved State (including all offline tick updates) → Tick Loop Running → Ready to Trade
```

**Session End:**
```
Trader Logs Out / Tab Closed → Session Invalidated → State Already Persisted in DB → Other Traders Unaffected
```

---

## User Stories

### US-001.1 — Initialize State for New Trader
> As the system, I want to initialize a new trader's state on first login so that they start with the correct starting conditions.

**Acceptance Criteria:**
- [ ] New trader account starts with exactly $150 `availableCash`
- [ ] New trader starts with $0 `lockedCash`
- [ ] New trader starts with an empty inventory
- [ ] New trader starts with an empty notifications list
- [ ] Supply pool (60 pets, 3 per breed) is shared across all traders and initialized once at system startup

---

### US-001.2 — Restore State on Returning Login (Including Offline Tick Catch-Up)
> As a Trader, I want my previous state restored — including all pet value changes that happened while I was offline — when I log in so that I always see accurate, current data.

**Acceptance Criteria:**
- [ ] On login, available cash matches the value at last logout/state save
- [ ] On login, inventory is exactly as it was at last logout
- [ ] On login, active listings are restored (still visible in Market View)
- [ ] On login, active bids are restored (locked cash is still locked)
- [ ] On login, notification history is restored (chronological order preserved)
- [ ] All pet fundamentals (age, health, desirability, intrinsic value) reflect every tick that fired while the trader was offline — the trader never sees stale pre-logout values
- [ ] Expired pets (age ≥ lifespan) that crossed their lifespan threshold while the trader was offline are shown as expired on next login

---

### US-001.3 — Render Trader Panel on Login
> As a Trader, I want to see my trader panel immediately after login so that I can start trading without extra navigation.

**Acceptance Criteria:**
- [ ] Trader panel loads within 3 seconds of successful login on a standard connection
- [ ] Panel shows: `availableCash`, `lockedCash`, `portfolioValue`, inventory, notifications
- [ ] Panel shows only the authenticated trader's private data
- [ ] Market View (shared) is accessible from the trader panel without additional login

---

### US-001.4 — Persistent Supply State
> As the system, I want the supply pool to persist across server restarts so that traders do not lose supply progress.

**Acceptance Criteria:**
- [ ] Supply counts are stored in durable storage, not in-memory
- [ ] After server restart, supply counts reflect all purchases made before the restart
- [ ] Supply starts at 3 per breed only on the very first system initialization (seed)
- [ ] Supply count of 0 for any breed persists — it does not reset on server restart

---

## Business Rules

| ID | Rule |
|----|------|
| BR-INIT-001 | Starting cash is $150 per new trader; this is fixed, not configurable at runtime |
| BR-INIT-002 | Initial supply is exactly 3 units per breed (60 total pets); seeded once at system first-run |
| BR-INIT-003 | Trader identity is determined by authenticated session; no anonymous access to trading |
| BR-INIT-004 | All state (cash, inventory, listings, bids, notifications) is persisted to durable storage |
| BR-INIT-005 | The tick loop runs on the server independently of any trader's login state |
| BR-INIT-006 | Any number of traders may be registered; there is no fixed maximum |
| BR-INIT-007 | Pet fundamentals are updated by the tick loop even while their owner is offline; the trader sees current values on next login |

---

## Out of Scope

- Configurable starting cash (fixed at $150)
- Admin-managed initialization (system seeds itself on first run)
- Push notifications to offline traders (mobile push, email) — state is caught up passively on login

---

## Dependencies

- EPIC-000 (authentication must complete before state is loaded)
- EPIC-011 (tick loop updates offline traders' pets)
- All other epics depend on this initialization
