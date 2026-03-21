# ADR-004: React for Frontend SPA

## Status
Accepted

## Context
The frontend must render 5+ distinct views (Auth, Trader Panel, Market View, Analysis, Leaderboard, Account), handle real-time WebSocket updates, and manage complex client-side state (cash, inventory, notifications). It should be deployable as a static site to S3/CloudFront.

## Decision
Use **React 18** with **TypeScript** and **Vite** bundler, hosted as a static SPA on **S3** behind **CloudFront CDN**.

## Consequences
**Easier:**
- Component-based architecture maps well to the distinct UI views
- React's state management handles real-time updates from WebSocket
- TypeScript provides type safety for API response types and domain models
- Vite provides fast builds and hot module replacement during development
- Static build deploys trivially to S3; CloudFront provides global CDN
- Large ecosystem of UI component libraries (e.g., shadcn/ui, MUI)

**Harder:**
- Client-side rendering means initial page load requires JavaScript execution
- State management complexity for real-time updates across multiple views
- Need to handle WebSocket reconnection and state synchronization

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Angular** | Heavier framework; steeper learning curve; more boilerplate for this scale |
| **Vue.js** | Viable alternative; React chosen for broader team familiarity |
| **Next.js** | SSR unnecessary for SPA; adds server-side complexity; harder S3 deployment |
| **Svelte** | Smaller ecosystem; less team familiarity |
