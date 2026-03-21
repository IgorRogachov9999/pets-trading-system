---
name: React SPA skeleton — structure and conventions
description: src/ui/ feature-based project layout, query client config, API layer pattern, test helper pattern (PTS-19 initial setup, PTS-23 restructure)
type: project
---

The `src/ui/` React SPA was established in PTS-19 and restructured to a feature-based architecture in PTS-23. Key decisions and conventions:

## Entry point

- `main.tsx` renders `<RouterProvider router={router} />` wrapped in `<StrictMode>` and `<QueryClientProvider>`.
- `App.tsx` is now a stub file — do not use it; all routing is in `src/router/index.tsx`.

## Query Client

- TanStack Query v5, global defaults: `staleTime: 4000`, `refetchInterval: false` (overridden per-query to `5000`).
- Test helper `createTestQueryClient()` disables retries (`retry: false`) and sets `staleTime: Infinity`.

## API Layer

- All API calls go through `src/api/client.ts` → `apiFetch<T>(path, options)`.
- `apiFetch` prepends `import.meta.env.VITE_API_BASE_URL`, attaches `Authorization: Bearer <token>` when `options.token` is provided, and throws `ApiError` on non-2xx.
- `src/api/health.ts` uses raw `fetch('/api/health')` via Vite proxy — not `apiFetch` — to preserve the existing proxy config.
- Per-domain API files: `listings.ts`, `bids.ts`, `portfolio.ts`, `supply.ts`, `trades.ts`, `leaderboard.ts`, `notifications.ts`.

## Directory Layout

```
src/
├── api/           # Typed fetch functions (one file per domain)
├── components/
│   ├── ui/        # Button, Card, Badge, Spinner + index.ts
│   └── layout/    # AppShell (Outlet), Header (NavLink) + index.ts
├── features/
│   ├── auth/      # LoginPage, RegisterPage
│   ├── market/    # MarketPage (has health query + tests)
│   ├── portfolio/ # PortfolioPage
│   ├── analysis/  # AnalysisPage
│   └── leaderboard/ # LeaderboardPage
├── hooks/         # useWebSocket (stub), index.ts
├── types/         # trader, pet, listing, bid, trade, notification + index.ts
├── utils/         # formatCurrency, formatAge + index.ts
├── router/        # createBrowserRouter — / → /market, /login, /register, /portfolio, /analysis, /leaderboard
└── vite-env.d.ts  # ImportMetaEnv: VITE_API_BASE_URL, VITE_WS_URL
```

## Router

- `/` redirects to `/market`.
- `/login`, `/register` render outside `AppShell` (no nav header).
- All other routes render inside `AppShell` (Header + Outlet).

## TypeScript

- `tsconfig.app.json`: `strict: true`, `exactOptionalPropertyTypes: true`, `noUncheckedIndexedAccess: true`, `noUnusedLocals: true`, `noUnusedParameters: true`.
- All domain types are `interface` (not type alias) — exported from `src/types/index.ts`.
- `import type { ... }` used for all type-only imports.

## Tests

- Tests co-located in the feature directory: `src/features/market/MarketPage.test.tsx`.
- `src/utils/formatCurrency.test.ts` covers the currency formatter.
- Old `src/__tests__/App.test.tsx` is now a stub — tests moved to MarketPage.test.tsx.
- Vitest `globals: true` — explicit `vi` import used for clarity.
- `setupFiles: ['./src/setupTests.ts']` wires `@testing-library/jest-dom`.

## Dependencies

- `react-router-dom: ^6.0.0` added in PTS-23 (ships its own types — no `@types/react-router-dom` needed).

**Why:** Establishes the patterns all future components and hooks must follow.
**How to apply:** New features go in `src/features/<feature>/`. New API calls go in `src/api/<domain>.ts` using `apiFetch`. New domain types go in `src/types/<domain>.ts` and are re-exported from `src/types/index.ts`. Tests co-locate with the feature file they test.
