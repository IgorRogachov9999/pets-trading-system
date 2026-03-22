# SPIKE-AUTH-000: Authentication Implementation Plan

**Covers:** US-000.1 (Register), US-000.2 (Login), US-000.3 (Logout), US-000.4 (Protect Routes)
**Jira Stories:** PTS-29, PTS-30, PTS-31, PTS-32
**Status:** Draft v6 — awaiting approval
**ADR References:** ADR-006 (Cognito), ADR-005 (API Gateway), ADR-017 (Hybrid real-time)

---

## 1. Current State Audit


| Layer              | What Exists                                                                                                                                     | What's Missing                                                                                                                                                                                                       |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Infrastructure** | Cognito User Pool + App Client (Terraform module done), API Gateway Cognito Authorizer on `{proxy+}`, Terraform outputs for Pool ID + Client ID | VITE env vars not injected in frontend CI, `pts/app-config` secret not populated post-apply, WebSocket `$connect` has no JWT authorizer, ECS task missing `COGNITO_USER_POOL_ID` env var, Liquibase not in pipelines |
| **Backend**        | Domain entities (Trader), ITraderRepository interface, HealthController                                                                         | JWT middleware in Program.cs, traders Liquibase migration, TraderRepository (Dapper), IUnitOfWork, TraderService, AuthService, AuthController (register/logout), AccountController (GET /accounts/dashboard)          |
| **Frontend**       | Route definitions for /login and /register, `apiFetch` wrapper with optional Bearer token, stub LoginPage and RegisterPage                      | Auth SDK, AuthContext, useAuth hook, FormField component, AuthLayout, ProtectedRoute, AccountDashboard stub, session restore, silent refresh, token passed to all API calls                                          |
| **Design**         | None                                                                                                                                            | Login + Register screens + AccountDashboard stub in Pencil                                                                                                                                                           |


---

## 2. Architecture Decisions

### 2.1 JWT Validation Strategy: Backend validates locally (not header trust)

**Decision:** The backend validates Cognito JWTs locally using `AddJwtBearer` middleware + JWKS auto-fetch.

**Why not trust `X-Trader-Sub` header from API Gateway:** During local development, requests hit the ALB directly (no API Gateway), so any header-based identity can be forged. Backend must validate the token itself for a consistent security boundary.

**Cost:** Negligible — JWKS public key is fetched on startup and cached in-process.

```csharp
// Program.cs
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        var region = builder.Configuration["AWS:Region"];
        var userPoolId = builder.Configuration["AWS:CognitoUserPoolId"];
        options.Authority = $"https://cognito-idp.{region}.amazonaws.com/{userPoolId}";
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            ValidateIssuer = true,
            ValidateAudience = false,  // Cognito access tokens use client_id, not aud
            ValidateLifetime = true,
        };
    });
```

Middleware order: `UseAuthentication` → `UseAuthorization` → `MapControllers`.

### 2.2 Cognito Keys on UI: Safe by design

The User Pool ID and App Client ID are public-facing identifiers — equivalent to Firebase's `apiKey`. Visible in the JS bundle intentionally. The App Client uses `generate_secret = false` for SPA use. A malicious actor with these values can only attempt to register with a new email — which is already publicly available on the registration page. All security is enforced by Cognito (credential validation) + API Gateway (JWT validation) + backend (JWT re-validation + sub → trader lookup). No risk.

### 2.3 Cognito SDK: `amazon-cognito-identity-js` (not Amplify)

**Decision:** Use `amazon-cognito-identity-js` directly (~44 KB). Amplify v6 adds ~120 KB+ gzipped with unnecessary overhead (Hub event bus, storage adapters).

**Token storage:** ID token and access token in React Context memory only. `amazon-cognito-identity-js` manages its own refresh token in `localStorage` internally — used for session restore on page refresh.

### 2.4 Token Type: ID Token as `Authorization: Bearer`

**Decision:** Frontend sends Cognito **ID token** as `Authorization: Bearer <id_token>`.

