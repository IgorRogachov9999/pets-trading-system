# Business Requirements Document — Pets Trading System

> **Document ID:** BRD-PTS-001
> **Version:** 3.0
> **Date:** 2026-03-20
> **Status:** Baselined
> **Prepared by:** BA Requirements Skill (Claude Code)
> **Changes from v2.0:** Removed Session Reset (EPIC-012) — not needed as users can create fresh accounts for demos. Starting cash changed from $700 to $150. Offline tick catch-up moved from Out of Scope to In Scope. Clarified top-up increases and withdrawal decreases `availableCash`.

---

## 1. Executive Summary

The Pets Trading System is a real-time virtual marketplace where authenticated traders buy, sell, and bid on virtual pets. Any number of traders can register and participate simultaneously. The primary purpose is to demonstrate end-to-end AI-assisted system development across design, coding, testing, and deployment. Success is measured by a working, coherent system that judges can interact with during a live demo, scored against a published judging matrix worth 100 points.

---

## 2. Business Context

### 2.1 Problem Statement

Hackathon participants must demonstrate AI-assisted system delivery by building a functional trading application within a single session. The system must showcase not just the final product, but the AI-guided process: design decisions, tradeoff reasoning, and test coverage. A toy trading domain (virtual pets) provides enough complexity to exercise full-stack skills without domain expertise barriers.

### 2.2 Goals and Measurable Outcomes

| Goal | Metric | Target |
|------|--------|--------|
| Authentication works | Register and login flow completes without error | 100% |
| Core trading mechanics work | All 5 trade flows execute without error in the live demo | 100% |
| Valuation is correct | Intrinsic value matches formula for 5 randomly selected pets during judging | 100% accuracy |
| UI is complete | All 5 required views accessible (Auth, Trader Panel, Market, Analysis, Leaderboard) | 5/5 |
| Real-time updates | UI refreshes after every trade or tick without manual reload | Observed by judges |
| Persistent state | Trader state survives server restart; offline tick updates visible on next login | Verified by judges |
| AI usage evidenced | Prompts, iterations, design artifacts visible and explainable | Subjective |
| Deployment demonstrated | System is accessible via a public URL or runs locally without setup | Live demo |

### 2.3 Scope

**In Scope:**
- User registration and login (email/password)
- Logout and session management
- Persistent state across server restarts (durable storage)
- Any number of registered traders (no fixed maximum)
- Offline tick catch-up: pet fundamentals updated by tick loop even while trader is offline; trader sees current values on next login
- Account page: view inventory, top up balance (increases `availableCash`), withdraw balance (decreases `availableCash`)
- Virtual pet marketplace (buy from supply, list, bid, accept/reject)
- 20-breed read-only pet dictionary with lifecycle simulation
- 5 UI views: Auth, Trader Panel, Market View, Analysis/Drill-Down, Leaderboard
- Real-time updates via push (WebSocket or SSE)
- Backend lifecycle tick loop (age/health/desirability/intrinsic value)
- Infrastructure definition and CI/CD pipeline (for judging criteria)
- Markdown test case documentation

**Out of Scope:**
- Social login (OAuth, Google, GitHub)
- Multi-factor authentication
- Password reset / forgot password
- Email verification
- AI-controlled traders or bots
- Financial compliance, reporting, or tax calculations
- Distributed locking (sequential actions sufficient)
- Automated test execution (test cases in markdown required; execution optional)
- Real-money payment processing for top-up/withdraw
- Session reset / bulk state wipe (traders create fresh accounts for new demo runs)
- Push notifications to offline traders (email, mobile push)

---

## 3. Stakeholders & Users

| Role | Description | Key Needs | Concerns |
|------|-------------|-----------|----------|
| **Trader** | Any registered user participating in the market | Clear panel; fast UI; accurate state restored on login including offline changes | Stale data after offline period; state loss on restart |
| **Hackathon Judge** | Evaluates scoring matrix criteria | All required components; explainable decisions; working demo | Missing views; incorrect valuation; auth broken; no persistence |
| **Demo Facilitator** | Person running the demo | Fresh demo by registering new accounts | N/A — no special reset tool needed |
| **Peer Teams (voters)** | Other hackathon teams | Polish, clarity, overall impression | Subjective; secondary to judge criteria |

