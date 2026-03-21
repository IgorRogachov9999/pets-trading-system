# BDD Scenarios — Pets Trading System

> **Version:** 3.0
> **Date:** 2026-03-20
> **Status:** Baselined
> **Format:** Gherkin (Cucumber-compatible)
> **Change from v2.0:** Starting cash $150. Removed Session Reset. Added explicit offline tick catch-up scenarios. Clarified top-up increases and withdrawal decreases availableCash.

---

## Feature: User Registration

```gherkin
Feature: Register a new trader account
  As a new user
  I want to register with my email and password
  So that I can participate as a trader in the pets marketplace

  Scenario: Successfully register a new account
    Given no account exists for "alice@example.com"
    When the user registers with email "alice@example.com" and password "securepass"
    Then an account is created for "alice@example.com"
    And the account starts with $150 available cash
    And the account starts with an empty inventory
    And the user is logged in immediately
    And the user is redirected to their trader panel

  Scenario: Registration rejected for duplicate email
    Given an account already exists for "alice@example.com"
    When a user attempts to register with email "alice@example.com" and password "anotherpass"
    Then the registration is rejected
    And an error message indicates the email is already registered
    And no new account is created

  Scenario: Registration rejected for invalid email format
    When a user attempts to register with email "not-an-email" and password "securepass"
    Then the registration is rejected
    And an error message indicates the email format is invalid

  Scenario: Registration rejected for password too short
    When a user attempts to register with email "bob@example.com" and password "short"
    Then the registration is rejected
    And an error message indicates the password must be at least 8 characters

  Scenario Outline: Email format validation
    When a user attempts to register with email "<email>" and password "validpass1"
    Then the registration <outcome>

    Examples:
      | email                  | outcome     |
      | valid@example.com      | succeeds    |
      | user@sub.domain.co     | succeeds    |
      | missing-at-sign        | is rejected |
      | @nodomain.com          | is rejected |
      | noDomain@              | is rejected |
```

---

## Feature: Login and Logout

```gherkin
Feature: Trader login and logout
  As a registered user
  I want to log in and log out securely
  So that my account is protected and my session is managed correctly

  Background:
    Given an account exists for "alice@example.com" with password "securepass"
    And Alice has $450 available cash and 2 pets in inventory from her last session

  Scenario: Successful login restores previous state
    When Alice logs in with email "alice@example.com" and password "securepass"
    Then Alice is redirected to her trader panel
    And Alice's trader panel shows $450 available cash
    And Alice's inventory contains 2 pets

  Scenario: Login with incorrect password is rejected
    When a user attempts to login with email "alice@example.com" and password "wrongpass"
    Then the login is rejected
    And the error message is "Invalid email or password"
    And no hint is given about which field is incorrect

  Scenario: Login with unknown email is rejected
    When a user attempts to login with email "unknown@example.com" and password "anypass"
    Then the login is rejected
    And the error message is "Invalid email or password"

  Scenario: Unauthenticated access to trader panel redirects to login
    Given no user is logged in
    When a user navigates to the trader panel URL directly
    Then they are redirected to the login page

  Scenario: Successful logout invalidates session
    Given Alice is logged in
    When Alice clicks logout
    Then Alice is redirected to the login page
    And Alice's session is invalidated on the server
    And navigating back to the trader panel URL redirects to login

  Scenario: State is preserved after logout and re-login
    Given Alice is logged in and has $320 available cash
    When Alice logs out
    And Alice logs back in with email "alice@example.com" and password "securepass"
    Then Alice's trader panel shows $320 available cash
```

---

## Feature: Account Management — Top-Up and Withdraw

