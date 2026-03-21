# ADR-006: Amazon Cognito for Authentication

## Status
Accepted

## Context
The system requires user registration and authentication with email/password. Passwords must be securely hashed. Sessions must be managed with JWT tokens that can be validated by API Gateway without calling the backend. The solution should be AWS-native to align with the IAM-first approach.

## Decision
Use **Amazon Cognito User Pools** for user registration, authentication, and JWT token management.

## Consequences
**Easier:**
- AWS-managed password hashing (SRP protocol) -- no custom crypto needed
- JWT tokens validated by API Gateway Cognito Authorizer (zero backend load)
- Built-in user pool management (create, verify, disable users)
- GlobalSignOut for server-side session invalidation on logout
- Configurable password policies (minimum length, character requirements)
- Token refresh flow handled by Cognito SDK
- Free tier: 50,000 MAU (more than sufficient for hackathon)

**Harder:**
- Cognito's error messages are generic (by design for security)
- Limited customization of registration flow without Lambda triggers
- Cognito sub (UUID) must be mapped to application trader ID in PostgreSQL
- Token expiry configuration is at the user pool level, not per-user

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Custom auth (bcrypt + JWT)** | Requires implementing password hashing, token issuance, refresh logic; security risk |
| **Auth0** | External service; additional cost; not AWS-native; adds external dependency |
| **AWS IAM Identity Center** | Designed for workforce identity, not customer identity |
| **Firebase Auth** | Cross-cloud dependency; not AWS-native |