---

## 4. Functional Requirements

### FR-001 — User Registration
**Description:** New users create an account with email and password.
**Acceptance Criteria:**
- Email is unique; duplicate registrations are rejected
- Password minimum 8 characters
- On success: account created with $150 starting cash and empty inventory
- User is logged in immediately after registration
**Business Rules:** BR-001, BR-002, BR-003

---

### FR-002 — User Login
**Description:** Registered users authenticate with email and password.
**Acceptance Criteria:**
- Correct credentials create a session and redirect to trader panel
- Incorrect credentials return a generic error (no field-level hints)
- Session persists until explicit logout or expiry (24h inactivity)
- Trader panel loads saved state from last session, including all tick updates that occurred while offline
**Business Rules:** BR-001, BR-004

---

### FR-003 — User Logout
**Description:** Authenticated users can end their session.
**Acceptance Criteria:**
- Session invalidated server-side on logout
- Redirected to login page
- State is persisted automatically (no data loss on logout)
- Back button after logout does not expose the trader panel
**Business Rules:** BR-004

---

### FR-004 — Account Page
**Description:** Authenticated traders can view their account summary and inventory on a dedicated account page.
**Acceptance Criteria:**
- Shows: registered email, `availableCash`, `lockedCash`, `portfolioValue`
- Shows full inventory with breed, type, health, age, desirability, intrinsicValue, listed/expired flags
- Data consistent with trader panel (same formula, same data)
**Business Rules:** BR-006, BR-007

---

### FR-005 — Top Up Balance
**Description:** Traders can add virtual cash to their available balance from the account page. This **increases** `availableCash`.
**Acceptance Criteria:**
- Top-up amount must be > $0
- `availableCash` **increases** by the top-up amount immediately upon confirmation
- Confirmation prompt shows current and new balance: "Your available cash will increase from $X to $Y"
- Change persisted to durable storage immediately
**Business Rules:** BR-007, BR-008

---

### FR-006 — Withdraw Balance
**Description:** Traders can remove virtual cash from their available balance from the account page. This **decreases** `availableCash`.
**Acceptance Criteria:**
- Withdrawal amount must be > $0 and ≤ `availableCash` (locked cash is not withdrawable)
- `availableCash` **decreases** by the withdrawal amount immediately upon confirmation
- Confirmation prompt shows current and new balance: "Your available cash will decrease from $X to $Y"
- Attempting to withdraw more than `availableCash` is rejected with an error; balance unchanged
- Change persisted to durable storage immediately
**Business Rules:** BR-007, BR-008, BR-009

---

### FR-007 — Trader Panel (Private View)
**Description:** Each authenticated trader has a private panel showing their own data only.
**Acceptance Criteria:**
- Displays: `availableCash`, `lockedCash`, `portfolioValue`, `inventory[]`, `notifications[]`
- No data from other traders is visible in this panel
- Portfolio value = `availableCash + lockedCash + sum(intrinsicValue of owned pets)`
- Updates immediately after any trade or valuation tick
- Link to account page accessible from panel
**Business Rules:** BR-006, BR-015

---

### FR-008 — New Supply Purchase
**Acceptance Criteria:**
- Retail price deducted from `availableCash` at time of purchase
- New pet added to inventory with `age=0`, `health=100`, `desirability=breed default`
- Supply count decremented per breed per purchase; persisted
- Rejected if `availableCash < retail price` or `supply count = 0`
**Business Rules:** BR-010, BR-011

---

### FR-009 — Secondary Market Listing
**Acceptance Criteria:**
- Listed pet appears in shared Market View immediately
- `askingPrice` must be > 0
- Only one active listing per pet instance at any time
**Business Rules:** BR-012, BR-013

---

### FR-010 — Listing Withdrawal
**Acceptance Criteria:**
- Listing removed from Market View immediately
- Any active bid rejected; bidder's `lockedCash` released
- Bidder receives withdrawal notification
**Business Rules:** BR-013, BR-016

