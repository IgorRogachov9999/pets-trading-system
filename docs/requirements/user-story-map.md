# User Story Map — Pets Trading System

> **Version:** 3.0
> **Date:** 2026-03-20
> **Status:** Baselined
> **Change from v2.0:** Removed Session Reset (EPIC-012). Starting cash $700 → $150. Offline tick catch-up moved from Out of Scope to In Scope. Clarified top-up increases and withdrawal decreases availableCash.

---

## How to read this map

**Activity → Epic → Story → Tasks → Acceptance Criteria**

MoSCoW priority is on every story. Stories marked **Must Have** are required to pass the core scoring criteria. Should/Could/Won't stories target bonus marks or presentation polish.

---

## Activity 0: Create Account & Authenticate

*Traders must register and log in before accessing any trading functionality. Each account represents one independent trader with their own cash, inventory, and notifications.*

### Epic 0.1 — User Registration

#### Story 0.1.1 — Register a New Account  `Must Have`

> As a new user, I want to create an account with my email and password so that I can participate as a trader.

**Tasks:**
- Render registration form (email, password, confirm password)
- Validate email format and uniqueness
- Validate password meets minimum requirements (8+ characters)
- Create trader account in durable storage with $150 starting cash
- Log user in immediately after registration
- Redirect to trader panel

**Acceptance Criteria:**
- [ ] Registration form is accessible from the landing page
- [ ] Email must be valid format; duplicate emails are rejected with a clear message
- [ ] Password must be at least 8 characters; shorter passwords are rejected
- [ ] Successful registration creates an account with $150 available cash and empty inventory
- [ ] User is logged in immediately after registration (no separate login step)
- [ ] Failed registration shows specific field-level error messages

---

### Epic 0.2 — Login / Logout

#### Story 0.2.1 — Log In  `Must Have`

> As a registered user, I want to log in with my email and password so that I can access my trader panel.

**Tasks:**
- Render login form (email, password)
- Validate credentials against stored hash
- Create authenticated session on success
- Load trader's persistent state from storage
- Redirect to trader panel

**Acceptance Criteria:**
- [ ] Login form is the default landing page for unauthenticated users
- [ ] Correct credentials create a session and redirect to trader panel
- [ ] Incorrect credentials show a generic message ("Invalid email or password") with no field-level hint
- [ ] Trader panel loads with the last saved state (cash, inventory, notifications)
- [ ] Unauthenticated navigation to protected routes redirects to login

---

#### Story 0.2.2 — Log Out  `Must Have`

> As a Trader, I want to log out so that my session ends and my state is saved for next time.

**Tasks:**
- Add logout action in header/navigation
- Invalidate session server-side
- Redirect to login page

**Acceptance Criteria:**
- [ ] Logout is accessible from any page via the header
- [ ] Session is invalidated on the server immediately
- [ ] User is redirected to the login page
- [ ] Back button after logout does not re-expose the trader panel
- [ ] All trading state is already persisted — no data loss on logout

---

## Activity 1: Set Up Trading Session

*After login, the trader's panel is loaded with their persistent state. On first login, the session starts fresh with $150 cash and an empty inventory.*

### Epic 1.1 — Session Initialization

#### Story 1.1.1 — Load Trader State on Login (Including Offline Tick Catch-Up)  `Must Have`

> As a Trader, I want my panel to load with my saved state — including all pet value changes that occurred while I was offline — so that I always see accurate, current data.

**Tasks:**
- Load cash, inventory, active bids, active listings, notifications from DB
- Render trader panel with loaded state (tick loop has kept pet values current in DB)
- Subscribe to real-time updates (WebSocket/SSE)

**Acceptance Criteria:**
- [ ] Trader panel loads within 3 seconds of successful login
- [ ] Available cash, locked cash, and portfolio value are shown immediately
- [ ] Inventory reflects all owned pets from last session
- [ ] Active bids and listings are restored
- [ ] Notification history is restored in chronological order
- [ ] Panel shows only the authenticated trader's private data
- [ ] All pet fundamentals (age, health, desirability, intrinsic value) reflect every tick that fired while offline — no stale pre-logout values shown
- [ ] Pets that expired (age ≥ lifespan) while offline are shown as expired on login

---

#### Story 1.1.2 — First-Time Trader Starting State  `Must Have`

> As a new Trader logging in for the first time, I want to start with $150 cash and a clean slate so that all traders begin fairly.