**Why:** ID tokens contain the `sub` claim needed by backend for trader lookup. Access tokens use `client_id` not `aud` and lack user attributes.

### 2.5 Auth State Management: React Context + useReducer

4-state machine: `initialising | unauthenticated | authenticated | error`. TanStack Query is for server state, not session state.

### 2.6 Email Verification: Disabled for dev environment

`auto_verified_attributes` is a configurable Terraform variable (list, default `[]`).

### 2.7 Database IDs: Application-generated (no DB defaults)

**Decision:** All entity IDs are `UUID` generated in the application layer via `Guid.NewGuid()` in C#. The `traders` table column is `UUID PRIMARY KEY` with **no DEFAULT**. The service layer sets the ID before calling the repository.

**Why:** Keeps ID generation logic in the application domain, not the database. Allows IDs to be known before the INSERT (useful for Unit of Work patterns and optimistic operations).

### 2.8 Minimal traders table: auth-only columns

**Decision:** Store only the data required for authentication in this iteration. Cash, inventory, and other trading attributes are added in EPIC-001/006. No premature schema.

### 2.9 Migrations: Liquibase (not raw SQL)

**Decision:** All database migrations use Liquibase changesets. Backend writes changelogs in Liquibase XML/SQL format. OPS updates deployment pipelines to run `liquibase update` before deploying ECS containers.

**File layout:**

```
database/trading/migrations/
├── db.changelog-master.xml        ← master changelog (includes all changesets)
└── changesets/
    └── 001-create-traders.sql     ← individual changesets
```

Migrations live at the repo root under `database/{db-name}/migrations/` — separate from API source code so any pipeline step or DBA can run them without checking out the full .NET solution.

### 2.10 Unit of Work pattern

**Decision:** All repository access goes through `IUnitOfWork`. Services depend on `IUnitOfWork`, not individual repositories. This ensures consistent transaction management across all data operations.

```csharp
public interface IUnitOfWork : IDisposable, IAsyncDisposable
{
    ITraderRepository Traders { get; }

    Task OpenConnectionAsync(CancellationToken ct = default);
    Task CloseConnectionAsync(CancellationToken ct = default);
    Task BeginTransactionAsync(CancellationToken ct = default);
    Task CommitTransactionAsync(CancellationToken ct = default);
    Task RollbackTransactionAsync(CancellationToken ct = default);
}
```

`UnitOfWork` implementation wraps a `NpgsqlConnection` + `NpgsqlTransaction`. All repositories in a UoW share the same connection and transaction. Callers open the connection, optionally begin a transaction, do their work, then commit. Connection and transaction are `null` until explicitly opened/begun.

### 2.11 Post-login redirect: /accounts/dashboard

**Decision:** After successful login or registration, the frontend redirects to `/accounts/dashboard`. This page is a placeholder stub for now (no business logic — implemented in EPIC-013). The auth implementation only needs the route to exist and be protected.

---

## 3. API Contracts

### POST /api/v1/auth/register

```
Auth: Authorization: Bearer <ID token>
Body: { "email": "trader@example.com" }

201 Created + Location: /api/v1/accounts/dashboard:
{
  "traderId": "uuid",
  "email": "trader@example.com",
  "createdAt": "2026-03-22T10:00:00Z"
}

409 Conflict    — trader already exists for this cognitoSub
400 Bad Request — email missing or malformed
401 Unauthorized — invalid JWT
```

### GET /api/v1/accounts/dashboard

```
Auth: Authorization: Bearer <ID token>

200 OK:
{
  "traderId": "uuid",
  "email": "trader@example.com",
  "createdAt": "2026-03-22T10:00:00Z"
}

401 Unauthorized — invalid/missing JWT
404 Not Found — JWT valid but no trader record
```

### POST /api/v1/auth/logout

