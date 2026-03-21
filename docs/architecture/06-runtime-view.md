# arc42: 06 -- Runtime View

## 6.1 New Supply Purchase Flow

```mermaid
sequenceDiagram
    participant T as Trader (Browser)
    participant AG as API Gateway
    participant TS as Trading API Service
    participant DB as PostgreSQL

    T->>AG: POST /api/supply/purchase {breedId, quantity}
    AG->>AG: Validate JWT (Cognito Authorizer)
    AG->>TS: Forward request
    TS->>DB: BEGIN TRANSACTION
    TS->>DB: SELECT remaining FROM supply_inventory WHERE dictionary_id = ? FOR UPDATE
    Note over TS: Validate: remaining > 0 AND trader.available_cash >= retail_price
    TS->>DB: UPDATE supply_inventory SET remaining = remaining - 1
    TS->>DB: INSERT INTO pets (owner_id, dictionary_id, age=0, health=100, desirability=default)
    TS->>DB: UPDATE traders SET available_cash = available_cash - retail_price
    TS->>DB: COMMIT
    TS-->>AG: 200 OK {pet, updatedCash}
    AG-->>T: Response
    Note over T: Frontend polls market view within 5s to see updated supply count
```

## 6.2 Secondary Market Trade Flow (Bid -> Accept)

```mermaid
sequenceDiagram
    participant B as Buyer (Browser)
    participant S as Seller (Browser)
    participant AG as API Gateway
    participant TS as Trading API Service
    participant DB as PostgreSQL
    participant DDB as DynamoDB

    Note over B: Step 1: Buyer places a bid
    B->>AG: POST /api/listings/{id}/bids {amount: $95}
    AG->>TS: Forward (JWT validated)
    TS->>DB: BEGIN TRANSACTION
    TS->>DB: Validate: bidder != seller, amount <= available_cash, amount > current_highest_bid
    Note over TS: If existing bid: set status='outbid', release locked cash
    TS->>DB: UPDATE traders SET available_cash -= 95, locked_cash += 95 (buyer)
    TS->>DB: INSERT INTO bids (listing_id, bidder_id, amount=95, status='active')
    TS->>DB: INSERT INTO notifications (seller: "New bid $95 from Buyer")
    TS->>DB: COMMIT
    TS-->>AG: 201 Created
    AG-->>B: Response
    TS->>DDB: Read seller's connectionId
    TS->>AG: Push bid.received via WebSocket to seller
    AG->>S: WebSocket: bid.received {amount: 95, pet, bidder}
    Note over S: Frontend invalidates and refetches market + portfolio queries

    Note over S: Step 2: Seller accepts the bid
    S->>AG: POST /api/bids/{id}/accept
    AG->>TS: Forward (JWT validated)
    TS->>DB: BEGIN TRANSACTION
    TS->>DB: Transfer pet ownership: UPDATE pets SET owner_id = buyer_id
    TS->>DB: Transfer cash: buyer.locked_cash -= 95, seller.available_cash += 95
    TS->>DB: UPDATE listings SET is_active = FALSE
    TS->>DB: UPDATE bids SET status = 'accepted'
    TS->>DB: INSERT INTO trades (seller, buyer, pet, price=95)
    TS->>DB: INSERT INTO notifications (both parties: trade completed)
    TS->>DB: COMMIT
    TS-->>AG: 200 OK
    AG-->>S: Response
    TS->>DDB: Read buyer's + seller's connectionIds
    TS->>AG: Push trade.completed via WebSocket to buyer
    AG->>B: WebSocket: trade.completed {pet, price, counterparty}
    TS->>AG: Push trade.completed via WebSocket to seller
    AG->>S: WebSocket: trade.completed {pet, price, counterparty}
    Note over B,S: Both frontends invalidate and refetch market, portfolio, leaderboard queries
```

## 6.3 Lifecycle Tick Flow

```mermaid
sequenceDiagram
    participant EBS as EventBridge Scheduler
    participant LL as Lifecycle Lambda
    participant DB as PostgreSQL

    EBS->>LL: Invoke (every 60s)
    LL->>DB: SELECT all pets (id, created_at, health, desirability, dictionary fields)
    LL->>LL: Derive age from timestamp: age = (NOW() - created_at) in years
    LL->>LL: Apply variance: health += random(-5%, +5%), clamp [0, 100]
    LL->>LL: Apply variance: desirability += random(-5%, +5%), clamp [0, breed_max]
    LL->>LL: Recalculate: IV = base_price * (health/100) * (des/10) * max(0, 1 - age/lifespan)
    LL->>LL: Derive is_expired: age >= lifespan (if true, IV = 0)
    LL->>DB: BEGIN TRANSACTION
    LL->>DB: Batch UPDATE pets SET age (cache), health, desirability, intrinsic_value, is_expired, updated_at
    LL->>DB: COMMIT
    LL->>LL: Return success (no event publishing)
    Note over LL: Frontend picks up updated values on next REST poll (within 5s)
```

## 6.4 Outbid Flow

