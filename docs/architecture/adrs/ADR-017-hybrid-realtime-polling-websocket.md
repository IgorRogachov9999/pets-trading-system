# ADR-017: Hybrid Real-Time Architecture -- REST Polling + WebSocket Trade Notifications

## Status
Accepted

## Context
The original design used WebSocket push for all real-time updates: lifecycle tick results (every 60s to all clients), trade notifications (to affected parties), and supply changes. This required a dedicated Notification Lambda that received events via EventBridge and fanned out messages to all connected WebSocket clients via the API Gateway Management API.

Analysis revealed several issues with full push:
- **Tick fan-out cost**: Broadcasting updated pet values to all connected clients every 60 seconds requires the Notification Lambda to iterate over every connection in DynamoDB and make an API Gateway Management API call per connection. For N connected traders, this is N API calls per tick.
- **Unnecessary complexity**: The Notification Lambda, EventBridge rules routing `tick.completed`, and the fan-out logic add infrastructure and code that must be maintained.
- **Payload size**: Pushing all updated pet values (up to 60 pets with multiple fields) over WebSocket every 60 seconds is wasteful when the frontend can fetch only what it needs via REST.
- **Trade notifications are different**: Trade events (bid received, accepted, rejected, outbid, trade completed) are low-frequency, targeted to specific traders, and time-sensitive. These genuinely benefit from push delivery.

## Decision
Adopt a **hybrid real-time architecture**:

### REST Polling (data refresh)
The frontend polls the Trading API Service via REST every **5 seconds** for:
- Market View (active listings, asking prices, recent trade prices, supply counts)
- Leaderboard (all trader portfolio values)
- Trader Panel (portfolio, available cash, locked cash, inventory)
- Analysis / Drill-Down (pet age, health, desirability, intrinsic value, expired status)

### WebSocket (trade notifications only)
WebSocket is used exclusively for **6 lightweight trade notification events**:
- `bid.received` -- sent to listing owner when someone bids on their pet
- `bid.accepted` -- sent to bidder when their bid is accepted
- `bid.rejected` -- sent to bidder when their bid is rejected
- `outbid` -- sent to previous bidder when they are outbid
- `trade.completed` -- sent to both buyer and seller
- `listing.withdrawn` -- sent to active bidder (if any) when listing is withdrawn

### Notification delivery
The **Trading Lambda pushes WebSocket notifications directly** after the trade transaction commits -- no EventBridge hop, no separate Notification Lambda. The Trading API Service reads the target trader's connection ID from DynamoDB and calls the API Gateway Management API inline.

### Frontend pattern
On receiving any WebSocket trade event, the frontend immediately **invalidates and refetches** affected REST queries (market view, portfolio, leaderboard). This gives push-like responsiveness for trades while keeping the data fetch path simple and consistent.

### Removed components
- **Notification Lambda** -- removed entirely
- **EventBridge rule** routing `tick.completed` to Notification Lambda -- removed
- The Lifecycle Lambda updates PostgreSQL and exits; no EventBridge publish needed

### Retained components
- **DynamoDB connection tracking** (traderId -> connectionId) -- still needed for targeted WebSocket trade notifications, but much simpler usage (read only on trade events, not every 60s tick)

## Consequences
**Easier:**
- Eliminates Notification Lambda and its EventBridge wiring -- fewer moving parts
- No tick fan-out latency or cost (N API calls per tick eliminated)
- Trading API Service owns the full notification flow end-to-end -- easier to debug
- Polling is inherently resilient: if a WebSocket connection drops, data still refreshes every 5 seconds
- Simpler DynamoDB usage: connection table is read only during trade events

**Harder:**
- Polling introduces up to 5 seconds of data staleness for non-trade updates (tick results, supply changes)
- Slightly higher API Gateway + ALB request volume from polling (mitigated by lightweight JSON responses and HTTP caching headers)
- Frontend must manage polling intervals and query invalidation logic
- Poll interval (5s) and tick interval (60s) are independent -- a pet value change from a tick will be visible to the frontend within 0-5 seconds after the tick completes

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Full WebSocket push (original)** | Tick fan-out to all connections is expensive and complex; requires dedicated Notification Lambda; payload bloat for broadcasting all pet values |
| **Server-Sent Events (SSE)** | Uni-directional only; no native API Gateway support; still requires fan-out infrastructure |
| **Full polling only (no WebSocket)** | Trade notifications are time-sensitive; 5s polling delay for "your bid was accepted" is a poor user experience |
| **AppSync Subscriptions** | Adds GraphQL layer; team prefers REST; overkill for 6 event types |
