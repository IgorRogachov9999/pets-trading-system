---
name: frontend-skill
description: >
  Activate for ANY frontend task: writing React components or hooks, TypeScript
  type definitions, Vite configuration, TanStack Query (REST polling, cache
  invalidation), WebSocket client code for the 6 trade event types, Cognito JWT
  authentication flows, React Router protected routes, Tailwind CSS styling, Vitest
  / React Testing Library tests, S3+CloudFront deployment, GitHub Actions CI/CD for
  the frontend, accessibility (ARIA, semantic HTML), performance optimization
  (code splitting, memoization, bundle analysis), state management, or any UI/UX
  work in this project.
---

# Frontend Skill

You are an expert frontend engineer for the **Pets Trading System** — a real-time virtual pet
marketplace. Apply the guidance below for every frontend task. Reference the appropriate file
for deep detail; keep this file as the authoritative entry point.

---

## Project Non-Negotiables

- **TanStack Query v5 — never SWR or Apollo.** All server state goes through `useQuery` / `useMutation`.
- **WebSocket carries exactly 6 event types**: `bid.received`, `bid.accepted`, `bid.rejected`,
  `outbid`, `trade.completed`, `listing.withdrawn`. WebSocket only triggers cache invalidation — it never
  carries data payloads used to render UI directly.
- **REST polling every 5 s** drives all market/leaderboard/portfolio data. Set `refetchInterval: 5000`.
- **Cognito JWT stored in memory only** — never `localStorage`, never `sessionStorage`. Access and ID
  tokens live in a React context or Zustand store.
- **4 required views must exist**: Trader Panel (`/dashboard`), Market View (`/market`),
  Analysis/Drill-Down (`/analysis/:petId`), Leaderboard (`/leaderboard`).
- **Traders cannot bid on their own pets** — disable the bid UI when `listing.traderId === currentUser.id`.
- **Buyers see only their own bid** — never render competing bid amounts or other bidders.
- **intrinsicValue** must be computed as: `BasePrice × (Health/100) × (Desirability/10) × max(0, 1 - Age/Lifespan)`.
- **TypeScript strict mode** — `strict: true` in `tsconfig.json`. Zero `any` types in production code.
- **Tailwind CSS** for all styling unless the project already has another framework in place.
- **No hardcoded API URLs** — use `import.meta.env.VITE_API_BASE_URL` and `VITE_WS_URL`.

---

## 1. React + TypeScript

**Reference**: [`references/react-typescript.md`](references/react-typescript.md)

- Use **functional components only**. No class components.
- Co-locate component, hook, and test files: `components/MarketView/MarketView.tsx`,
  `components/MarketView/MarketView.test.tsx`, `hooks/useMarketListings.ts`.
- Wrap each major view section in a dedicated **error boundary** so one broken section does not
  crash the whole page.
- Use **Suspense** with `useSuspenseQuery` for data-dependent sections when a loading skeleton is
  appropriate; use `useQuery` with manual `isLoading` handling for incremental updates.
- Apply `useTransition` for non-urgent updates (leaderboard sort, filter changes) and
  `useDeferredValue` for search/filter inputs to keep the UI responsive during polling.
- `React.memo`, `useMemo`, `useCallback` only where profiling confirms a benefit — not by default.
- Use **branded types** for all domain IDs: `TraderId`, `PetId`, `ListingId`, `BidId`.
- Use **discriminated unions** for bid state (`active | accepted | rejected | withdrawn | outbid`)
  and listing state (`active | withdrawn | sold`).

---

## 2. TypeScript Patterns

**Reference**: [`references/react-typescript.md`](references/react-typescript.md)

- `tsconfig.json`: `"strict": true`, `"noUncheckedIndexedAccess": true`, `"exactOptionalPropertyTypes": true`.
- Import types with `import type { Foo }` — keeps runtime bundle clean.
- Define all API response shapes as interfaces; derive component prop types from them with `Pick` / `Omit`.
- Use `satisfies` operator to validate object literals against a type without widening.
- Discriminated unions for async states: `{ status: 'idle' } | { status: 'loading' } | { status: 'success'; data: T } | { status: 'error'; error: Error }`.

---

## 3. TanStack Query

**Reference**: [`references/tanstack-query-websocket.md`](references/tanstack-query-websocket.md)

- Configure `QueryClient` with global defaults: `staleTime: 4000`, `refetchInterval: false` (set per-query).
- Polling queries set `refetchInterval: 5000` and `refetchIntervalInBackground: false`.
- Canonical query keys:
  - `['trader', traderId, 'portfolio']`
  - `['trader', traderId, 'notifications']`
  - `['market', 'listings']`
  - `['leaderboard']`
  - `['pet', petId, 'analysis']`
- WebSocket events map directly to `queryClient.invalidateQueries()` — see WebSocket section.
- `trade.completed` invalidates: `['trader', buyerId, 'portfolio']`, `['trader', sellerId, 'portfolio']`,
  `['market', 'listings']`, `['leaderboard']`.
- Optimistic updates for bid placement: update `['market', 'listings']` cache immediately, roll back
  on mutation error.

---

## 4. WebSocket Client

**Reference**: [`references/tanstack-query-websocket.md`](references/tanstack-query-websocket.md)

- Single WebSocket instance managed in a **React context provider** (`WebSocketProvider`).
- Connect to API Gateway WebSocket endpoint with Cognito ID token as query param:
  `wss://...execute-api.../prod?token=<idToken>`.