```
Auth: Authorization: Bearer <ID token>
Body: (empty)

204 No Content — session invalidated
401 Unauthorized — invalid JWT
502 Bad Gateway — Cognito GlobalSignOut failed (frontend still clears local state)
```

---

## 4. Database Schema

### Minimal traders table (auth-only, v1)

**Migration:** `database/trading/migrations/changesets/001-create-traders.sql`
**Liquibase format** — included via `db.changelog-master.xml`

```sql
-- liquibase formatted sql
-- changeset pts:001-create-traders
CREATE TABLE traders (
    id          UUID         PRIMARY KEY,
    cognito_sub VARCHAR(128) UNIQUE NOT NULL,
    email       VARCHAR(255) UNIQUE NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_traders_cognito_sub ON traders(cognito_sub);
CREATE UNIQUE INDEX idx_traders_email ON traders(email);
-- rollback DROP TABLE traders;
```

**No** `available_cash`, `locked_cash`, `updated_at` — added in EPIC-001/006.
**No** `DEFAULT gen_random_uuid()` — ID supplied by application layer.

---

## 5. Task Breakdown

9 tasks across 4 stories.

### Task 1 — [OPS] Cognito infrastructure gaps + Liquibase in CI/CD pipelines

**Parent story:** PTS-29 | **Priority:** High | **Label:** devops

5 Cognito gaps (module already exists):

1. `terraform/modules/cognito/variables.tf` — `auto_verified_attributes` variable (list, default `[]`)
2. `terraform/modules/ecs/main.tf` — `COGNITO_USER_POOL_ID` + `AWS_REGION` env vars in ECS container
3. `.github/workflows/deploy-dev.yml` + `deploy-demo.yml` — populate `pts/app-config` secret post-apply
4. `.github/workflows/build-frontend.yml` — inject `VITE_COGNITO_USER_POOL_ID` + `VITE_COGNITO_CLIENT_ID` before `npm run build`
5. `terraform/modules/api-gateway/main.tf` — WebSocket `$connect` JWT authorizer

Liquibase additions:
6. `.github/workflows/deploy-dev.yml` — add Liquibase step **before** ECS deploy: `liquibase --changeLogFile=database/trading/migrations/db.changelog-master.xml update`; Liquibase connects to RDS via `DB_CONNECTION_STRING` from Secrets Manager
7. `terraform/modules/ecs/` (or separate job) — ECS deploy task waits for Liquibase job to succeed

---

### Task 2 — [BE] JWT middleware + Liquibase migration + IUnitOfWork + TraderRepository + POST /auth/register

**Parent story:** PTS-29 | **Priority:** High | **Label:** backend
**Depends on:** Task 1

New files:

- `database/trading/migrations/db.changelog-master.xml` — Liquibase master changelog
- `database/trading/migrations/changesets/001-create-traders.sql` — traders table (minimal schema, app-generated ID)
- `src/PetsTrading.Domain/Interfaces/IUnitOfWork.cs` — `ITraderRepository Traders { get; }` + `OpenConnectionAsync`, `CloseConnectionAsync`, `BeginTransactionAsync`, `CommitTransactionAsync`, `RollbackTransactionAsync`
- `src/PetsTrading.Infrastructure/Persistence/UnitOfWork.cs` — wraps `NpgsqlConnection` + `NpgsqlTransaction`; passes shared connection to all repos
- `src/PetsTrading.Infrastructure/Repositories/TraderRepository.cs` — `GetByCognitoSubAsync`, `CreateAsync` (receives fully-populated entity with ID already set by caller)
- `src/PetsTrading.Infrastructure/DependencyInjection.cs` — registers `IUnitOfWork → UnitOfWork`, `NpgsqlDataSource`
- `src/PetsTrading.Application/DTOs/TraderDto.cs` — `{ TraderId, Email, CreatedAt }`
- `src/PetsTrading.Application/Exceptions/TraderAlreadyExistsException.cs`
- `src/PetsTrading.Application/Services/ITraderService.cs` + `TraderService.cs` — `RegisterAsync(cognitoSub, email)`: generates `Guid.NewGuid()` for ID, checks duplicate, creates trader via `uow.Traders.CreateAsync`, commits
- `src/PetsTrading.TradingApi/Controllers/AuthController.cs` — `POST /api/v1/auth/register`

