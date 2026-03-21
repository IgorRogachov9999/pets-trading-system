# ADR-007: WebSocket via API Gateway for Real-Time Updates

## Status
Accepted (Updated -- scope narrowed by ADR-017)

## Context
The system requires real-time UI updates for trade events. Traders need immediate notification when bids are placed, accepted, rejected, or when they are outbid.

> **Update (2026-03-21):** The scope of WebSocket usage has been significantly narrowed by [ADR-017](./ADR-017-hybrid-realtime-polling-websocket.md). WebSocket is now used **only for trade notification events** (6 event types), not for broadcasting tick data or full state updates. Lifecycle tick data and market views are served via REST polling (5-second interval). The Notification Lambda has been removed; the Trading API Service pushes WebSocket messages directly.

## Decision
Use **API Gateway WebSocket API** for persistent bi-directional connections, with **DynamoDB** for connection tracking (traderId -> connectionId mapping).

WebSocket carries only the following **6 lightweight trade notification events**:
- `bid.received` -- sent to listing owner
- `bid.accepted` -- sent to bidder
- `bid.rejected` -- sent to bidder
- `outbid` -- sent to previous bidder
- `trade.completed` -- sent to both buyer and seller
- `listing.withdrawn` -- sent to active bidder

The **Trading API Service** pushes these notifications directly via the API Gateway Management API after trade transactions commit -- no intermediate Lambda or EventBridge hop.

## Consequences
**Easier:**
- Managed WebSocket infrastructure -- no custom WebSocket server to maintain
- API Gateway handles TLS termination, connection keepalive, and scaling
- Connection-level routing via `$connect`, `$disconnect`, `$default` routes
- Targeted push to specific connections for trade notifications (low volume, high value)
- DynamoDB provides fast lookups for connection-to-trader mapping
- No tick fan-out cost -- WebSocket is not used for broadcasting pet value updates
- Trading API Service owns the full notification path end-to-end (simpler debugging)

**Harder:**
- Connection tracking requires DynamoDB table (additional service)
- Stale connection cleanup needed (handle `GoneException`)
- Maximum 500 concurrent connections per route (default; sufficient for hackathon)
- Client must handle reconnection with exponential backoff
- Trading API Service has an additional dependency on API Gateway Management API and DynamoDB

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Server-Sent Events (SSE)** | Uni-directional only; harder to implement per-trader targeting; no native API Gateway support |
| **SignalR on ECS** | Requires sticky sessions or Redis backplane; adds complexity; self-managed WebSocket server |
| **AWS AppSync Subscriptions** | GraphQL subscription model adds complexity; team prefers REST + WebSocket |
| **Full polling only (no WebSocket)** | Trade notifications are time-sensitive; 5s polling delay for "your bid was accepted" is a poor UX |
| **AWS IoT Core MQTT** | Overkill; designed for IoT devices; pricing model not aligned |
| **Full WebSocket push for all data** | Tick fan-out to all connections is expensive; requires dedicated Notification Lambda; see ADR-017 |