```gherkin
Feature: Manage virtual cash balance from account page
  As a Trader
  I want to top up and withdraw my virtual cash balance
  So that I can control how much I participate in the market

  Background:
    Given Alice is logged in with $300 available cash and $50 locked cash

  Scenario: Top-up INCREASES availableCash
    When Alice navigates to the account page
    And Alice requests to top up $200
    And Alice confirms the prompt "Add $200.00 to your balance? Your available cash will increase from $300.00 to $500.00."
    Then Alice's available cash INCREASES from $300 to $500
    And the trader panel also shows $500 available cash

  Scenario: Top-up rejected for zero amount
    When Alice requests to top up $0
    Then the top-up is rejected
    And an error message indicates the amount must be greater than zero
    And Alice's available cash is unchanged at $300

  Scenario: Top-up rejected for negative amount
    When Alice requests to top up -$50
    Then the top-up is rejected
    And Alice's available cash is unchanged at $300

  Scenario: Withdrawal DECREASES availableCash
    When Alice requests to withdraw $150
    And Alice confirms the prompt "Withdraw $150.00 from your balance? Your available cash will decrease from $300.00 to $150.00."
    Then Alice's available cash DECREASES from $300 to $150
    And Alice's locked cash is still $50 (unaffected by withdrawal)
    And the trader panel also shows $150 available cash

  Scenario: Withdrawal rejected when amount exceeds available cash
    When Alice requests to withdraw $400
    Then the withdrawal is rejected
    And an error message indicates the amount exceeds available cash
    And Alice's available cash is unchanged at $300

  Scenario: Locked cash cannot be withdrawn
    Given Alice has $300 available cash and $50 locked cash
    When Alice requests to withdraw $320
    Then the withdrawal is rejected
    And the error message indicates only available cash can be withdrawn (not locked cash)

  Scenario: Withdrawal rejected for zero amount
    When Alice requests to withdraw $0
    Then the withdrawal is rejected
    And Alice's available cash is unchanged at $300

  Scenario: Account page inventory matches trader panel
    Given Alice owns a Poodle with intrinsic value $95.00
    When Alice navigates to the account page
    Then the account page inventory shows the Poodle with intrinsic value $95.00
    And the portfolio value on the account page equals $300 + $50 + $95 = $445.00
```

---

## Feature: Persistent State Across Server Restarts

```gherkin
Feature: State persists across server restarts
  As a Trader
  I want my trading state to survive server restarts
  So that I do not lose cash, inventory, or trade history

  Scenario: Trader state survives server restart
    Given Alice is logged in with $450 available cash and 2 pets in inventory
    And Alice has an active bid of $80 on Bob's Labrador
    When the server restarts
    And Alice logs in again
    Then Alice's available cash is $450
    And Alice's locked cash includes the $80 bid
    And Alice's inventory still contains 2 pets
    And Alice's active bid on the Labrador is restored

  Scenario: Supply counts survive server restart
    Given the Labrador supply count is 1 (2 have been purchased)
    When the server restarts
    Then the Labrador supply count is still 1

  Scenario: Active listings survive server restart
    Given Bob has a Siamese listed at $95
    When the server restarts
    Then the Siamese listing is still visible in the Market View at $95
```

---

## Feature: New Supply Purchase

```gherkin
Feature: Purchase pets from new supply
  As a Trader
  I want to buy pets from the fixed supply at retail price
  So that I can build my inventory to trade on the secondary market

  Background:
    Given the system has 3 units of each breed in new supply
    And Alice is logged in with $150 available cash

  Scenario: Trader successfully purchases a pet from supply
    When Alice purchases 1 Labrador from new supply
    Then Alice's available cash decreases by $100
    And a new Labrador with age=0, health=100%, and default desirability is added to Alice's inventory
    And the Labrador supply count decreases to 2
    And the Market View shows 2 Labradors remaining in supply

  Scenario: Trader purchases multiple pets of the same breed
    Given the Labrador supply count is 3
    When Alice purchases 2 Labradors from new supply
    Then Alice's available cash decreases by $200
    And 2 new Labradors appear in Alice's inventory
    And the Labrador supply count decreases to 1

  Scenario: Purchase rejected when trader has insufficient cash
    Given Alice has $80 available cash
    When Alice attempts to purchase 1 Poodle at retail price $110
    Then the purchase is rejected
    And Alice's cash remains $80
    And the Poodle supply count is unchanged
    And an error message is shown to Alice

  Scenario: Purchase rejected when supply is exhausted
    Given the Betta supply count is 0
    When Alice attempts to purchase 1 Betta from supply
    Then the purchase is rejected
    And Alice's cash is unchanged
    And an error message indicates the breed is out of stock

  Scenario Outline: Retail prices match the pet dictionary exactly
    When Alice purchases 1 <breed> from new supply
    Then Alice's cash decreases by exactly $<price>

    Examples:
      | breed      | price |
      | Labrador   | 100   |
      | Goldfish   | 5     |
      | Macaw      | 120   |
      | Guppy      | 4     |
      | Siamese    | 90    |
```

