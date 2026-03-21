# arc42: 08 -- Cross-cutting Concepts

## 8.1 Authentication and Authorization

### Authentication Flow
1. User registers or logs in via Trading API Service, which proxies to Amazon Cognito
2. Cognito returns JWT tokens (access token, ID token, refresh token)
3. Frontend stores tokens in memory (not localStorage for security)
4. Every API request includes the access token in the `Authorization: Bearer <token>` header
5. API Gateway validates the JWT using a Cognito Authorizer before forwarding to backend

### Authorization Model
- **All API endpoints require authentication** (except register/login)
- **Resource-level authorization** enforced in the Trading API Service:
  - Traders can only view/modify their own data (inventory, cash, notifications)
  - Traders cannot bid on their own listings (BR-015)
  - Traders can only accept/reject bids on their own listings
  - Market View and Leaderboard are read-only shared views
- **IAM roles** for service-to-service communication (ECS task roles, Lambda execution roles)

### Security Controls

| Control | Implementation |
|---------|---------------|
| Password storage | Cognito handles hashing (SRP protocol, bcrypt) |
| Token expiry | Access token: 1 hour; Refresh token: 24 hours |
| Session invalidation | Cognito GlobalSignOut on logout |
| CORS | API Gateway configured for frontend domain only |
| HTTPS everywhere | CloudFront -> API Gateway -> ALB (TLS termination at ALB) |
| WAF | AWS Managed Rules on API Gateway |
| No hardcoded credentials | IAM roles for all AWS service access |
| Database auth | IAM authentication (passwordless) for RDS |

## 8.2 Data Consistency

### Transactional Boundaries
All trading operations that modify multiple entities (cash, inventory, bids, listings) execute within a **single PostgreSQL transaction** with **SERIALIZABLE** isolation level for critical operations:

| Operation | Transaction Scope | Isolation |
|-----------|------------------|-----------|
| Place bid | Lock cash + create bid + (optional: release outbid) | SERIALIZABLE |
| Accept bid | Transfer pet + transfer cash + close listing + create trade record | SERIALIZABLE |
| Withdraw listing | Deactivate listing + reject bid + release cash | READ COMMITTED |
| Lifecycle tick | Batch update all pets (age cache, health, desirability, intrinsic value) | READ COMMITTED |
| Supply purchase | Decrement supply + create pet + deduct cash | SERIALIZABLE |