**Acceptance Criteria:**
- [ ] New trader starts with exactly $150 available cash
- [ ] New trader starts with $0 locked cash
- [ ] New trader starts with an empty inventory
- [ ] New trader starts with an empty notifications list
- [ ] Portfolio value shown as $150.00 on first login

---

## Activity 2: Build Inventory from New Supply

*Traders buy fresh pets at fixed retail price from the shared supply pool. Supply is persistent and shared across all traders.*

### Epic 2.1 — New Supply Purchase

#### Story 2.1.1 — Browse Available Supply  `Must Have`

> As a Trader, I want to see which pets are available from new supply with their breed details and retail price so that I can decide what to buy.

**Tasks:**
- Display supply inventory: breed, type, retail price, quantity remaining
- Pull from the read-only 20-breed dictionary
- Supply counts reflect all purchases ever made (persistent)

**Acceptance Criteria:**
- [ ] All 20 breeds listed with type, retail price, and available quantity
- [ ] Initial quantity is 3 per breed (seeded once at system first-run)
- [ ] Supply count updates in real time as any trader makes a purchase
- [ ] Breeds with 0 remaining are shown as "Out of Stock" (not hidden)
- [ ] Retail prices match the pet dictionary exactly

---

#### Story 2.1.2 — Purchase Pet from Supply  `Must Have`

> As a Trader, I want to buy one or more pets from the supply at the retail price so that I can build an inventory to trade.

**Tasks:**
- Implement purchase action per breed
- Deduct retail price from `availableCash`
- Add new pet instance to trader's inventory with `age=0`, `health=100`, `desirability=breed default`
- Decrement supply count for that breed in persistent storage

**Acceptance Criteria:**
- [ ] Purchase deducts the exact retail price from `availableCash`
- [ ] New pet appears in trader's inventory immediately after purchase
- [ ] Pet starts with `age = 0`, `health = 100%`, and breed-default desirability
- [ ] Supply count for that breed decreases by 1 per pet purchased
- [ ] If `availableCash < retail price`, purchase is rejected with an error message
- [ ] If supply count = 0, purchase is rejected
- [ ] New pet and updated cash are persisted to storage immediately

---

## Activity 3: Trade on the Secondary Market

*Traders list owned pets for sale and negotiate via bid/accept/reject. This is the core trading loop.*

### Epic 3.1 — Create and Manage Listings

#### Story 3.1.1 — List a Pet for Sale  `Must Have`

> As a Trader, I want to list a pet from my inventory at an asking price so that other traders can bid on it.

**Tasks:**
- Add "List for Sale" action to each pet in inventory
- Accept asking price input (must be > 0)
- Create listing record in persistent storage

**Acceptance Criteria:**
- [ ] Trader can specify any asking price > 0
- [ ] Listed pet appears immediately in the shared Market View
- [ ] A pet cannot be listed if it already has an active listing
- [ ] Listing does not remove the pet from the trader's inventory display (it remains owned)
- [ ] Asking price of $0 or negative is rejected

---

#### Story 3.1.2 — Withdraw a Listing  `Must Have`

> As a Trader, I want to withdraw a pet listing so that I can delist unsold pets and reclaim them.

**Tasks:**
- Add "Withdraw" action to any of the trader's active listings
- If an active bid exists, reject it and release locked cash
- Remove listing from Market View
- Restore pet to "unlisted" state

**Acceptance Criteria:**
- [ ] Withdrawn listing is removed from Market View immediately
- [ ] Any active bid is rejected and the bidder's locked cash is released
- [ ] Bidder receives a withdrawal notification
- [ ] Seller receives no notification for their own withdrawal
- [ ] Pet remains in seller's inventory after withdrawal

---

#### Story 3.1.3 — View Own Active Listings  `Must Have`

> As a Trader, I want to see which of my pets are currently listed so that I can manage them.

**Acceptance Criteria:**
- [ ] Seller sees which of their pets are listed and at what asking price
- [ ] Seller sees whether a bid exists on each listing (yes/no)
- [ ] Seller can see bid amount when reviewing bids to accept/reject

---

### Epic 3.2 — Bidding

#### Story 3.2.1 — Place a Bid  `Must Have`

> As a Trader, I want to place a bid on a listed pet so that the seller can accept it and transfer ownership to me.

**Tasks:**
- Display "Bid" action on all listings not owned by the active trader
- Accept bid amount input
- Validate: amount ≤ trader's `availableCash`
- Lock bid amount in `lockedCash`
- If a previous bid exists, outbid it atomically