---

## Feature: Secondary Market — Listings

```gherkin
Feature: Create and manage pet listings
  As a Trader
  I want to list pets I own for sale at an asking price
  So that other traders can bid on them

  Background:
    Given Alice is logged in and owns a Poodle with health=100%, age=0
    And the Poodle is not currently listed

  Scenario: Trader creates a listing at a valid asking price
    When Alice lists the Poodle for sale at $150
    Then the Poodle appears in the Market View with asking price $150
    And the Poodle is marked as "listed" in Alice's inventory
    And Alice's cash is unchanged

  Scenario: Listing rejected with asking price of zero
    When Alice attempts to list the Poodle for $0
    Then the listing is rejected
    And the Poodle does not appear in the Market View

  Scenario: A pet cannot be listed twice simultaneously
    Given the Poodle is already listed at $150
    When Alice attempts to list the same Poodle at $120
    Then the second listing is rejected
    And the Market View still shows only one listing for the Poodle at $150

  Scenario: Trader withdraws a listing with no active bid
    Given the Poodle is listed at $150 with no active bid
    When Alice withdraws the listing
    Then the listing is removed from the Market View
    And the Poodle remains in Alice's inventory as "unlisted"

  Scenario: Withdrawing a listing rejects any active bid
    Given Bob is logged in with $200 available cash
    And Bob has an active bid of $130 on the Poodle
    And Bob has $130 locked in their locked cash
    When Alice withdraws the listing
    Then the listing is removed from the Market View
    And Bob's $130 is released back to available cash
    And Bob receives a notification: "Your bid of $130 on Poodle was rejected (listing withdrawn by Alice)"
    And Alice's panel shows the Poodle as unlisted
```

---

## Feature: Secondary Market — Bidding

```gherkin
Feature: Place and manage bids
  As a Trader
  I want to place bids on listed pets
  So that sellers can accept my offer and transfer ownership

  Background:
    Given Alice is logged in and owns a Bulldog listed for sale at $80
    And Bob is logged in with $200 available cash and $0 locked cash
    And Carol is logged in with $200 available cash and $0 locked cash

  Scenario: Trader successfully places a bid below asking price
    When Bob places a bid of $60 on Alice's Bulldog
    Then Bob's available cash decreases by $60
    And Bob's locked cash increases by $60
    And Bob's bid status shows "active"
    And Alice receives a notification: "New bid of $60 from Bob on Bulldog"

  Scenario: Trader successfully places a bid above asking price
    When Bob places a bid of $100 on Alice's Bulldog
    Then Bob's available cash decreases by $100
    And Bob's locked cash increases by $100
    And Bob's bid is the active bid on the listing

  Scenario: Bid rejected when amount exceeds available cash
    Given Bob has $50 available cash
    When Bob attempts to bid $60 on Alice's Bulldog
    Then the bid is rejected
    And Bob's cash is unchanged
    And an error message is shown to Bob

  Scenario: Bid rejected when amount is zero
    When Bob attempts to bid $0 on Alice's Bulldog
    Then the bid is rejected

  Scenario: Trader cannot bid on their own pet
    When Alice attempts to place a bid on their own Bulldog listing
    Then the bid is rejected
    And an error message indicates self-bidding is not allowed

  Scenario: New higher bid atomically replaces the previous bid
    Given Bob has an active bid of $60 on Alice's Bulldog
    And Bob has $140 remaining available cash
    When Carol places a bid of $70 on the same Bulldog
    Then Carol's available cash decreases by $70
    And Carol's bid is now the active bid on the listing
    And Bob's $60 is released back to their available cash
    And Bob receives a notification: "Your bid of $60 on Bulldog was outbid by Carol ($70)"
    And Alice receives a notification: "New highest bid of $70 from Carol on Bulldog"

  Scenario: A lower replacement bid is rejected (highest bid rule)
    Given Bob has an active bid of $90 on Alice's Bulldog
    When Carol attempts to place a bid of $80 on the same Bulldog
    Then the bid is rejected
    And Bob's bid remains active at $90

  Scenario: Trader withdraws their own active bid
    Given Bob has an active bid of $60 on Alice's Bulldog
    When Bob withdraws their bid
    Then Bob's $60 is released back to available cash
    And Bob's locked cash decreases by $60
    And Bob's bid status shows "withdrawn"
    And the Bulldog listing shows no active bid
    And Alice receives a notification: "Bid of $60 on Bulldog was withdrawn by Bob"

  Scenario: Trader can bid on multiple different listings simultaneously
    Given Alice also owns a Bengal listed at $75
    And Bob has bid $60 on the Bulldog
    When Bob places a bid of $70 on the Bengal (owned by Alice)
    Then Bob has two active bids: $60 on Bulldog and $70 on Bengal
    And Bob's total locked cash is $130
    And Bob's available cash has decreased by $130 total
```