### Formula Precision
- Intrinsic value is **calculated only on the backend** (single source of truth)
- Frontend **displays** the server-calculated value; never independently computes it
- All monetary values stored as `DECIMAL(10,2)` in PostgreSQL
- Rounding: HALF_EVEN (banker's rounding) to 2 decimal places
- Maximum acceptable divergence between any two views: $0.01

### Pet Age Precision
- Age is derived from `(NOW() - created_at)` in years (ADR-016)
- The `pets.age` column is a cache, refreshed each lifecycle tick
- Between ticks, the cached age may be up to 60 seconds stale (acceptable for display)
- `is_expired` is derived: `age >= lifespan` (also refreshed each tick)

### Portfolio Value Consistency
- `portfolioValue = availableCash + lockedCash + SUM(intrinsicValue of owned pets)`
- Calculated from the same database query whether displayed on Trader Panel, Account Page, or Leaderboard
- Updates atomically after trades (within the same transaction)
- Updates after lifecycle ticks (tick writes new values; next poll reflects them)

## 8.3 Structured Logging

### Log Format
All services emit structured JSON logs to CloudWatch Logs.

```json
{
  "timestamp": "2026-03-20T14:30:00.123Z",
  "level": "INFO",
  "service": "trading-api",
  "traceId": "1-abc123-def456",
  "correlationId": "req-789xyz",
  "traderId": "trader-uuid",
  "action": "bid.placed",
  "data": {
    "listingId": "listing-uuid",
    "amount": 95.00,
    "breed": "Poodle"
  },
  "durationMs": 45
}
```

### Log Levels

| Level | Usage |
|-------|-------|
| ERROR | Unrecoverable failures, transaction rollbacks, external service failures |
| WARN | Validation rejections, rate limiting, degraded performance |
| INFO | Business events: trades, bids, purchases, tick completions, login/logout |
| DEBUG | SQL queries, request/response payloads (dev only) |

### Log Groups

| Log Group | Source |
|-----------|--------|
| `/ecs/trading-api` | Trading API Service |
| `/lambda/lifecycle-engine` | Lifecycle Lambda |
| `/apigateway/pets-trading-rest` | API Gateway REST access logs |
| `/apigateway/pets-trading-ws` | API Gateway WebSocket logs |

### Correlation

- Every HTTP request generates a `correlationId` (UUID) in middleware
- The `correlationId` propagates through all downstream calls
- X-Ray `traceId` is also logged for cross-service correlation
- WebSocket messages include `correlationId` for client-side debugging

## 8.4 Error Handling

### API Error Response Format

```json
{
  "error": {
    "code": "INSUFFICIENT_CASH",
    "message": "Available cash ($80.00) is insufficient for this purchase ($110.00)",
    "details": {
      "availableCash": 80.00,
      "requiredAmount": 110.00
    }
  }
}
```

### Error Categories

| HTTP Status | Error Code | Scenario |
|-------------|-----------|----------|
| 400 | `INVALID_INPUT` | Missing/malformed request fields |
| 400 | `INSUFFICIENT_CASH` | Cash < required amount |
| 400 | `SUPPLY_EXHAUSTED` | Breed supply count = 0 |
| 400 | `SELF_BID_FORBIDDEN` | Trader bidding on own listing |
| 400 | `BID_TOO_LOW` | Bid <= current highest bid |
| 400 | `ALREADY_LISTED` | Pet already has active listing |
| 400 | `INVALID_ASKING_PRICE` | Asking price <= 0 |
| 401 | `UNAUTHORIZED` | Missing/invalid JWT |
| 403 | `FORBIDDEN` | Action not allowed for this trader |
| 404 | `NOT_FOUND` | Resource does not exist |
| 409 | `CONFLICT` | Concurrent modification detected |
| 429 | `RATE_LIMITED` | Too many requests |
| 500 | `INTERNAL_ERROR` | Unhandled server error |

### Retry Strategy
- Backend retries: None (transactions are atomic; failures roll back)
- Frontend retries: Exponential backoff for 429 and 503 responses (max 3 retries)
- WebSocket reconnection: Exponential backoff starting at 1s, max 30s
- Lifecycle Lambda: No retry (EventBridge Scheduler invokes again in 60s; idempotent)

## 8.5 Real-Time Communication

### Hybrid Architecture (ADR-017)

The system uses a **hybrid push/pull** real-time architecture:

#### REST Polling (data refresh)
- Frontend polls the Trading API every **5 seconds** for all data views:
  - Market View (active listings, asking prices, recent trade prices, supply counts)
  - Leaderboard (all trader portfolio values)
  - Trader Panel (portfolio, available cash, locked cash, inventory)
  - Analysis / Drill-Down (pet age, health, desirability, intrinsic value, expired status)
- Lifecycle tick results are picked up on the next poll (within 0-5 seconds of tick completion)

#### WebSocket (trade notifications only)
- WebSocket is used exclusively for **6 lightweight trade notification events**:

| Event | Recipients | Payload |
|-------|-----------|---------|
| `bid.received` | Listing owner | Bid amount, pet, bidder info |
| `bid.accepted` | Bidder | Pet, accepted amount |
| `bid.rejected` | Bidder | Pet, rejected amount |
| `outbid` | Previous bidder | Original amount, new amount, cash released |
| `trade.completed` | Both buyer and seller | Trade details, pet, price, counterparty |
| `listing.withdrawn` | Active bidder (if any) | Pet, bid amount, cash released |

#### Notification Delivery
- The **Trading API Service** pushes WebSocket notifications **directly** after the trade transaction commits
- No intermediate EventBridge hop or Notification Lambda
- Trading API reads the target trader's `connectionId` from DynamoDB and calls the API Gateway Management API inline
- If DynamoDB read or WebSocket push fails, the notification is still persisted in PostgreSQL (trader sees it on next poll)

#### Frontend Pattern
- On receiving any WebSocket trade event, the frontend immediately **invalidates and refetches** affected REST queries (market, portfolio, leaderboard)
- This gives push-like responsiveness for trades while keeping the data fetch path simple and consistent

### Connection Lifecycle

| Event | Action |
|-------|--------|
| `$connect` | Store connection ID + trader ID in DynamoDB |
| `$disconnect` | Remove connection from DynamoDB |
| Stale connection | Trading API catches `GoneException`, removes from DynamoDB |
| Client reconnect | REST polling continues uninterrupted; re-establish WebSocket for trade notifications |

## 8.6 Configuration Management

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TICK_INTERVAL_SECONDS` | `60` | Lifecycle tick interval (EventBridge Scheduler rate) |
| `POLL_INTERVAL_SECONDS` | `5` | Frontend REST polling interval |
| `ASPNETCORE_ENVIRONMENT` | `Production` | Runtime environment |
| `AWS_REGION` | `us-east-1` | AWS region |
| `COGNITO_USER_POOL_ID` | (from Secrets Manager) | Cognito user pool |
| `COGNITO_CLIENT_ID` | (from Secrets Manager) | Cognito app client |
| `DB_CONNECTION_STRING` | (from Secrets Manager) | PostgreSQL connection |
| `STARTING_CASH` | `150` | New trader starting balance |
| `INITIAL_SUPPLY_PER_BREED` | `3` | Initial supply units |
| `WEBSOCKET_CONNECTIONS_TABLE` | `pts-websocket-connections` | DynamoDB table for WebSocket connections |
| `WEBSOCKET_API_ENDPOINT` | (from Secrets Manager) | API Gateway WebSocket endpoint |

### Secrets (AWS Secrets Manager)

| Secret | Contents |
|--------|----------|
| `pts/database/connection` | Host, port, database name (IAM auth, no password) |
| `pts/cognito/config` | User pool ID, app client ID, region |
| `pts/api-gateway/websocket-url` | WebSocket API endpoint for Management API calls |