**Acceptance Criteria:**
- [ ] Bid amount is deducted from `availableCash` and added to `lockedCash`
- [ ] Bid is visible as "active" in the bidder's panel
- [ ] A trader cannot bid on their own listed pet
- [ ] Bid exceeding `availableCash` is rejected with an error message
- [ ] Bid of $0 or negative is rejected
- [ ] If a previous bidder exists, their cash is released and they receive an "outbid" notification
- [ ] Seller receives a "bid received" notification
- [ ] Only the highest bid is active at any time on a given listing

---

#### Story 3.2.2 — Withdraw Own Bid  `Must Have`

> As a Trader, I want to withdraw my active bid so that I can free my locked cash for other trades.

**Tasks:**
- Show "Withdraw Bid" on any active bid in the bidder's panel
- Release locked cash back to `availableCash`
- Remove bid from the listing
- Notify seller

**Acceptance Criteria:**
- [ ] `lockedCash` decreases and `availableCash` increases by the bid amount immediately
- [ ] Listing returns to "no active bid" state
- [ ] Seller receives a withdrawal notification
- [ ] Bidder's bid status updates to "withdrawn"

---

#### Story 3.2.3 — Be Outbid  `Must Have`

> As a Trader, I want to be notified and have my cash released when someone outbids me so that I can decide to rebid elsewhere.

**Acceptance Criteria:**
- [ ] Previous bidder's locked cash is released the instant a higher bid is placed
- [ ] Previous bidder receives an "outbid" notification
- [ ] Previous bidder's bid status updates to "outbid"
- [ ] New bidder's cash is locked and their bid shows as active

---

### Epic 3.3 — Accept / Reject Bids

#### Story 3.3.1 — Accept a Bid  `Must Have`

> As a Trader (seller), I want to accept an active bid on my listing so that the trade executes and I receive payment.

**Tasks:**
- Show "Accept" action when a listing has an active bid
- On accept: transfer ownership, transfer cash, remove listing, update inventories
- Persist trade result to durable storage
- Send notifications to both parties

**Acceptance Criteria:**
- [ ] Pet transferred to buyer's inventory and removed from seller's immediately
- [ ] Bid amount added to seller's `availableCash`; removed from buyer's `lockedCash`
- [ ] Listing removed from Market View
- [ ] Market View records the most recent trade price for that breed
- [ ] Both parties receive trade completion notifications
- [ ] All UI panels refresh immediately after trade

---

#### Story 3.3.2 — Reject a Bid  `Must Have`

> As a Trader (seller), I want to reject an active bid so that I can wait for a better offer.

**Acceptance Criteria:**
- [ ] Bidder's locked cash is released immediately
- [ ] Listing remains visible in Market View (pet not removed from sale)
- [ ] Bidder receives a rejection notification
- [ ] Seller's panel shows listing is still active with no bid

---

## Activity 4: Manage Account

*Traders can access their account page to view a profile summary, see their full inventory, and manage their virtual cash balance.*

### Epic 4.1 — Account Page

#### Story 4.1.1 — View Account Summary  `Must Have`

> As a Trader, I want to see my account summary on a dedicated page so that I have a single place to view my identity and financial position.

**Tasks:**
- Render account page (accessible from header/nav)
- Show registered email, available cash, locked cash, portfolio value

**Acceptance Criteria:**
- [ ] Account page shows: email, `availableCash`, `lockedCash`, `portfolioValue`
- [ ] Portfolio value formula consistent with trader panel
- [ ] Accessible from the trader panel (header link or profile menu)
- [ ] Data matches trader panel values exactly (≤ $0.01 rounding tolerance)

---

#### Story 4.1.2 — View Inventory from Account Page  `Must Have`

> As a Trader, I want to see my full inventory on my account page so that I have a complete picture of what I own.

**Acceptance Criteria:**
- [ ] All owned pets listed with: breed, type, health, age, desirability, intrinsic value, listed status, expired status
- [ ] Inventory matches the trader panel inventory exactly
- [ ] Inventory is read-only from the account page
- [ ] Expired pets shown with $0.00 intrinsic value and "Expired" label

---

#### Story 4.1.3 — Top Up Balance (Increases availableCash)  `Must Have`

> As a Trader, I want to add virtual cash to my available balance so that my balance increases and I can participate in more trades.