---

## Feature: Secondary Market — Accept / Reject

```gherkin
Feature: Seller accepts or rejects bids
  As a Trader (seller)
  I want to accept or reject bids on my listings
  So that I control whether a trade executes

  Background:
    Given Alice is logged in and owns a Siamese listed for $90
    And Bob is logged in and has placed an active bid of $95 on the Siamese
    And Bob has $95 locked cash and $105 remaining available cash

  Scenario: Seller accepts a bid — trade executes immediately
    When Alice accepts Bob's bid of $95
    Then the Siamese is transferred to Bob's inventory
    And the Siamese is removed from Alice's inventory
    And Alice's available cash increases by $95
    And Bob's locked cash decreases by $95
    And the listing is removed from the Market View
    And the Market View records $95 as the most recent trade price for Siamese
    And Alice receives a notification: "Siamese sold to Bob for $95"
    And Bob receives a notification: "Bid accepted — Siamese purchased from Alice for $95"
    And all trader panels and leaderboard refresh immediately

  Scenario: Seller rejects a bid — listing stays open
    When Alice rejects Bob's bid of $95
    Then Bob's $95 is released back to their available cash
    And Bob's locked cash decreases by $95
    And the Siamese listing remains in the Market View at asking price $90
    And Bob receives a notification: "Your bid of $95 on Siamese was rejected by Alice"
    And Alice's panel shows the Siamese listing is still active with no active bid

  Scenario: Seller cannot accept a bid if no active bid exists
    Given the Siamese listing has no active bid
    When Alice attempts to accept a bid
    Then the action is unavailable (no accept button shown)
```

---

## Feature: Pet Lifecycle — Valuation Tick

```gherkin
Feature: Automatic pet valuation updates
  As the system
  I want to recalculate every pet's value every minute
  So that the market reflects dynamic, time-sensitive fundamentals

  Background:
    Given a Macaw owned by Alice with age=1.0, health=95%, desirability=9, basePrice=$120, lifespan=50

  Scenario: Valuation tick updates age, health, desirability, and intrinsic value
    Given the tick interval is 60 seconds
    When a valuation tick occurs
    Then the Macaw's age increases by approximately 60/(365×24×3600) years
    And the Macaw's health changes by a random value in [-5%, +5%] relative to current health
    And the Macaw's desirability changes by a random value in [-5%, +5%] relative to current value
    And the Macaw's intrinsic value is recalculated as: $120 × (newHealth/100) × (newDesirability/10) × (1 - newAge/50)
    And all trader panels display the updated intrinsic value within 2 seconds

  Scenario: Tick updates pets owned by offline traders
    Given Bob is logged out but owns a Labrador
    When a valuation tick occurs
    Then the Labrador's age, health, desirability, and intrinsic value are updated in storage
    And when Bob logs in next, the Labrador shows current post-tick values (not stale pre-logout values)

  Scenario: Multiple ticks while offline are all applied before next login
    Given Bob is logged out and owns a Macaw with health=80%
    When 5 valuation ticks occur while Bob is offline
    Then when Bob logs in, the Macaw's health reflects all 5 ticks of variance (not just the last tick)

  Scenario: Pet expires while trader is offline
    Given Bob is logged out and owns a Guppy with age=2.99 years and lifespan=3 years
    When enough ticks occur to push the Guppy's age past 3.0 years
    Then when Bob logs in, the Guppy is shown as "expired" with intrinsic value $0.00

  Scenario: Health cannot exceed 100% after a positive tick
    Given the Macaw's health is 98%
    When a valuation tick applies +4% health variance
    Then the Macaw's health is clamped to 100%

  Scenario: Health cannot fall below 0% after a negative tick
    Given a Guppy with health=2%
    When a valuation tick applies -5% health variance
    Then the Guppy's health is clamped to 0%

  Scenario: Expired pet shows intrinsic value of zero
    Given a Guppy with age=3.0 years and lifespan=3 years
    When a valuation tick occurs
    Then the Guppy's intrinsic value is $0.00
    And the Guppy is marked as "expired" in all views
    And the Guppy remains in the owner's inventory and is still listeable

  Scenario: All panels refresh after a valuation tick
    When a valuation tick occurs
    Then every logged-in trader's portfolio value is recalculated
    And the leaderboard ranking is updated
    And changes are visible in the UI within 2 seconds of the tick completing

  Scenario Outline: Intrinsic value formula produces correct results
    Given a pet with basePrice=<base>, health=<health>%, desirability=<des>, age=<age>, lifespan=<lifespan>
    When intrinsic value is calculated
    Then the result is <expected> (±$0.01)

    Examples:
      | base | health | des | age   | lifespan | expected |
      | 110  | 94.24  | 9   | 0.77  | 14       | 88.16    |
      | 100  | 92.11  | 8   | 3.12  | 12       | 61.20    |
      | 90   | 78.34  | 9   | 5.64  | 15       | 42.13    |
      | 5    | 67.85  | 5   | 8.77  | 10       | 0.21     |
```

