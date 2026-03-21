# ADR-005: AWS API Gateway for API Management

## Status
Accepted

## Context
The system needs a single entry point for all client-to-backend communication, supporting both REST API calls and WebSocket connections. The entry point should handle JWT validation, request throttling, and integrate with WAF for security.

## Decision
Use **AWS API Gateway** with both a **REST API** (for CRUD operations) and a **WebSocket API** (for real-time push notifications).

## Consequences
**Easier:**
- Cognito authorizer validates JWT tokens before requests reach backend (offloads auth)
- Built-in throttling and quota management prevents abuse
- WebSocket API manages connection lifecycle (connect/disconnect/message)
- VPC Link integration routes to internal ALB (backend stays in private subnet)
- WAF integration for OWASP protection
- Access logging to CloudWatch
- Custom domain support with ACM certificates

**Harder:**
- WebSocket API requires external connection tracking (DynamoDB)
- API Gateway adds ~10-20ms latency per request
- WebSocket API has 500 concurrent connections per route (default quota)
- Request/response size limited to 10MB

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Direct ALB exposure** | No built-in JWT validation; no WebSocket management; no WAF integration |
| **AWS AppSync** | GraphQL adds complexity; team more familiar with REST; overkill for this API surface |
| **Kong / NGINX** | Self-managed; additional ECS service to maintain; no native Cognito integration |