**Tasks:**
- Render top-up form with amount input
- Validate: amount > $0
- Confirmation prompt showing current and new balance before execution
- Add amount to `availableCash` in storage and refresh views

**Acceptance Criteria:**
- [ ] Top-up form accepts a positive dollar amount (> $0)
- [ ] Confirmation prompt shows: "Add $X to your balance? Your available cash will increase from $Y to $Z."
- [ ] On confirmation: `availableCash` **increases** by the entered amount immediately
- [ ] New (higher) balance visible immediately on account page and trader panel
- [ ] Zero or negative amount is rejected with an error

---

#### Story 4.1.4 — Withdraw Balance (Decreases availableCash)  `Must Have`

> As a Trader, I want to withdraw cash from my available balance so that my balance decreases and I reduce my exposure in the system.

**Tasks:**
- Render withdrawal form with amount input
- Validate: amount > $0 and ≤ `availableCash`
- Confirmation prompt showing current and new balance before execution
- Subtract amount from `availableCash` in storage and refresh views

**Acceptance Criteria:**
- [ ] Withdrawal form accepts a positive dollar amount (> $0)
- [ ] Withdrawal amount cannot exceed `availableCash`; locked cash is not withdrawable
- [ ] Confirmation prompt shows: "Withdraw $X from your balance? Your available cash will decrease from $Y to $Z."
- [ ] On confirmation: `availableCash` **decreases** by the entered amount immediately
- [ ] New (lower) balance visible immediately on account page and trader panel
- [ ] Attempting to withdraw more than `availableCash` is rejected with an error
- [ ] Zero or negative amount is rejected

---

## Activity 5: Monitor Own Portfolio

### Epic 5.1 — Trader Dashboard

#### Story 5.1.1 — View Portfolio Summary  `Must Have`

> As a Trader, I want to see my available cash, locked cash, and total portfolio value so that I can make informed trading decisions.

**Tasks:**
- Display `availableCash`, `lockedCash`, `portfolioValue` in trader panel
- Update after every trade and every valuation tick

**Acceptance Criteria:**
- [ ] All three values are visible without any navigation
- [ ] Portfolio value calculation matches the formula exactly
- [ ] Values update immediately after any trade or valuation change
- [ ] Values shown in currency format with 2 decimal places

---

#### Story 5.1.2 — View Pet Inventory  `Must Have`

> As a Trader, I want to see all pets I own with their current intrinsic value so that I know what I hold.

**Acceptance Criteria:**
- [ ] All owned pets visible in inventory regardless of listed/expired state
- [ ] Each pet shows: breed, type, current health, current age, current desirability, current intrinsic value
- [ ] Listed pets marked as "listed" with their asking price
- [ ] Expired pets marked as "expired" (intrinsicValue = $0.00 shown)
- [ ] Inventory updates after every trade and valuation tick

---

### Epic 5.2 — Notifications

#### Story 5.2.1 — Receive Real-Time Notifications  `Must Have`

> As a Trader, I want to receive notifications about bid and trade events so that I can respond promptly.

**Acceptance Criteria:**
- [ ] Notifications appear in the trader's private panel only
- [ ] Every notification includes: event type, pet breed, dollar amount, counterparty
- [ ] Notifications are in chronological order
- [ ] Five notification types supported: received / accepted / rejected / withdrawn / outbid
- [ ] Notifications persist across sessions (stored in durable storage)

---

## Activity 6: Analyze Market Opportunities

### Epic 6.1 — Market View

#### Story 6.1.1 — Browse Active Listings  `Must Have`

> As a Trader, I want to see all current listings in the market so that I can identify buying opportunities.

**Acceptance Criteria:**
- [ ] All active listings visible to all logged-in traders in a shared view
- [ ] Each listing shows: breed, asking price, most recent trade price (if any)
- [ ] Default order is newest listing first
- [ ] Listing appears immediately when created and disappears when withdrawn or sold
- [ ] New supply count is visible in Market View

---

#### Story 6.1.2 — View New Supply Count  `Must Have`

> As a Trader, I want to see how many new pets remain in supply by breed so that I know when to buy from supply vs. the secondary market.

**Acceptance Criteria:**
- [ ] Supply count per breed is visible in or alongside the Market View
- [ ] Count decrements in real time as any trader makes a purchase
- [ ] Supply counts reflect cumulative purchases across all sessions (persistent)

---

### Epic 6.2 — Analysis / Drill-Down View

#### Story 6.2.1 — Drill into Pet Fundamentals  `Must Have`

