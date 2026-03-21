# API Design Reference

## RESTful Resource-Oriented Design

Use nouns for resources, HTTP verbs for actions. Never put verbs in URIs.

| Wrong | Correct |
|---|---|
| `POST /createListing` | `POST /v1/listings` |
| `GET /getTraderInventory` | `GET /v1/traders/{id}/inventory` |
| `POST /withdrawListing` | `DELETE /v1/listings/{id}` |
| `POST /placeBid` | `POST /v1/listings/{id}/bids` |

### Resource Hierarchy for This Project

```
GET    /v1/traders/{id}                    # Trader profile + portfolio
GET    /v1/traders/{id}/inventory          # Owned pets
GET    /v1/traders/{id}/notifications      # Bid received/accepted/rejected/withdrawn/outbid
GET    /v1/traders                         # Leaderboard (portfolioValues)

GET    /v1/listings                        # Market view (active listings)
POST   /v1/listings                        # Create listing
GET    /v1/listings/{id}                   # Single listing detail
DELETE /v1/listings/{id}                   # Withdraw listing

POST   /v1/listings/{id}/bids              # Place or replace bid
DELETE /v1/listings/{id}/bids/active       # Withdraw own bid
POST   /v1/listings/{id}/accept-bid        # Seller accepts active bid

GET    /v1/supply                          # Available new-supply pets
POST   /v1/supply/purchase                 # Buy from new supply (bypasses bid/ask)

GET    /v1/pets/{id}                       # Pet details (age, health, desirability, intrinsicValue)
```

---

## OpenAPI 3.1 Specification

Write the OpenAPI spec **before** implementing. Key sections:

```yaml
openapi: "3.1.0"
info:
  title: Pets Trading System API
  version: "1.0.0"
servers:
  - url: https://api.pettrading.example.com/v1

components:
  securitySchemes:
    CognitoJWT:
      type: http
      scheme: bearer
      bearerFormat: JWT

  schemas:
    Problem:
      type: object
      properties:
        type: { type: string, format: uri }
        title: { type: string }
        status: { type: integer }
        detail: { type: string }
        instance: { type: string, format: uri }

security:
  - CognitoJWT: []
```

Document every request body, response schema, and error response. Use `$ref` for reuse.

---

## HTTP Status Codes

