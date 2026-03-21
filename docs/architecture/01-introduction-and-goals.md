# arc42: 01 -- Introduction and Goals

## 1.1 Requirements Overview

The Pets Trading System is a real-time virtual pet marketplace built for the Altus Nova AI-Driven Systems Hackathon. Authenticated traders register accounts, buy pets from a fixed supply, list them on a secondary market, and negotiate trades through a bid/accept/reject workflow. A background lifecycle engine continuously ages all pets and fluctuates their health and desirability, producing dynamic intrinsic values that drive trading decisions.

### Core Functional Requirements


| ID     | Requirement                                                                                  | Priority  |
| ------ | -------------------------------------------------------------------------------------------- | --------- |
| FR-001 | User registration (email/password, $150 starting cash)                                       | Must Have |
| FR-002 | User login with persistent state restoration (including offline tick catch-up)               | Must Have |
| FR-003 | User logout with session invalidation                                                        | Must Have |
| FR-004 | Account page (summary, inventory, top-up, withdraw)                                          | Must Have |
| FR-008 | New supply purchase (20 breeds, 3 units each, retail price)                                  | Must Have |
| FR-009 | Secondary market listing (askingPrice > 0, one per pet)                                      | Must Have |
| FR-011 | Bid placement (locks cash, highest-bid-wins, atomic replacement)                             | Must Have |
| FR-013 | Accept bid (immediate trade execution)                                                       | Must Have |
| FR-014 | Reject bid (release locked cash)                                                             | Must Have |
| FR-015 | Market View (shared, active listings, recent trade prices, supply counts)                    | Must Have |
| FR-016 | Analysis / Drill-Down View (pet fundamentals)                                                | Must Have |
| FR-017 | Leaderboard (all traders, real-time portfolio values)                                        | Must Have |
| FR-018 | Notifications (5 types, private, persistent)                                                 | Must Have |
| FR-019 | Pet Lifecycle Tick (60s configurable, age/health/desirability variance)                      | Must Have |
| FR-020 | Intrinsic Value Formula: `BasePrice x (Health/100) x (Desirability/10) x (1 - Age/Lifespan)` | Must Have |


### Key Business Rules

- Starting cash: $150 per new account
- Supply: 3 units per breed (20 breeds = 60 total pets)
- Only highest bid is active per listing; new higher bid atomically replaces previous
- Traders cannot bid on their own pets
- Withdrawing a listing rejects all active bids and releases locked cash
- Expired pets (age >= lifespan) have intrinsicValue = 0 but remain tradeable
- Health clamped [0%, 100%], desirability clamped [0, breed max]

## 1.2 Quality Goals


| Priority | Quality Goal                 | Scenario                                                                                      |
| -------- | ---------------------------- | --------------------------------------------------------------------------------------------- |
| 1        | **Real-time responsiveness** | UI reflects state changes within 2 seconds of any trade or lifecycle tick                     |
| 2        | **Data consistency**         | Portfolio value on trader panel and leaderboard are always identical for the same trader      |
| 3        | **State durability**         | All trading state persists across server restarts; offline tick updates visible on next login |
| 4        | **Formula precision**        | Intrinsic value consistent across backend and frontend (divergence < $0.01)                   |
| 5        | **API performance**          | Backend API endpoints respond in < 500ms p95 under demo load                                  |


## 1.3 Stakeholders


| Role                 | Description                                     | Key Expectations                                                        |
| -------------------- | ----------------------------------------------- | ----------------------------------------------------------------------- |
| **Trader**           | Any registered user participating in the market | Clear UI, fast updates, accurate portfolio data, offline catch-up       |
| **Hackathon Judge**  | Evaluates solution against scoring matrix       | All required views working, correct valuation, explainable architecture |
| **Demo Facilitator** | Person running the live demo                    | Fresh demo via new account registration, stable deployment              |
| **Development Team** | Engineers building the system                   | Clear architecture, well-defined service boundaries, deployable IaC     |