---

### FR-011 — Bid Placement
**Acceptance Criteria:**
- Bid amount ≤ bidder's `availableCash`; bid amount > 0
- Bidder cannot bid on their own listing
- Bid amount moved from `availableCash` to `lockedCash` immediately
- Only one active bid per listing; highest wins; new higher bid atomically replaces previous
**Business Rules:** BR-014, BR-015, BR-016

---

### FR-012 — Bid Withdrawal (by Bidder)
**Acceptance Criteria:**
- `lockedCash` released back to `availableCash` immediately
- Seller receives withdrawal notification
**Business Rules:** BR-016

---

### FR-013 — Accept Bid
**Acceptance Criteria:**
- Pet ownership transferred to buyer immediately
- Bid amount transferred from buyer's `lockedCash` to seller's `availableCash`
- Most recent trade price recorded for the breed
- Both parties receive trade completion notifications
**Business Rules:** BR-015, BR-017

---

### FR-014 — Reject Bid
**Acceptance Criteria:**
- Bidder's `lockedCash` released to `availableCash`
- Listing remains in Market View with no active bid
- Bidder receives rejection notification
**Business Rules:** BR-016

---

### FR-015 — Market View (Shared)
**Acceptance Criteria:**
- Shows: all active listings, `askingPrice`, most recent trade price per breed, new supply count
- Default sort: newest listing first; updates in real time
**Business Rules:** BR-012, BR-018

---

### FR-016 — Analysis / Drill-Down View
**Acceptance Criteria:**
- Shows: `age` (years, 2 dp), `health` (%), `desirability`, `maintenanceCost`, `intrinsicValue` ($), `expired` (boolean)
- Accessible for all pets; `intrinsicValue` reflects the formula exactly

---

### FR-017 — Leaderboard
**Acceptance Criteria:**
- Shows all registered traders with their `portfolioValue`, sorted descending
- Updates within 2 seconds of any trade or valuation tick
- Trader identified by email or display name

---

### FR-018 — Notifications
**Acceptance Criteria:**
- Five notification types: bid received, bid accepted, bid rejected, bid withdrawn, outbid
- Each includes: event type, pet breed, dollar amount, counterparty trader
- Chronological order; persisted in durable storage; private to recipient
**Business Rules:** BR-019

---

### FR-019 — Pet Lifecycle Tick
**Acceptance Criteria:**
- Tick interval default: 60 seconds (configurable via environment variable)
- Health clamped to [0%, 100%]; desirability clamped to [0, breed max]
- All connected clients refreshed within 2 seconds of tick completion
- Tick updates pets of **offline** traders; updated values visible on next login
**Business Rules:** BR-020

---

### FR-020 — Intrinsic Value Formula

```
IntrinsicValue = BasePrice × (Health / 100) × (Desirability / 10) × (1 - Age / Lifespan)
```

Expired pets (`age ≥ lifespan`) produce `intrinsicValue = 0`

---

### FR-021 — Pet Dictionary (Read-Only)

| Type | Breed | Lifespan | Desirability | Maintenance | BasePrice |
|------|-------|----------|-------------|-------------|-----------|
| Dog | Labrador | 12 | 8 | 5 | $100 |
| Dog | Beagle | 13 | 7 | 4 | $90 |
| Dog | Poodle | 14 | 9 | 6 | $110 |
| Dog | Bulldog | 10 | 6 | 7 | $80 |
| Dog | Pit Bull | 11 | 5 | 5 | $70 |
| Cat | Siamese | 15 | 9 | 4 | $90 |
| Cat | Persian | 14 | 8 | 6 | $85 |
| Cat | Maine Coon | 16 | 7 | 5 | $80 |
| Cat | Bengal | 12 | 6 | 5 | $75 |
| Cat | Sphynx | 13 | 5 | 7 | $70 |
| Bird | Parakeet | 8 | 7 | 3 | $25 |
| Bird | Canary | 10 | 6 | 2 | $20 |
| Bird | Cockatiel | 12 | 8 | 3 | $30 |
| Bird | Macaw | 50 | 9 | 8 | $120 |
| Bird | Lovebird | 15 | 5 | 3 | $15 |
| Fish | Goldfish | 10 | 5 | 2 | $5 |
| Fish | Betta | 5 | 6 | 1 | $6 |
| Fish | Guppy | 3 | 4 | 1 | $4 |
| Fish | Angelfish | 8 | 7 | 2 | $8 |
| Fish | Clownfish | 6 | 8 | 3 | $10 |