---

## Feature: Trader Panel — Portfolio Visibility

```gherkin
Feature: Trader views their private portfolio summary
  As a Trader
  I want to see my cash, locked cash, and total portfolio value
  So that I can make informed trading decisions

  Background:
    Given Bob is logged in with $300 available cash, $80 locked cash
    And Bob owns a Poodle with intrinsic value $88.16 and a Goldfish with intrinsic value $4.00

  Scenario: Portfolio value is calculated correctly
    Then Bob's displayed portfolio value is $472.16
    # 300 + 80 + 88.16 + 4.00 = 472.16

  Scenario: Portfolio value updates immediately after a trade
    When Bob sells the Poodle for $100 (bid accepted)
    Then Bob's available cash increases by $100
    And Bob's portfolio value recalculates immediately

  Scenario: Trader cannot see another trader's cash or inventory
    When Alice is logged in and views her own panel
    Then Alice cannot see Bob's available cash
    And Alice cannot see Bob's inventory details
    And Alice cannot see Bob's notifications
```

---

## Feature: Leaderboard

```gherkin
Feature: Real-time leaderboard
  As a Trader
  I want to see all registered traders ranked by portfolio value
  So that I can track relative performance and adjust my strategy

  Scenario: Leaderboard shows all traders ranked by portfolio value
    Given Alice's portfolio = $520, Bob's portfolio = $480, Carol's portfolio = $550
    Then the leaderboard shows:
      | Rank | Trader | Portfolio Value |
      | 1    | Carol  | $550.00         |
      | 2    | Alice  | $520.00         |
      | 3    | Bob    | $480.00         |

  Scenario: Leaderboard includes all registered traders regardless of whether they are online
    Given Dave is registered but currently logged out with portfolio value $600
    Then Dave appears on the leaderboard with $600.00
    And Dave's rank is determined by their portfolio value like any other trader

  Scenario: Leaderboard updates immediately after a trade
    Given Alice sells a Macaw to Bob for $110
    When the trade completes
    Then the leaderboard reflects updated portfolio values for both Alice and Bob within 2 seconds

  Scenario: Leaderboard updates immediately after a valuation tick
    When a valuation tick changes pet intrinsic values
    Then the leaderboard ranking and values update within 2 seconds
```

---

## Feature: Market View

