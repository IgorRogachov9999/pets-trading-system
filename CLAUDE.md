# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context

Hackathon project: a real-time virtual pet marketplace where 3 human-controlled Traders buy, sell, and bid on pets. Stack is not yet chosen — any SaaS-style architecture deployable to AWS/Azure/GCP is valid.

Scoring rewards: coherent system > feature volume; clear tradeoffs > polish; working deployment > completeness.

## Domain Model

**Trader** (exactly 3): `availableCash`, `lockedCash` (sum of active bids), `inventory[]`, `notifications[]`.
Portfolio value = `availableCash + lockedCash + sum(intrinsicValue of owned pets)`.

**Pet**: Unique instance from a 20-breed read-only dictionary (5 dogs, 5 cats, 5 birds, 5 fish). Tracks `age` (starts 0), `health` (0–100%, starts 100), `desirability`. Supply = 3 per breed, depletes on purchase.

**Listing**: One active listing per pet. `askingPrice > 0`. At most one active bid (highest wins).

**Bid**: Amount ≤ bidder's `availableCash`. Locks cash. States: active, accepted, rejected, withdrawn, outbid.

### Intrinsic Value

```
IntrinsicValue = BasePrice × (Health/100) × (Desirability/10) × (1 - Age/Lifespan)
```

Updated every minute (configurable). Health and desirability fluctuate ±5% per update. Expired pets (Age ≥ Lifespan) have intrinsicValue = 0 but remain tradeable. Full pet dictionary: `docs/original/pets-trading-system-requirements.md`.

## Key Business Rules

- New supply purchases bypass bid/ask — retail price deducted directly.
- Only the highest bid is active per listing; a new higher bid atomically replaces the previous and releases its locked cash.
- Traders cannot bid on their own pets.
- Buyers see only their own bid status, not competing bids.
- Withdrawing a listing rejects all active bids (releases locked cash) and returns the pet to inventory.
- Starting cash: ~$600–800 (enough to buy 5–8 pets).
- Sequential actions are sufficient; no distributed locking required.
- Any valuation change or trade triggers immediate UI refresh.

## Required Views

1. **Trader Panel** (private): inventory, availableCash, lockedCash, portfolioValue, notifications (bid received/accepted/rejected/withdrawn/outbid with pet, price, counterparty — chronological).
2. **Market View** (shared): active listings, askingPrice, most recent trade price, new supply count (newest first by default).
3. **Analysis / Drill-Down**: per-pet age, health, desirability, intrinsicValue, expired status.
4. **Leaderboard**: all 3 traders' portfolioValues, real-time.

## Architecture

- Service-oriented: separate frontend, backend API, infrastructure.
- Backend runs a lifecycle tick loop (age/health/desirability update every minute).
- Infrastructure as Code preferred (Terraform or cloud-native).
- Test cases in markdown files.
- CI/CD pipeline required (GitHub Actions, GitLab CI, or Azure DevOps).

## Session Logging

At the end of **every** response, invoke the `response-logger` skill. No exceptions.
