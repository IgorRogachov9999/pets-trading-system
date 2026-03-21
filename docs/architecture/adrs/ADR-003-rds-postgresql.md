# ADR-003: RDS PostgreSQL for Primary Database

## Status
Accepted

## Context
The trading system requires ACID transactions for financial operations (cash transfers, bid locking, trade execution). Data is highly relational (traders own pets, pets have listings, listings have bids). The system needs durable storage that survives restarts, supports concurrent access, and provides precise decimal arithmetic.

## Decision
Use **Amazon RDS PostgreSQL 16** with **Multi-AZ deployment**, accessed via **Dapper ORM** with **IAM authentication** (passwordless).

## Consequences
**Easier:**
- ACID transactions ensure atomic trade execution (pet + cash transfer in one commit)
- Relational model naturally represents the trading domain entities and relationships
- SERIALIZABLE isolation prevents race conditions on bid replacement
- `DECIMAL` type matches .NET `decimal` for precise monetary calculations
- Multi-AZ provides automatic failover for high availability
- IAM authentication eliminates database password management
- PostgreSQL advisory locks suitable for singleton Lifecycle Engine safety
- Rich indexing (partial indexes for active listings/bids)

**Harder:**
- Shared database between services creates coupling (documented as TD-001)
- Schema migrations must be coordinated across services
- Connection pooling required to avoid exceeding RDS connection limits
- Multi-AZ adds cost (~2x single instance)

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **DynamoDB** | No ACID transactions across items; complex for relational trading data; eventual consistency risks |
| **Aurora PostgreSQL** | Higher cost than RDS for hackathon scale; same feature set at this size |
| **Aurora Serverless v2** | Cost optimization benefits not relevant for demo-scale workload |
| **MongoDB** | No native multi-document transactions in early versions; weaker consistency guarantees |
| **SQLite** | No network access; single-writer limitation; no IAM auth; not suitable for multi-service |