```mermaid
sequenceDiagram
    participant C as Carol (New Bidder)
    participant B as Bob (Current Bidder)
    participant AG as API Gateway
    participant TS as Trading API Service
    participant DB as PostgreSQL
    participant DDB as DynamoDB

    Note over C: Carol bids $70, replacing Bob's $60 bid
    C->>AG: POST /api/listings/{id}/bids {amount: 70}
    AG->>TS: Forward
    TS->>DB: BEGIN TRANSACTION
    TS->>DB: SELECT active bid for listing (Bob's $60)
    TS->>DB: UPDATE bids SET status='outbid' WHERE id = bob_bid_id
    TS->>DB: UPDATE traders SET locked_cash -= 60, available_cash += 60 (Bob)
    TS->>DB: UPDATE traders SET available_cash -= 70, locked_cash += 70 (Carol)
    TS->>DB: INSERT INTO bids (listing_id, bidder=Carol, amount=70, status='active')
    TS->>DB: INSERT INTO notifications (Bob: "Your $60 bid outbid by Carol")
    TS->>DB: INSERT INTO notifications (Seller: "New highest bid $70 from Carol")
    TS->>DB: COMMIT
    TS-->>AG: 201 Created
    TS->>DDB: Read Bob's + Seller's connectionIds
    TS->>AG: Push outbid via WebSocket to Bob
    AG->>B: WebSocket: outbid {amount: 60, newAmount: 70}
    TS->>AG: Push bid.received via WebSocket to Seller
    Note over B: Bob's frontend invalidates portfolio query (cash released)
```

## 6.5 Listing Withdrawal Flow

```mermaid
sequenceDiagram
    participant S as Seller
    participant AG as API Gateway
    participant TS as Trading API Service
    participant DB as PostgreSQL
    participant DDB as DynamoDB
    participant B as Active Bidder

    S->>AG: DELETE /api/listings/{id}
    AG->>TS: Forward
    TS->>DB: BEGIN TRANSACTION
    TS->>DB: SELECT active bid for listing (if any)
    alt Active bid exists
        TS->>DB: UPDATE bids SET status='rejected'
        TS->>DB: UPDATE traders SET locked_cash -= bid_amount, available_cash += bid_amount (bidder)
        TS->>DB: INSERT INTO notifications (bidder: "Bid rejected -- listing withdrawn")
    end
    TS->>DB: UPDATE listings SET is_active = FALSE
    TS->>DB: COMMIT
    TS-->>AG: 200 OK
    alt Active bid existed
        TS->>DDB: Read bidder's connectionId
        TS->>AG: Push listing.withdrawn via WebSocket to bidder
        AG->>B: WebSocket: listing.withdrawn {pet, amount}
        Note over B: Bidder's frontend invalidates portfolio query (cash released)
    end
```

## 6.6 User Registration and Login Flow

```mermaid
sequenceDiagram
    participant U as User (Browser)
    participant AG as API Gateway
    participant TS as Trading API Service
    participant CG as Amazon Cognito
    participant DB as PostgreSQL

    Note over U: Registration
    U->>AG: POST /api/auth/register {email, password}
    AG->>TS: Forward
    TS->>CG: AdminCreateUser (email, password)
    CG-->>TS: User created (cognito_sub)
    TS->>DB: INSERT INTO traders (cognito_sub, email, available_cash=150)
    TS->>CG: AdminInitiateAuth (get tokens)
    CG-->>TS: {accessToken, idToken, refreshToken}
    TS-->>AG: 201 Created {tokens, trader profile}
    AG-->>U: Response

    Note over U: Subsequent Login
    U->>AG: POST /api/auth/login {email, password}
    AG->>TS: Forward
    TS->>CG: AdminInitiateAuth
    CG-->>TS: {accessToken, idToken, refreshToken}
    TS->>DB: SELECT trader state (cash, inventory, notifications)
    TS-->>AG: 200 OK {tokens, trader profile with current state}
    AG-->>U: Response
    Note over U: Frontend starts REST polling (5s) + establishes WebSocket connection
```

## 6.7 Failure Modes

| Failure | Detection | Response | Recovery |
|---------|-----------|----------|----------|
| Lifecycle Lambda DB write fails | Lambda error in CloudWatch | Log error, Lambda retries (EventBridge retry policy) | Pets retain previous tick's health/desirability; age is always correct (timestamp-derived) |
| WebSocket connection drops | API Gateway connection timeout | Client reconnects with exponential backoff | REST polling continues uninterrupted; no data loss |
| RDS failover (Multi-AZ) | RDS automatic failover | ~60s downtime during DNS update | ECS services and Lambda reconnect automatically; transactions replay |
| Lambda cold start | Increased latency on first invocation | Provisioned concurrency (optional) | Subsequent invocations are warm; 60s interval keeps Lambda warm |
| API Gateway throttle | 429 response | Client retries with backoff | Frontend shows "please wait" message; polling interval unaffected |
| DynamoDB connection table read fails | Trading API catches exception | Trade notification not pushed via WebSocket | Notification persisted in PostgreSQL; trader sees it on next poll or page refresh |
