# ADR Reference — Architecture Decision Records

## ADR Format

Every architectural decision that is hard to reverse, affects multiple teams, or involves a significant trade-off deserves an ADR. This project already has ADR-001 through ADR-017 in `docs/architecture/adrs/`. New decisions follow the same format.

```markdown
# ADR-{NNN}: {Title}

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-XXX]

## Context
Describe the situation, constraints, and forces at play.
What problem are we solving? What are the hard requirements?

## Decision
State the decision clearly and concisely.
What are we going to do?

## Consequences

### Positive
- Benefit 1
- Benefit 2

### Negative
- Drawback 1
- Drawback 2

### Neutral
- Side effect that is neither good nor bad

## Alternatives Considered
What else was evaluated and why was it rejected?

## References
- Link to relevant documentation or discussion
```

---

## Naming Convention

```
docs/architecture/adrs/
├── ADR-001-dotnet-backend.md
├── ADR-002-ecs-fargate.md
├── ...
└── ADR-017-hybrid-realtime.md
```

Use zero-padded three-digit numbers. Title should be a short noun phrase describing the decision, not the outcome.

---

## Example: Technology Selection ADR

```markdown
# ADR-003: PostgreSQL as Primary Database

## Status
Accepted

## Context
We need a database for the Pets Trading System that:
- Handles financial transactions with strong ACID guarantees
- Supports complex queries across traders, listings, bids, and trades
- Fits within the hackathon team's existing knowledge
- Works well with Dapper (micro-ORM) on .NET 10

## Decision
Use PostgreSQL 16 on AWS RDS Multi-AZ as the sole database.
All financial data (cash balances, locked amounts, trade records) lives here.

## Consequences

### Positive
- Full ACID compliance for bid/trade atomic operations
- Rich SQL feature set (window functions, CTEs, JSONB)
- Well-understood by the team; strong .NET/Npgsql ecosystem
- RDS Multi-AZ gives automatic failover < 60 s

### Negative
- Vertical scaling has limits (addressed with read replicas if needed)
- Multi-AZ adds ~2× RDS cost vs single-AZ

### Neutral
- Requires Flyway or manual SQL migration files rather than EF Core migrations

## Alternatives Considered

**DynamoDB**
- Rejected: Financial data requires ACID transactions; DynamoDB transactions are limited and complex to reason about for bid replacement.

**MySQL**
- Rejected: Less rich feature set for window functions and CTEs needed for leaderboard/analytics queries.

## References
- ADR-001 (.NET 10 backend)
- docs/architecture/05-building-block-view.md (schema)
```

---

## When to Write an ADR

Write an ADR when:
- The decision is **hard to reverse** (database choice, auth provider, message bus)
- It **affects multiple components** or teams
- There are **meaningful trade-offs** between alternatives
- Future engineers will ask "why did we do it this way?"

Skip an ADR for:
- Tactical implementation choices (naming conventions, method signatures)
- Decisions that are trivially reversible
- Choices with no meaningful alternatives

---

## Quick Reference

| Section | Key Question |
|---|---|
| Context | What problem? What constraints? |
| Decision | What are we doing? |
| Consequences | What are the trade-offs? |
| Alternatives | What else was considered and why rejected? |