Modified:

- `Program.cs` — `AddJwtBearer`, `UseAuthentication`, `UseAuthorization`
- `PetsTrading.TradingApi.csproj` — `Microsoft.AspNetCore.Authentication.JwtBearer`
- `PetsTrading.Application.csproj` — `AWSSDK.CognitoIdentityProvider`

Unit tests: TraderService register happy path (ID is non-empty UUID), duplicate sub → 409, duplicate email; AuthController 201 + Location header, 409, 400.

---

### Task 3 — [DSN] Design authentication screens + AccountDashboard stub

**Parent story:** PTS-29 | **Priority:** High | **Label:** design
**Parallel with:** Task 2

Output: `designs/mockups/auth-flows.pen` — 5 artboards:

1. Login — Default
2. Login — Error State
3. Register — Default
4. Register — Error State
5. AccountDashboard — Stub (just a protected page shell: header with logout, a "Welcome, {email}" heading, no business logic)

---

### Task 4 — [FE] Cognito SDK + AuthContext + cognito.ts + Register page + AccountDashboard stub

**Parent story:** PTS-29 | **Priority:** High | **Label:** frontend
**Depends on:** Task 2 (API contract), Task 3 (design)

Install: `npm install amazon-cognito-identity-js`

New files:

- `src/features/auth/cognito.ts` — CognitoUserPool singleton + Promise wrappers
- `src/features/auth/AuthContext.tsx` — 4-state machine; `register()`: signUp → authenticate → POST /register → GET /accounts/dashboard → LOGIN_SUCCESS → scheduleRefresh
- `src/features/auth/useAuth.ts`
- `src/components/ui/FormField.tsx`
- `src/components/layout/AuthLayout.tsx`
- `src/features/auth/components/AuthErrorBanner.tsx`
- `src/features/account/AccountDashboard.tsx` — **stub only**: shows "Welcome, {email}" + logout button; no business logic

Modified:

- `RegisterPage.tsx` — replace stub; on success navigate to `/accounts/dashboard`
- `main.tsx` — wrap in `<AuthProvider>`
- `vite-env.d.ts` — add Cognito VITE env var types
- `features/auth/index.ts`

---

### Task 5 — [BE] GET /api/v1/accounts/dashboard endpoint

**Parent story:** PTS-30 | **Priority:** High | **Label:** backend
**Depends on:** Task 2

New files:

- `src/PetsTrading.Application/Exceptions/TraderNotFoundException.cs` (→ 404)
- `src/PetsTrading.TradingApi/Controllers/AccountController.cs` — `GET /api/v1/accounts/dashboard`

Modified: `TraderService.cs` — add `GetCurrentTraderAsync(cognitoSub)` using `uow.Traders.GetByCognitoSubAsync`

Unit tests: 200 with minimal DTO, 404 not found, `[Authorize]` reflection check.

---

### Task 6 — [FE] Login page + AuthContext login + session restore + silent refresh

**Parent story:** PTS-30 | **Priority:** High | **Label:** frontend
**Depends on:** Task 5 (GET /api/v1/accounts/dashboard contract), Task 3 (design), Task 4 (AuthContext exists)

New: `src/api/auth.ts` — `registerTrader(email, token)` + `getMe(token)`

Modified:

- `LoginPage.tsx` — replace stub; on success navigate to `/accounts/dashboard` (or `location.state.from`)
- `AuthContext.tsx` — add `login()` + session restore `useEffect` on mount

---

### Task 7 — [BE] POST /api/v1/auth/logout (GlobalSignOut)

**Parent story:** PTS-31 | **Priority:** Medium | **Label:** backend
**Depends on:** Task 2

New files:

- `src/PetsTrading.Application/Exceptions/CognitoException.cs` (→ 502)
- `src/PetsTrading.Application/Services/IAuthService.cs` + `AuthService.cs`

Modified: `AuthController.cs` — add logout action; register `IAmazonCognitoIdentityProvider` in DI.

---

### Task 8 — [FE] Logout button + GlobalSignOut flow

**Parent story:** PTS-31 | **Priority:** Medium | **Label:** frontend
**Depends on:** Task 7

Modified: `AuthContext.tsx` (logout()), `Header.tsx` (logout button), `src/api/auth.ts` (logoutTrader).

---

### Task 9 — [FE] ProtectedRoute + token propagation across all API calls

**Parent story:** PTS-32 | **Priority:** High | **Label:** frontend
**Depends on:** Task 4 + Task 6

New files:

- `src/router/ProtectedRoute.tsx`
- `src/components/shared/PageSkeleton.tsx`
- `src/features/auth/SessionExpiredModal.tsx`

Modified: `router/index.tsx` (wrap AppShell + `/accounts/dashboard` with ProtectedRoute), all `src/api/*.ts` files (add token param), all TanStack Query hooks (read idToken from useAuth, `enabled: token !== null`).

Router structure after change:

```
/login               → LoginPage (public)
/register            → RegisterPage (public)
/                    → ProtectedRoute
  /accounts/dashboard → AccountDashboard (stub)
  /market             → MarketPage
  /portfolio          → PortfolioPage
  /analysis           → AnalysisPage
  /leaderboard        → LeaderboardPage
```

---

## 6. Dependency Graph & Execution Waves

```
Wave 1 (parallel):  Task 1 [OPS]  ·  Task 3 [DSN]
Wave 2:             Task 2 [BE]   (after Task 1)
Wave 3 (parallel):  Task 4 [FE]   (after Task 2 + Task 3)
                    Task 5 [BE]   (after Task 2)
Wave 4 (parallel):  Task 6 [FE]   (after Task 5 + Task 3)
                    Task 7 [BE]   (after Task 2)
Wave 5 (parallel):  Task 8 [FE]   (after Task 7)
                    Task 9 [FE]   (after Task 4 + Task 6)
```

---

## 7. Decisions Summary


| Decision            | Chosen                                            | Rationale                                                                             |
| ------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Cognito keys on UI  | Safe — public by design                           | Pool ID + Client ID are public identifiers (like Firebase apiKey); no secret involved |
| JWT validation      | Backend validates locally (JWKS)                  | Works in local dev + production; no header forgery risk                               |
| Cognito SDK         | `amazon-cognito-identity-js`                      | Lightweight ~44 KB; no Amplify overhead                                               |
| Token to send       | ID token as `Authorization: Bearer`               | Contains `sub` claim needed by backend                                                |
| Token storage       | Memory (React context) only                       | Access/ID tokens never in localStorage                                                |
| Session restore     | Via SDK's internal refresh token in localStorage  | Transparent page refresh                                                              |
| Auth state          | React Context + useReducer                        | Sufficient, no extra dependencies                                                     |
| Email verification  | Disabled in dev (`auto_verified_attributes = []`) | Hackathon registration speed                                                          |
| Protected routes    | Custom `ProtectedRoute` component                 | Loaders can't access React context                                                    |
| DB IDs              | Application-generated `Guid.NewGuid()`            | ID known before INSERT; domain control                                                |
| DB schema           | Minimal: id, cognito_sub, email, created_at only  | No premature cash/inventory columns                                                   |
| Migrations          | Liquibase; `database/trading/migrations/` at repo root | Decoupled from API source; any pipeline step can run them without the .NET solution |
| Repository access   | IUnitOfWork with explicit open/begin/commit/rollback/close | Consistent transaction management; callers control connection lifecycle          |
| Post-login redirect | `/accounts/dashboard`                             | Account page is the landing hub (EPIC-013); stub for now                              |