```gherkin
Feature: Shared market view with all active listings
  As a Trader
  I want to see all current listings in a shared market view
  So that I can identify buying opportunities across the market

  Scenario: Market view shows all active listings newest first
    Given Alice listed a Bulldog at 10:00
    And Bob listed a Siamese at 10:05
    And Carol listed a Macaw at 10:03
    Then the market view shows listings in order:
      | Position | Pet     | Listed By | Asking Price |
      | 1        | Siamese | Bob       | (price)      |
      | 2        | Macaw   | Carol     | (price)      |
      | 3        | Bulldog | Alice     | (price)      |

  Scenario: Market view shows the most recent trade price for each breed
    Given a Poodle was last traded at $130
    When the Poodle listing is viewed in the Market View
    Then the most recent trade price shown is $130

  Scenario: Market view shows most recent trade price as blank when no trades have occurred
    Given no Beagle has ever been traded in this session
    Then the most recent trade price for Beagle shows as "—" or empty

  Scenario: Listing disappears from market view when withdrawn
    Given a Bulldog listing is visible in the Market View
    When the seller withdraws the listing
    Then the Bulldog listing is no longer visible in the Market View within 1 second

  Scenario: Listing disappears from market view when a trade completes
    Given a Siamese listing is visible in the Market View with an active bid
    When the seller accepts the bid
    Then the Siamese listing is no longer visible in the Market View within 1 second

  Scenario: Market view shows new supply count
    Given 2 Labradors remain in new supply
    Then the Market View shows "2 Labradors available in new supply"
```

---

## Feature: Notifications

```gherkin
Feature: Trader receives private notifications for bid and trade events
  As a Trader
  I want to receive notifications for all events affecting my listings and bids
  So that I can respond to offers without constantly watching the market

  Scenario Outline: Correct notification is delivered for each event type
    Given <actor> performs <action> involving <counterparty> and <pet> at <amount>
    Then <recipient> receives a notification matching "<message_pattern>"

    Examples:
      | actor | action               | counterparty | pet    | amount | recipient | message_pattern                                       |
      | Bob   | places a bid         | Alice        | Poodle | $130   | Alice     | "New bid of $130 from Bob on Poodle"                  |
      | Alice | accepts the bid      | Bob          | Poodle | $130   | Bob       | "Bid accepted — Poodle purchased from Alice for $130" |
      | Alice | accepts the bid      | Bob          | Poodle | $130   | Alice     | "Poodle sold to Bob for $130"                         |
      | Alice | rejects the bid      | Bob          | Poodle | $130   | Bob       | "Bid of $130 on Poodle rejected by Alice"             |
      | Bob   | withdraws their bid  | Alice        | Poodle | $130   | Alice     | "Bid of $130 on Poodle withdrawn by Bob"              |
      | Carol | places a higher bid  | Bob          | Poodle | $140   | Bob       | "Your bid of $130 on Poodle was outbid by Carol"      |

  Scenario: Notifications are private — only the recipient sees them
    Given Bob receives a bid rejection notification
    Then Alice's notification panel does not show Bob's notification
    And Carol's notification panel does not show Bob's notification

  Scenario: Notifications are displayed in chronological order
    Given Alice has received 3 notifications at different times
    Then the notifications are displayed in the order they were received

  Scenario: Notifications persist across logout and re-login
    Given Alice has 3 notifications in her notification panel
    When Alice logs out
    And Alice logs back in
    Then Alice's notification panel still shows 3 notifications in the original order
```

---

## Feature: Analysis / Drill-Down View

```gherkin
Feature: Detailed pet fundamentals view
  As a Trader
  I want to view the detailed fundamentals of any pet
  So that I can calculate whether a bid price represents fair value

  Background:
    Given a Macaw owned by Alice with:
      | Field        | Value  |
      | Age          | 10.57  |
      | Health       | 95.11% |
      | Desirability | 9      |
      | BasePrice    | $120   |
      | Lifespan     | 50     |
      | Maintenance  | $8     |

  Scenario: Analysis view shows all required fundamentals
    When Bob opens the analysis view for Alice's Macaw
    Then the view displays:
      | Field           | Value       |
      | Age             | 10.57 years |
      | Health          | 95.11%      |
      | Desirability    | 9           |
      | Maintenance     | $8          |
      | Intrinsic Value | $105.77     |
      | Expired         | No          |

  Scenario: Analysis view for an expired pet shows zero intrinsic value
    Given a Guppy with age=3.5 years and lifespan=3 years
    When a trader opens the analysis view for the Guppy
    Then the Expired field shows "Yes"
    And the Intrinsic Value shows $0.00

  Scenario: Any trader can view fundamentals for any pet (not just their own)
    Given Bob owns a Siamese listed in the market
    When Carol opens the analysis view for Bob's Siamese
    Then all fundamentals are visible to Carol
```
