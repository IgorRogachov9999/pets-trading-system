# Architecture Patterns Reference

## Pattern Comparison

| Pattern | Best For | Team Size | Trade-offs |
|---|---|---|---|
| **Monolith** | Simple domain, small team | 1–10 | Simple deploy; hard to scale parts |
| **Modular Monolith** | Growing complexity | 5–20 | Module boundaries; still single deploy |
| **Microservices** | Complex domain, large org | 20+ | Independent scale; operational overhead |
| **Serverless** | Variable load, event-driven | Any | Auto-scale; cold starts, vendor lock |
| **Event-Driven** | Async processing, loose coupling | 10+ | Audit trail; debugging complexity |
| **CQRS** | Read-heavy, complex queries | 10+ | Optimised reads; eventual consistency |

## This Project: Modular Monolith → Selective Serverless

The Pets Trading System uses a **Modular Monolith** for the Trading API (single ECS Fargate service with clear bounded-context boundaries) with **Selective Serverless** for the Lifecycle Engine (Lambda). This is the right call at hackathon scale — avoids microservices operational overhead while keeping domain boundaries clean.

---

## Monolith

```
┌───────────────────────────────────┐
│           Trading API             │
│  ┌───────┐  ┌─────────┐  ┌─────┐ │
│  │Traders│  │Listings │  │Pets │ │
│  └───────┘  └─────────┘  └─────┘ │
│              ↕                    │
│          PostgreSQL               │
└───────────────────────────────────┘
```

**Use when**: Small team, simple domain, rapid iteration.
**Pros**: Simple deployment, easy debugging, no network latency between components.
**Cons**: Hard to scale parts independently; large test suite as domain grows.

---

## Microservices

```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Traders  │  │ Listings │  │   Pets   │
│ Service  │  │ Service  │  │ Service  │
└────┬─────┘  └────┬─────┘  └────┬─────┘
     │             │             │
┌────▼────┐  ┌────▼────┐  ┌────▼────┐
│  DB     │  │  DB     │  │  DB     │
└─────────┘  └─────────┘  └─────────┘
```

**Use when**: Large teams (20+), services with very different scaling needs, polyglot requirements.
**Avoid for this project**: The Trading API's financial operations require cross-entity ACID transactions — splitting into microservices would force distributed transactions (sagas), adding significant complexity without benefit at this scale.

---

## Event-Driven

```
┌──────────┐   ┌───────────────┐   ┌──────────┐
│ Producer │──▶│  Message Bus  │──▶│ Consumer │
└──────────┘   │ (EventBridge) │   └──────────┘
               └───────────────┘
```

**Use when**: Async processing, loose coupling, audit trails.
**In this project**: EventBridge Scheduler triggers the Lifecycle Lambda every 60 s — the only event-driven component. Trade WebSocket notifications are pushed synchronously by the Trading API after commit, not via a message bus.

---

## CQRS (Command Query Responsibility Segregation)

```
┌──────────┐      ┌──────────────┐
│ Commands │─────▶│  Write Model │──┐
└──────────┘      └──────────────┘  │ Events
                                    ▼
┌──────────┐      ┌──────────────┐
│ Queries  │◀─────│  Read Model  │◀─┘
└──────────┘      └──────────────┘
```

**Use when**: Read/write ratio heavily skewed, complex read queries, event sourcing.
**In this project**: Light CQRS via MediatR (separate `Commands/` and `Queries/` in the Application layer) without full event sourcing. Commands mutate state; queries use optimised Dapper read models. See `clean-architecture.md` for folder structure.

---

## Serverless

**Use when**: Variable load, event-driven triggers, infrequent background work.
**In this project**: Lifecycle Lambda runs once per minute via EventBridge Scheduler. It's stateless, deterministic, and doesn't serve user requests — ideal serverless fit.

---

## Quick Reference

| Requirement | Recommended |
|---|---|
| Simple CRUD, small team | Monolith |
| Growing startup, clear domains | Modular Monolith |
| Enterprise, independent scaling | Microservices |
| Batch / scheduled background work | Serverless Lambda |
| Async notifications | Event-Driven (EventBridge / SQS) |
| Read-heavy with complex queries | CQRS with separate read models |