---

## 5. Non-Functional Requirements

| ID | Category | Requirement | Rationale |
|----|----------|-------------|-----------|
| NFR-001 | Real-time latency | UI reflects state changes within ≤ 2 seconds of a trade or tick event | Judges observe responsiveness |
| NFR-002 | Concurrent users | System supports multiple authenticated traders simultaneously; designed for ≥ 10 concurrent | Traders are independent users |
| NFR-003 | Tick configurability | Lifecycle tick interval is configurable via environment variable (default: 60s) | Judges may request faster ticks |
| NFR-004 | State durability | All trading state persists across server restarts; offline tick updates applied on next login | State loss is a defect |
| NFR-005 | Deployment | System must be accessible during the demo (local or public URL) | Required for live demo scoring |
| NFR-006 | API response time | Backend API endpoints respond in < 500ms p95 under demo load | No degradation visible during demo |
| NFR-007 | Data consistency | `portfolioValue` on trader panel and leaderboard always identical for the same trader | Judges will cross-check |
| NFR-008 | Formula precision | Intrinsic value consistent across backend and frontend (no rounding divergence > $0.01) | Judges verify formula |
| NFR-009 | Auth security | Passwords stored as cryptographic hashes; session tokens invalidated on logout | Security baseline |
| NFR-010 | Session expiry | Inactive sessions expire after 24 hours; user redirected to login | Prevents stale sessions |

---

## 6. Assumptions & Constraints

### Assumptions

| ID | Assumption |
|----|-----------|
| A-001 | Each registered user controls exactly one trader account; no shared accounts |
| A-002 | Starting cash for each new trader is $150; this is a fixed constant |
| A-003 | Sequential actions sufficient — no distributed locks needed for trading operations |
| A-004 | Age tracked in fractional years; 1 minute ≈ 60/(365×24×3600) ≈ 0.0000019 years |
| A-005 | Desirability bounded between 0 and the breed's baseline value for variance calculations |
| A-006 | "Most recent trade price" in Market View is per-breed, not per-pet-instance |
| A-007 | Pet where `1 - Age/Lifespan ≤ 0` is "expired" and has intrinsicValue = 0 |
| A-008 | Target deployment cloud platform not specified; any of AWS/Azure/GCP is valid |
| A-009 | Top-up and withdrawal are virtual operations (no real-money payment gateway required) |
| A-010 | Durable storage means a relational or document database; exact technology is an architectural decision |
| A-011 | Tick loop updates all pets continuously, including those owned by offline traders; state is caught up passively on next login |

### Constraints

| ID | Constraint |
|----|-----------|
| C-001 | Pet dictionary is read-only — cannot be modified at runtime |
| C-002 | Initial supply per breed is 3 units; seeded once at first system initialization |
| C-003 | Bid amounts must not exceed `availableCash` (locked cash excluded) |
| C-004 | Only one active bid per listing at any time |
| C-005 | Only one active listing per pet instance at any time |
| C-006 | Traders cannot bid on their own listings |
| C-007 | Withdrawal cannot reduce `availableCash` below $0 |
| C-008 | Authentication is required for all trading actions; no anonymous access |

---

## 7. Open Questions