| Code | When to Use |
|---|---|
| `200 OK` | Successful GET, PUT, PATCH with response body |
| `201 Created` | Successful POST that creates a resource; include `Location` header |
| `204 No Content` | Successful DELETE or action with no response body |
| `400 Bad Request` | Malformed request syntax, missing required fields |
| `401 Unauthorized` | Missing or invalid JWT |
| `403 Forbidden` | Valid JWT but insufficient permissions (e.g., accessing another trader's data) |
| `404 Not Found` | Resource does not exist |
| `409 Conflict` | State conflict (e.g., listing already has an active bid from this trader) |
| `422 Unprocessable Entity` | Business rule violation (e.g., self-bidding, insufficient cash) |
| `429 Too Many Requests` | Rate limit exceeded; include `Retry-After` header |
| `500 Internal Server Error` | Unexpected server error; never leak stack traces |

---

## RFC 7807 Problem Details

Every error response must use `Content-Type: application/problem+json`.

```json
{
  "type": "https://pettrading.example.com/errors/insufficient-cash",
  "title": "Insufficient available cash",
  "status": 422,
  "detail": "Bid amount $250 exceeds available cash $180.50.",
  "instance": "/v1/listings/abc123/bids",
  "traceId": "0HN123ABC456"
}
```

Define a URI for each error type in the `type` field. Include `traceId` for correlation with X-Ray.

---

## Pagination

Use **cursor-based pagination** for all collections. Offset pagination breaks when items are
inserted/deleted between pages (common in a live trading system).

### Request

```
GET /v1/listings?limit=20&cursor=eyJpZCI6IjEyMyJ9
```

### Response

```json
{
  "items": [...],
  "pagination": {
    "nextCursor": "eyJpZCI6IjE0MyJ9",
    "hasMore": true,
    "limit": 20
  }
}
```

Cursor is a base64-encoded JSON object containing the last seen `id` (and/or `created_at`).
Never expose raw database row IDs as cursors.

### PostgreSQL Cursor Query Pattern

```sql
SELECT * FROM listings
WHERE is_active = TRUE
  AND id < @Cursor   -- decode cursor to get the id
ORDER BY created_at DESC, id DESC
LIMIT @Limit + 1     -- fetch one extra to determine hasMore
```

---

## API Versioning

- Version via URL path: `/v1/`, `/v2/`.
- Additive, backwards-compatible changes (new optional fields, new endpoints): no new version.
- Breaking changes (renamed fields, removed endpoints, changed semantics): new version.
- Maintain previous major version for 6 months minimum after deprecation notice.
- Communicate deprecation via `Deprecation` and `Sunset` response headers.

---

## Rate Limiting

Two-layer approach:

1. **API Gateway**: throttle at 1000 req/s burst, 500 req/s steady-state per stage. Per-client
   throttling via usage plans.
2. **Application level**: fine-grained per-trader limits for write operations (bid placement,
   listing creation) using a Redis or DynamoDB token bucket.

Rate limit response:

```json
HTTP/1.1 429 Too Many Requests
Retry-After: 30
Content-Type: application/problem+json

{
  "type": "https://pettrading.example.com/errors/rate-limit-exceeded",
  "title": "Rate limit exceeded",
  "status": 429,
  "detail": "You may place at most 10 bids per minute.",
  "instance": "/v1/listings/abc123/bids"
}
```

---

## Request/Response Validation

- Validate at the API boundary, not deep in the service layer.
- Reject unknown fields (use `[JsonIgnore]` or `AdditionalPropertiesPolicy.Disallow`).
- Use FluentValidation or Data Annotations; return all validation errors in one response:

```json
{
  "type": "https://pettrading.example.com/errors/validation",
  "title": "Validation failed",
  "status": 400,
  "errors": {
    "askingPrice": ["Must be greater than 0"],
    "petId": ["Pet not found in your inventory"]
  }
}
```

---

## WebSocket API Design (6 Event Types)

WebSocket carries notifications only — never market data or portfolio state.

### Connection

- Client connects with JWT in query string: `wss://ws.pettrading.example.com?token=<JWT>`
- API Gateway Cognito authorizer validates JWT on `$connect`.
- Trading API stores `traderId → connectionId` in DynamoDB (`connections` table, 24h TTL).

### Message Format

All messages share a common envelope:

```json
{
  "eventType": "bid.received",
  "tradeId": "uuid | null",
  "petId": "uuid",
  "petName": "string",
  "amount": 150.00,
  "counterpartyName": "string",
  "timestamp": "2026-03-21T10:00:00Z"
}
```

### Event Types and Recipients

| Event | Recipient | Payload fields |
|---|---|---|
| `bid.received` | Listing owner | `listingId`, `petId`, `petName`, `amount`, `bidderId` |
| `bid.accepted` | Bidder | `listingId`, `petId`, `petName`, `amount`, `sellerId` |
| `bid.rejected` | Bidder | `listingId`, `petId`, `petName`, `amount` |
| `outbid` | Previous bidder | `listingId`, `petId`, `petName`, `newAmount` |
| `trade.completed` | Buyer + Seller | `tradeId`, `petId`, `petName`, `price`, `counterpartyName` |
| `listing.withdrawn` | Active bidder | `listingId`, `petId`, `petName`, `refundAmount` |

### Sending Notifications (Trading API → API Gateway Management API)

```csharp
var client = new AmazonApiGatewayManagementApiClient(new AmazonApiGatewayManagementApiConfig
{
    ServiceURL = $"https://{apiId}.execute-api.{region}.amazonaws.com/{stage}"
});

await client.PostToConnectionAsync(new PostToConnectionRequest
{
    ConnectionId = connectionId,
    Data = new MemoryStream(JsonSerializer.SerializeToUtf8Bytes(notification))
});
```

Handle `GoneException` (410) by deleting stale connection from DynamoDB.

---

## Authentication and Authorization Documentation

Document in OpenAPI using `security` at operation level:

```yaml
/traders/{id}/inventory:
  get:
    security:
      - CognitoJWT: []
    parameters:
      - name: id
        in: path
        required: true
    responses:
      "200":
        description: Trader inventory
      "401":
        $ref: "#/components/responses/Unauthorized"
      "403":
        $ref: "#/components/responses/Forbidden"
```

- `401` = unauthenticated (no/invalid token).
- `403` = authenticated but trying to access another trader's private data.
- Traders can only read their own inventory, notifications, and cash balances.
- Market view (listings, leaderboard) is accessible to all authenticated traders.