> As a Trader, I want to view the detailed fundamentals of any pet (owned or listed) so that I can determine whether a price is fair.

**Acceptance Criteria:**
- [ ] Analysis view shows: age (years, 2 dp), health (%), desirability, maintenance cost, intrinsic value ($), expired status
- [ ] Intrinsic value matches the formula: `BasePrice × (Health/100) × (Desirability/10) × (1 - Age/Lifespan)`
- [ ] Expired pets clearly flagged (age ≥ lifespan)
- [ ] View accessible for all pets, including listed pets and pets not owned by the viewer

---

## Activity 7: Track Competition

### Epic 7.1 — Leaderboard

#### Story 7.1.1 — View All Traders' Portfolio Values  `Must Have`

> As a Trader, I want to see all registered traders ranked by portfolio value in real time so that I can adjust my strategy.

**Tasks:**
- Display trader identifier (email or display name), portfolioValue for all registered traders
- Sort by descending portfolioValue
- Refresh on every trade and valuation tick

**Acceptance Criteria:**
- [ ] All registered traders shown with their current portfolio value
- [ ] Ranked by portfolio value (highest first)
- [ ] Updates within 2 seconds of any trade or valuation change
- [ ] Portfolio value = `availableCash + lockedCash + sum(intrinsicValue of owned pets)` — consistent with trader panel
- [ ] Trader identified by email or display name

---

## Activity 8: System — Pet Lifecycle

*Background operations that run without user action.*

### Epic 8.1 — Valuation Lifecycle Tick

#### Story 8.1.1 — Update Pet Valuations Every Minute  `Must Have`

> As the system, I want to update every pet's age, health, desirability, and intrinsic value every minute so that the market reflects a dynamic, time-sensitive environment.

**Tasks:**
- Backend tick loop: runs every 60 seconds (configurable)
- Age increments continuously
- Health: ±5% random variance per tick, clamped to 0–100%
- Desirability: ±5% random variance per tick, clamped to 0–breed max
- Recalculate `intrinsicValue` for every pet (including offline traders' pets)
- Push updates to all connected clients
- Persist updated values to durable storage

**Acceptance Criteria:**
- [ ] Tick interval configurable (default 60 seconds)
- [ ] Age increases by tick_interval_in_seconds / (365 × 24 × 3600) years per tick
- [ ] Health and desirability change by random amount in [-5%, +5%] per tick
- [ ] Health cannot go below 0 or above 100%; desirability cannot go below 0 or above breed max
- [ ] Intrinsic value recalculated using the formula after each tick
- [ ] All trader panels and leaderboard refresh immediately after a tick
- [ ] Updated values persisted so offline traders see current values on next login
- [ ] Pets whose age ≥ lifespan show intrinsicValue = 0 but remain in inventory

---

#### Story 8.1.2 — Real-Time UI Refresh on State Change  `Must Have`

> As a Trader, I want the UI to update immediately whenever a trade occurs or valuations change so that I am always looking at current data.

**Acceptance Criteria:**
- [ ] Trade events trigger immediate UI refresh for all affected panels
- [ ] Valuation ticks trigger immediate refresh of inventory values, portfolio totals, and leaderboard
- [ ] No manual page refresh required during a session
- [ ] Latency from state change to UI update ≤ 2 seconds

---

## Out of Scope

The following are explicitly excluded:

| Item | Reason |
|------|--------|
| Social login (Google, GitHub, OAuth) | Simple email/password sufficient for demo |
| Password reset / forgot password | Post-MVP feature |
| Email verification on registration | Not required for hackathon demo |
| Multi-factor authentication | Security hardening; out of hackathon scope |
| Session reset / bulk state wipe | Not needed — fresh demo via new account registration |
| AI-controlled traders or bots | Spec: human-controlled only |
| Financial compliance, reporting, or tax calculations | Not in scope |
| Distributed locking / concurrency enforcement | Sequential actions sufficient for demo |
| Email or push notifications outside the UI | UI notifications are sufficient |
| Push notifications to offline traders | State caught up passively on next login |
| Pet images or media | UX enhancement, not a requirement |
| Bid history beyond current active bid | Bonus feature per spec |
| Automated test execution | Test cases in markdown are required; execution is optional |
| Real-money payment processing for top-up/withdraw | System is virtual; no payment gateway needed |
| Comparison of multiple pets side-by-side | Post-MVP |
| Historical portfolio value charts | Post-MVP |
