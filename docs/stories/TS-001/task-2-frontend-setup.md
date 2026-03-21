# Task 2: Frontend — React SPA Skeleton

**Jira**: [PTS-19](https://igorrogachov9999.atlassian.net/browse/PTS-19)
**Story**: [TS-001](./story.md)
**Label**: `frontend`
**Depends on**: nothing (API contract defined in Task 1)

## API Contract to Implement Against

```
GET /api/health
Response: 200 OK
Body: { "message": "Pets Trading System API is running" }
Auth: None
```

## What to Build

### `src/ui/` — React + TypeScript + Vite
- Single `App` component:
  - Calls `GET /api/health` on mount via TanStack Query
  - Displays the `message` string
  - Shows loading state while fetching
  - Shows error if call fails
- `vite.config.ts`: proxy `/api` → `http://localhost:8080`
- Tailwind CSS (basic setup)
- `Dockerfile`: node:20-alpine build → nginx:alpine serve

### `src/ui/src/__tests__/` — Vitest + React Testing Library
- At least one test: renders App, mocks the query, asserts message in DOM

## Acceptance Criteria

- `npm run build` succeeds
- `npm test` passes all tests
- `docker build src/ui/` produces a valid image