- Reconnect with **exponential backoff**: base 1 s, multiplier 2×, max 3 retries, then render a
  `ConnectionLostBanner` component (non-blocking — polling still works).
- On each inbound message, parse `{ type, payload }` and call the appropriate
  `queryClient.invalidateQueries()`. Never use WebSocket payload data directly in UI.
- Disconnect cleanly on logout (send `$disconnect` or just close the socket).
- Expose `{ status: 'connecting' | 'connected' | 'reconnecting' | 'failed' }` from context for
  the connection status indicator.

---

## 5. Cognito Auth

**Reference**: [`references/cognito-auth.md`](references/cognito-auth.md)

- Use **AWS Amplify v6** (`@aws-amplify/auth`) or `amazon-cognito-identity-js` directly.
- Store **access token** and **ID token** in React `AuthContext` state (in-memory only).
- Attach ID token as `Authorization: Bearer <idToken>` header on every API request via an
  Axios interceptor or custom `fetch` wrapper.
- Implement **silent refresh** before token expiry: schedule a `setTimeout` at `(expiry - 60s)`.
- Protected routes: `<PrivateRoute>` component checks `isAuthenticated`; redirects to `/login`
  otherwise — preserves the attempted URL in `state` for post-login redirect.
- On logout: clear tokens from memory, call Cognito `signOut()`, close WebSocket, redirect to `/login`.
- Show **SessionExpiredModal** if refresh fails — prompt user to log in again.

---

## 6. The 4 Required Views

**Reference**: [`references/views-components.md`](references/views-components.md)

| View | Route | Polling | WebSocket triggers |
|---|---|---|---|
| Trader Panel | `/dashboard` | portfolio 5s, notifications on push | `bid.received`, `bid.accepted`, `bid.rejected`, `outbid`, `trade.completed`, `listing.withdrawn` |
| Market View | `/market` | listings 5s | `trade.completed`, `listing.withdrawn` |
| Analysis | `/analysis/:petId` | pet data 5s | none |
| Leaderboard | `/leaderboard` | 5s | `trade.completed` |

**Trader Panel** sections: `CashDisplay`, `InventoryGrid`, `NotificationFeed`.
**Market View** sections: `NewSupplyBanner`, `ListingsGrid`, `ListingCard` with inline bid form.
**Analysis** sections: `IntrinsicValueGauge`, `PetStatBars` (health, desirability, age), `ExpiredBadge`.
**Leaderboard** sections: `RankedTable` with current-user row highlight, rank-change indicators.

---

## 7. Styling (Tailwind CSS)

**Reference**: [`references/views-components.md`](references/views-components.md)

- Define design tokens in `tailwind.config.ts`: brand colors, spacing scale, typography.
- Use **real-time visual indicators**: flash animation on price change (green up, red down),
  pulsing border on newly received bids, `aria-live="polite"` on the notification feed.
- Mobile-first responsive layout: single column on mobile, grid on desktop.
- Use `cn()` utility (clsx + tailwind-merge) for conditional class composition.
- Avoid inline styles — all dynamic styling goes through Tailwind class toggling.

---

## 8. Testing

**Reference**: [`references/testing.md`](references/testing.md)

- **Vitest** as test runner; **React Testing Library** for component tests.
- All tests use a custom `renderWithProviders()` wrapper: `QueryClientProvider` + `AuthProvider` +
  `MemoryRouter`.
- **MSW** (Mock Service Worker) for API mocking — define handlers in `src/mocks/handlers.ts`.
- Test polling with `vi.useFakeTimers()` + `vi.advanceTimersByTime(5000)`.
- Test WebSocket events by calling the mock socket's `onmessage` handler and asserting cache invalidation.
- Coverage targets: **80%+** for all custom hooks containing business logic, **70%+** overall.
- Prefer **behavioral tests** (what the user sees) over snapshot tests.

---

## 9. Deployment

**Reference**: [`references/deployment.md`](references/deployment.md)

- `vite build` with code splitting: vendor chunk, auth chunk, per-view lazy chunks.
- Inject environment variables at build time via GitHub Actions secrets → `$GITHUB_ENV`.
- S3 sync: `aws s3 sync dist/ s3://$BUCKET --delete`. Set `Cache-Control: no-cache` for
  `index.html`; `max-age=31536000,immutable` for hashed assets.
- CloudFront custom error: `404 → /index.html` with HTTP 200 response code (SPA routing).
- CloudFront invalidation after every deploy: `aws cloudfront create-invalidation --paths "/index.html" "/assets/*"`.
- GitHub Actions uses **OIDC** for AWS credentials — no static `AWS_ACCESS_KEY_ID` secrets.
- Feature branch previews deploy to `s3://bucket/previews/<branch-name>/`.

---

## 10. Performance & Accessibility

**Reference**: [`references/react-typescript.md`](references/react-typescript.md)

- Lazy-load all route components with `React.lazy()` + `<Suspense fallback={<PageSkeleton />}>`.
- Analyze bundle with `rollup-plugin-visualizer` — keep initial JS under 200 KB gzipped.
- Use `aria-live="polite"` on `NotificationFeed` and price-change regions so screen readers
  announce updates without interrupting the user.
- Semantic HTML: `<main>`, `<nav>`, `<section aria-labelledby>`, `<table>` for leaderboard.
- All interactive elements reachable by keyboard; focus visible styles never removed.
- Color contrast WCAG AA minimum (4.5:1 for text, 3:1 for large text / UI components).
- Avoid layout shift during polling updates — reserve space for dynamic content with fixed heights
  or skeleton placeholders.
