# Pets Trading System

## Table of Contents

- [System Requirements](#system-requirements)
  - [1. Business Context / Purpose](#1-business-context--purpose)
  - [2. Core System Mechanics](#2-core-system-mechanics)
    - [2.1 Traders](#21-traders)
    - [2.2 Pets](#22-pets)
    - [2.3 Market & Trades](#23-market--trades)
    - [2.4 UI & Views](#24-ui--views)
    - [2.5 System Behavior](#25-system-behavior)
  - [3. Optional / Bonus Features](#3-optional--bonus-features)
  - [4. Ready-to-Use Pet Dictionary](#4-ready-to-use-pet-dictionary)
    - [Intrinsic Value Formula](#intrinsic-value-formula)
  - [5. Example Flows](#5-example-flows)
    - [5.1 Purchasing New Pets](#51-purchasing-new-pets)
    - [5.2 Secondary Market Trade](#52-secondary-market-trade)
    - [5.3 Bid Withdrawal](#53-bid-withdrawal)
    - [5.4 Valuation Update](#54-valuation-update)
    - [5.5 Bid Being Outbid](#55-bid-being-outbid)
    - [5.6 Trader Delisting a Pet](#56-trader-delisting-a-pet)
    - [5.7 Reviewing Intrinsic Value](#57-reviewing-intrinsic-value)
    - [5.8 Using Leaderboard](#58-using-leaderboard)
- [Clarifying Questions & Answers](#clarifying-questions--answers)
  - [1. Trader Behavior & Controls](#1-trader-behavior--controls)
  - [2. Market Mechanics & Trading Rules](#2-market-mechanics--trading-rules)
  - [3. Pets & Valuation](#3-pets--valuation)
  - [4. UI / Views](#4-ui--views)
  - [5. System Behavior](#5-system-behavior)
- [UX / Experience Considerations left to Participant Decisions](#ux--experience-considerations-left-to-participant-decisions)

---

## System Requirements

### 1. Business Context / Purpose

Participants will build a **"Trading Pets" system** to demonstrate **end-to-end AI-assisted system development**, including design, coding, deployment, and automated testing.

- **Goal:** Human-controlled Traders buy, sell, and manage virtual pets, demonstrating AI-assisted system development rather than trading strategies.
- **Focus Areas for AI Use:**
  - UI/UX design
  - Technical architecture / data modeling
  - Front-end & back-end coding
  - Cloud deployment (IaC)
  - Automated testing

---

### 2. Core System Mechanics

#### 2.1 Traders

- **Number:** Exactly 3 Traders.
- **UI Panels:** Each Trader has a separate panel/window.
- **Private Information:** Inventory, available cash, locked cash, portfolio value, and notifications.
- **Cash:** Fixed initial amount sufficient to buy 5–8 new pets.
- **Portfolio Value:** `available cash + locked cash + market value of pets`

#### 2.2 Pets

- **Dictionary:** Provided read-only, 20 breeds (5 dogs, 5 cats, 5 birds, 5 fish).
- **Parameters per breed:**
  - Lifespan (years)
  - Desirability (numeric score)
  - Maintenance cost
  - Full health = 100%
  - Age = 0 (new pets)
- **Intrinsic Value Formula:** Same for all pets; uses breed-specific parameters.

```
Intrinsic Value = Base Value × (Health / 100) × (Desirability / 10) × (1 - Age / Lifespan)
```

- **Supply:** Limited (default 3 per type), decreases as pets are purchased.
- **Unique Entities:** Each pet instantiated separately; lifecycle tracked individually.
- **Lifecycle Updates:** Age increases continuously; health and desirability ±5% per update. Updates every minute (configurable).

#### 2.3 Market & Trades

**New Pet Purchases:**
- From supply at fixed retail price.
- Multiple pets may be purchased if cash and supply allow.
- Not considered a secondary-market trade.

**Secondary-Market Trades:**
- One pet per transaction.
- Bid above or below asking price allowed.
- Highest bid is active; cash locked.
- Seller can accept/reject; trade executes immediately.
- Bids > available (unlocked) cash are rejected.
- Buyers cannot bid on their own pets.
- Buyers only see status of their own bids (active, rejected, withdrawn, outbid).

**Listings:**
- Asking price > 0.
- Pet listings can be withdrawn by seller; active bids are rejected and locked cash released.
- Only one active listing per pet.
- Multiple pets may be listed simultaneously.

#### 2.4 UI & Views

- **Trader Panel:** Inventory, available cash, locked cash, total portfolio value.
- **Market View:**
  - Current listings
  - Asking price
  - Most recent trade price
  - New supply count
  - Default order = newest listings first (optional sorting/filtering)
- **Analysis / Drill-Down View:**
  - Full pet fundamentals (age, health, desirability, intrinsic value)
  - Expired status
- **Notifications:**
  - Bid received, accepted, rejected, withdrawn, outbid
  - Include pet, price, counterparty
  - Chronological order

#### 2.5 System Behavior

- Sequential actions sufficient for demo; no concurrency enforcement required.
- Trades and valuation updates trigger immediate UI refresh if any metrics change.
- Expired pets remain in inventory; residual market value is market-driven.
- Cash for active bids locked; released upon bid withdrawal or rejection.
- Multiple active bids across different pets allowed.

---

### 3. Optional / Bonus Features

- Sorting/filtering in market view
- Bid timestamps for history
- Performance / scalability considerations
- Audit trails / ledger beyond notifications
- Enhanced UI interactions (confirmation prompts, visualization enhancements)

---

### 4. Ready-to-Use Pet Dictionary

| Type | Breed | Lifespan | Desirability | Maintenance | Health | Age | Base/Retail Price |
|------|-------|----------|-------------|-------------|--------|-----|-------------------|
| **Dog** | Labrador | 12 | 8 | 5 | 100 | 0 | 100 |
| **Dog** | Beagle | 13 | 7 | 4 | 100 | 0 | 90 |
| **Dog** | Poodle | 14 | 9 | 6 | 100 | 0 | 110 |
| **Dog** | Bulldog | 10 | 6 | 7 | 100 | 0 | 80 |
| **Dog** | Pit Bull | 11 | 5 | 5 | 100 | 0 | 70 |
| **Cat** | Siamese | 15 | 9 | 4 | 100 | 0 | 90 |
| **Cat** | Persian | 14 | 8 | 6 | 100 | 0 | 85 |
| **Cat** | Maine Coon | 16 | 7 | 5 | 100 | 0 | 80 |
| **Cat** | Bengal | 12 | 6 | 5 | 100 | 0 | 75 |
| **Cat** | Sphynx | 13 | 5 | 7 | 100 | 0 | 70 |
| **Bird** | Parakeet | 8 | 7 | 3 | 100 | 0 | 25 |
| **Bird** | Canary | 10 | 6 | 2 | 100 | 0 | 20 |
| **Bird** | Cockatiel | 12 | 8 | 3 | 100 | 0 | 30 |
| **Bird** | Macaw | 50 | 9 | 8 | 100 | 0 | 120 |
| **Bird** | Lovebird | 15 | 5 | 3 | 100 | 0 | 15 |
| **Fish** | Goldfish | 10 | 5 | 2 | 100 | 0 | 5 |
| **Fish** | Betta | 5 | 6 | 1 | 100 | 0 | 6 |
| **Fish** | Guppy | 3 | 4 | 1 | 100 | 0 | 4 |
| **Fish** | Angelfish | 8 | 7 | 2 | 100 | 0 | 8 |
| **Fish** | Clownfish | 6 | 8 | 3 | 100 | 0 | 10 |

#### Intrinsic Value Formula

```
Intrinsic Value = Base Value × (Health / 100) × (Desirability / 10) × (1 - Age / Lifespan)
```

**Where:**

- **Base Value** = Suggested retail price for the pet type (set in the dictionary)
- **Health** = Current health percentage (0–100%)
- **Desirability** = Breed-specific desirability (1–10 scale)
- **Age** = Current age of the pet in years
- **Lifespan** = Maximum lifespan of the breed in years

**Notes:**

- Age starts at 0 when purchased from supply.
- Health and desirability fluctuate ±5% each update (*once per minute*).
- Residual value at end-of-life is determined by the market (Traders can still bid on "expired" pets).

#### 20 Random Intrinsic Value Scenarios

| Type | Breed | Age (yrs) | Health (%) | Desirability | Base Price | Intrinsic Value |
|------|-------|-----------|------------|-------------|------------|-----------------|
| Cat | Sphynx | 12.29 | 77.82 | 5 | 70 | 1.48 |
| Dog | Poodle | 0.77 | 94.24 | 9 | 110 | 88.16 |
| Bird | Lovebird | 2.17 | 55.95 | 5 | 15 | 3.59 |
| Fish | Guppy | 0.82 | 86.18 | 4 | 4 | 1.00 |
| Fish | Goldfish | 8.77 | 67.85 | 5 | 5 | 0.21 |
| Dog | Labrador | 3.12 | 92.11 | 8 | 100 | 61.20 |
| Cat | Siamese | 5.64 | 78.34 | 9 | 90 | 42.13 |
| Dog | Beagle | 6.45 | 84.22 | 7 | 90 | 27.08 |
| Bird | Macaw | 10.57 | 95.11 | 9 | 120 | 105.77 |
| Fish | Betta | 1.12 | 73.45 | 6 | 6 | 3.46 |
| Dog | Pit Bull | 8.22 | 67.83 | 5 | 70 | 5.12 |
| Cat | Persian | 4.91 | 88.33 | 8 | 85 | 38.22 |
| Dog | Bulldog | 2.78 | 95.44 | 6 | 80 | 44.01 |
| Cat | Maine Coon | 6.33 | 90.12 | 7 | 80 | 35.26 |
| Bird | Cockatiel | 3.44 | 77.22 | 8 | 30 | 15.56 |
| Fish | Angelfish | 5.12 | 69.81 | 7 | 8 | 1.72 |
| Bird | Parakeet | 1.55 | 82.45 | 7 | 25 | 14.34 |
| Fish | Clownfish | 2.78 | 88.11 | 8 | 10 | 5.02 |
| Cat | Bengal | 8.22 | 75.22 | 6 | 75 | 9.78 |
| Dog | Poodle | 10.11 | 85.33 | 9 | 110 | 25.27 |

This table demonstrates a **range of intrinsic values** for different pets at different ages and health levels, consistent with the formula.

---

### 5. Example Flows

#### 5.1 Purchasing New Pets

1. Trader A buys 2 Labradors from new supply at retail price.
2. Cash decreases, pets added to inventory, lifecycle metrics start ticking.

#### 5.2 Secondary Market Trade

1. Trader A lists a Poodle for sale at $Y.
2. Trader B places a bid of $Z > $Y.
3. Trader A accepts → trade executes immediately.
4. Notifications:
   - Trader A: "Bid accepted by Trader B for Poodle at $Z."
   - Trader B: "Your bid accepted by Trader A for Poodle at $Z."

#### 5.3 Bid Withdrawal

1. Trader C bids $W on a Bengal.
2. Trader C withdraws bid → cash released.
3. Trader A notified: "Bid withdrawn by Trader C for Bengal at $W."

#### 5.4 Valuation Update

1. Every minute, intrinsic value recalculated using ±5% variance.
2. All affected panels refresh automatically.

#### 5.5 Bid Being Outbid

1. Trader A lists Bulldog at $50.
2. Trader B bids $55 → active.
3. Trader C bids $60 → replaces B's bid, B's cash released.
4. Notifications:
   - Trader A: "New highest bid $60 from Trader C."
   - Trader B: "Your bid $55 outbid by Trader C."
   - Trader C: "Your bid $60 is currently highest."

#### 5.6 Trader Delisting a Pet

1. Trader A has Poodle listed with active bid $40 from Trader B.
2. Trader A withdraws listing → bid rejected, cash released.
3. Notification: Trader B: "Bid $40 withdrawn by Trader A (listing removed)."
4. Pet returned to Trader A inventory.

#### 5.7 Reviewing Intrinsic Value

1. Trader C views analysis for Cocker Spaniel listed by Trader B.
2. Analysis shows age, health, desirability, maintenance, intrinsic value.
3. Trader C decides on bid based on intrinsic value.

#### 5.8 Using Leaderboard

1. Trader A opens leaderboard:
   - Trader B: Portfolio $500
   - Trader C: Portfolio $450
   - Trader A: Portfolio $470
2. Trader A identifies which traders/pets to target for maximizing portfolio.

---

## Clarifying Questions & Answers

### 1. Trader Behavior & Controls

**Q1: Who controls the Traders?**
**A:** Each Trader is controlled by a human participant (human acts as Trader). The participant can act as all three Traders during the demo.

**Q2: Do Traders act simultaneously or turn-by-turn?**
**A:** Traders operate simultaneously, but since one participant is controlling all of them, actions happen one at a time in any order chosen by the participant.

**Q3: Does each Trader have a separate interface?**
**A:** Yes. Each Trader has its own window/panel, simulating how multiple people could trade at once.

**Q4: Can Traders see each other's inventory or cash?**
**A:** No. Each Trader sees only their own cash, locked cash (for active bids), and pets.

### 2. Market Mechanics & Trading Rules

**Q5: Can Traders buy multiple pets at once?**
**A:** Yes, both from the new supply and the market, as long as they have enough cash.

**Q6: Can multiple bids exist for the same pet?**
**A:** Only the highest bid counts. If a new higher bid comes in, it replaces the previous one and releases that bidder's locked cash.

**Q7: Can a Trader bid on their own pets?**
**A:** No — a Trader cannot buy their own pets.

**Q8: Can bids be higher or lower than the asking price?**
**A:** Yes, any bid is allowed. The seller chooses whether to accept or reject the bid.

**Q9: What happens if a bid is withdrawn?**
**A:** Locked cash is immediately released, and the seller is notified.

**Q10: Can pets be relisted for sale?**
**A:** Yes, but only after withdrawing the previous listing. Any active bids are automatically rejected when withdrawn.

**Q11: Can a pet be listed multiple times simultaneously?**
**A:** No. Each individual pet can have only one active listing, but a Trader can list multiple different pets at once.

**Q12: Are trades instantaneous?**
**A:** Yes. Once a seller accepts a bid, the transaction executes immediately and updates inventory and cash.

**Q13: Are there any cash or bid restrictions?**
**A:** Bids cannot exceed a Trader's available (unlocked) cash. Cash is locked for active bids and released when a bid is withdrawn or rejected.

### 3. Pets & Valuation

**Q14: Are pets unique or generic?**
**A:** Each pet is unique — its own age, health, and intrinsic value tracked individually.

**Q15: How is age handled?**
**A:** Age starts at 0 when purchased new and increases continuously, even if the pet is being traded.

**Q16: How is health handled?**
**A:** Health fluctuates ±5% at each valuation update.

**Q17: How is intrinsic value calculated?**
**A:** Same formula for all pets:

```
Intrinsic Value = Base Price × (Health / 100) × (Desirability / 10) × (1 - Age / Lifespan)
```

**Q18: Can expired pets be sold or bought?**
**A:** Yes. Pets remain in inventory at zero intrinsic value, but traders can still bid on them.

**Q19: What are the starting Base Prices for pets?**
**A:** Each breed has a fixed retail price (e.g., Labrador = $100, Beagle = $90, Goldfish = $5, etc.)

**Q20: Is the pet dictionary editable by participants?**
**A:** No. The dictionary is read-only.

### 4. UI / Views

**Q21: What should the market view show?**
**A:** Current listings, asking price, most recent trade price, and new supply count. Default order = newest listings first.

**Q22: What should the analysis view show?**
**A:** Full fundamentals for each pet — age, health, desirability, maintenance, intrinsic value — for Traders to make decisions.

**Q23: What does the leaderboard show?**
**A:** Total portfolio value (cash + locked cash + market value). Updates in real-time as trades and valuations change.

**Q24: What notifications are required?**
**A:** Bid received, accepted, rejected, withdrawn, outbid. Each includes pet, price, and counterparty.

### 5. System Behavior

**Q25: How often are valuations updated?**
**A:** Every minute (or configurable). Variance ±5% on health/desirability.

**Q26: What happens on UI refresh?**
**A:** If any valuation has changed or a trade occurs, all relevant panels **update immediately.**

**Q27: Can pets have multiple active bids?**
**A:** No. Only one active bid per pet.

**Q28: Are there limits on inventory or listings?**
**A:** No. Traders can hold unlimited pets as long as they have cash, and list as many pets as they own.

**Q29: How are transactions handled for multiple bids or relisted pets?**
**A:** Highest bid replaces previous bids. Relisting requires withdrawing first, which cancels active bids.

---

## UX / Experience Considerations left to Participant Decisions

**Notes for Participants:**

- Scoring may consider thoughtful design choices.
- The goal is to see participants **make intentional UX decisions** rather than follow a rigid template.

### 1. Market View Display

- How pets are **visually presented** (layout, card vs. table, icons, colors).
- Optional **sorting/filtering** (e.g., by type, price, age, health).
- Whether to highlight new listings, recently updated valuations, or expired pets.

### 2. Trader Panel / Inventory

- How inventory is **organized and displayed** (grouping, tabs, list vs. grid).
- How available cash, locked cash, and total portfolio value are shown.
- Whether to include **visual indicators for active bids**.

### 3. Analysis / Drill-Down View

- How the detailed pet fundamentals are presented (charts, tables, visual cues).
- Optional **highlighting of key metrics** (e.g., intrinsic value trends, age vs. lifespan).
- How easily a Trader can interpret information to decide on a bid.

### 4. Leaderboard

- How total portfolio values are shown (aggregate, per component, color-coded).
- Optional inclusion of visual cues for relative performance vs. other Traders.
- Placement and prominence of the leaderboard in the Trader's panel.

### 5. Notifications

- How alerts are displayed (pop-ups, banners, inline messages).
- Duration, visibility, or dismissal mechanics for notifications.
- Whether multiple notifications are grouped or stacked.

### 6. Bid / Trade Interaction

- How bidding is initiated and confirmed (modal, inline, drag-and-drop).
- How bids are visually distinguished (active, rejected, outbid).
- Optional UX cues for "locked cash" or unavailable funds.

### 7. Listing / Delisting Pets

- How sellers list pets for sale (form, drag-and-drop, quick-action buttons).
- How withdrawn or relisted pets are visually indicated.
- Optional prompts or confirmations for critical actions (accept/reject, withdrawal).

### 8. Valuation Updates

- How real-time updates (age, health, intrinsic value) are reflected in the UI.
- Optional visual cues for metric changes (animation, color changes, arrows).

### 9. Multiple Active Panels

- Whether participants **show all Trader panels at once** or allow toggling between Traders.
- Optional decision on **responsive layout for multiple simultaneous views**.

### 10. Optional UX Enhancements

- Any additional usability improvements that enhance clarity or reduce cognitive load (e.g., tooltips, hover info, color-coded risk indicators, highlighting expired pets).