| ID | Question | Impact | Owner | Target Date |
|----|----------|--------|-------|-------------|
| OQ-001 | Is desirability clamped to [0, breed_default] or [0, 10] during variance updates? | Affects high-desirability pets exceeding breed baseline | Architect | Before implementation |
| OQ-002 | What is the target deployment platform (AWS/Azure/GCP)? | Affects IaC choice | Participant / judge | Before infra design |
| OQ-003 | Should tick interval be configurable at runtime (UI) or only at startup (env var)? | Affects whether a settings panel is needed | Participant | Before frontend design |
| OQ-004 | Is "most recent trade price" per breed across all traders, or per-listing? | Affects data model | Architect | Before data modeling |
| OQ-005 | Should notifications persist indefinitely in DB, or expire after N days? | Affects storage growth | Architect | Before DB design |
| OQ-006 | Is there a minimum balance floor on withdrawal (e.g., cannot go below $0)? | Affects account management rules — currently assumed $0 floor | Product Owner | Before implementation |
| OQ-007 | Should the leaderboard show offline traders or only currently active/logged-in traders? | Affects real-time leaderboard design | Participant | Before frontend design |
| OQ-008 | Does a trader need a display name separate from their email? | Affects registration form and leaderboard | Participant | Before registration design |

---

## 8. Glossary

| Term | Definition |
|------|-----------|
| **Trader** | Any registered user with an authenticated account; can buy, sell, and bid on pets |
| **Account** | A registered user's profile, identified by email and password |
| **availableCash** | Cash a trader can spend immediately (excludes locked cash) |
| **lockedCash** | Cash held against active bids; released when a bid is accepted, rejected, or withdrawn |
| **portfolioValue** | `availableCash + lockedCash + sum(intrinsicValue of all owned pets)` |
| **Top-Up** | A virtual cash addition that **increases** a trader's `availableCash`; initiated from the account page |
| **Withdrawal** | A virtual cash removal that **decreases** a trader's `availableCash`; initiated from the account page |
| **Listing** | An offer to sell a specific pet at a stated asking price |
| **Bid** | An offer to buy a listed pet at a stated price; only one active bid per listing (highest wins) |
| **intrinsicValue** | `BasePrice × (Health/100) × (Desirability/10) × (1 - Age/Lifespan)` |
| **Lifecycle Tick** | Periodic backend event (default: 60s) aging all pets and applying ±5% variance; runs even while traders are offline |
| **Offline Tick Catch-Up** | The behaviour where a returning trader sees their pets' current values (updated by all ticks since logout) on their next login |
| **Expired** | Pet whose `age ≥ lifespan`; intrinsicValue = 0 but remains tradeable |
| **New Supply** | Fixed pool of fresh pets (3 per breed); separate from secondary market |
| **Secondary Market** | Peer-to-peer trading between traders via listings and bids |
| **Outbid** | Bid replaced by a higher bid; locked cash released automatically |

---

## Business Rules Reference

| ID | Rule |
|----|------|
| BR-001 | Each account is identified by a unique email address |
| BR-002 | Passwords are stored as cryptographic hashes (never plaintext) |
| BR-003 | A new account starts with exactly $150 available cash and an empty inventory |
| BR-004 | Session tokens must be invalidated on logout |
| BR-005 | Login failure returns a generic message; it does not reveal whether the email exists |
| BR-006 | Each trader sees only their own cash, inventory, and notifications |
| BR-007 | Account page data must be consistent with trader panel data |
| BR-008 | Top-up and withdrawal changes are persisted immediately to durable storage |
| BR-009 | Withdrawal cannot exceed the trader's current `availableCash`; locked cash is not withdrawable |
| BR-010 | New supply purchases are at fixed retail price; no bidding involved |
| BR-011 | Supply count per breed starts at 3 (seeded once) and decrements with each purchase; persisted |
| BR-012 | `askingPrice` must be > 0 |
| BR-013 | Only one active listing per pet instance at any time |
| BR-014 | Bid amount must be ≤ trader's `availableCash` |
| BR-015 | Traders cannot bid on their own listings |
| BR-016 | Withdrawing a listing or a bid releases all locked cash associated immediately |
| BR-017 | A trade executes immediately when a bid is accepted; no pending/settlement state |
| BR-018 | Market View is shared (read by all traders) |
| BR-019 | Notifications are private to the recipient trader and persisted in durable storage |
| BR-020 | Expired pets (`age ≥ lifespan`) have `intrinsicValue = 0` but remain listeable/tradeable |
