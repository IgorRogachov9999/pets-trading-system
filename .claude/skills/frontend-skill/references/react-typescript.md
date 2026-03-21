# React + TypeScript Reference

Deep guidance for React 18 + TypeScript strict mode in the Pets Trading System frontend.

---

## TypeScript Strict tsconfig for Vite Projects

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "allowImportingTsExtensions": true,
    "noEmit": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

```jsonc
// tsconfig.node.json
{
  "compilerOptions": {
    "composite": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "allowSyntheticDefaultImports": true
  },
  "include": ["vite.config.ts"]
}
```

---

## Branded Types for Domain Model

Branded types prevent passing a `PetId` where a `TraderId` is expected — catches entire classes
of bugs at compile time.

```typescript
// src/types/brands.ts
declare const __brand: unique symbol;
type Brand<T, B> = T & { readonly [__brand]: B };

export type TraderId  = Brand<string, 'TraderId'>;
export type PetId     = Brand<string, 'PetId'>;
export type ListingId = Brand<string, 'ListingId'>;
export type BidId     = Brand<string, 'BidId'>;

// Usage: cast once at the API boundary, then rely on types throughout
const traderId = response.traderId as TraderId;
```

**Rule**: cast to branded types only in API response mappers (`src/api/mappers/`). Everywhere
else, accept the branded type directly — no further casting needed.

---

## Discriminated Unions for Domain States

### Bid State

```typescript
// src/types/domain.ts
export type BidStatus =
  | { status: 'active';    bidId: BidId; amount: number }
  | { status: 'accepted';  bidId: BidId; amount: number; acceptedAt: string }
  | { status: 'rejected';  bidId: BidId; amount: number; rejectedAt: string }
  | { status: 'withdrawn'; bidId: BidId; amount: number }
  | { status: 'outbid';    bidId: BidId; amount: number; replacedByAmount: number };
```

### Listing State

```typescript
export type ListingState =
  | { state: 'active';    listingId: ListingId; askingPrice: number; myBid?: BidStatus }
  | { state: 'withdrawn'; listingId: ListingId; withdrawnAt: string }
  | { state: 'sold';      listingId: ListingId; soldAt: string; salePrice: number };
```

### Async State Wrapper (for manual loading states)

```typescript
export type AsyncState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error';   error: Error };
```

Use exhaustive `switch` on `status` — TypeScript enforces all branches are handled:

```typescript
function renderBidStatus(bid: BidStatus): React.ReactNode {
  switch (bid.status) {
    case 'active':    return <ActiveBadge amount={bid.amount} />;
    case 'accepted':  return <AcceptedBadge amount={bid.amount} />;
    case 'rejected':  return <RejectedBadge />;
    case 'withdrawn': return <WithdrawnBadge />;
    case 'outbid':    return <OutbidBadge replacedBy={bid.replacedByAmount} />;
    // TypeScript error if a case is missing
  }
}
```

---

## Component Patterns

### Functional Components with Explicit Return Types

```typescript
// Always annotate the return type for exported components
interface ListingCardProps {
  listing: ActiveListing;
  currentTraderId: TraderId;
  onBidPlace: (listingId: ListingId, amount: number) => void;
}

export function ListingCard({
  listing,
  currentTraderId,
  onBidPlace,
}: ListingCardProps): React.ReactElement {
  const isOwnListing = listing.traderId === currentTraderId;
  // ...
}
```

### Custom Hooks Pattern

Keep hooks focused: one hook per query or per behavior cluster.

```typescript
// src/hooks/useMarketListings.ts
import { useQuery } from '@tanstack/react-query';
import { fetchMarketListings } from '@/api/market';
import type { MarketListing } from '@/types/domain';

export function useMarketListings() {
  return useQuery<MarketListing[]>({
    queryKey: ['market', 'listings'],
    queryFn: fetchMarketListings,
    refetchInterval: 5000,
    refetchIntervalInBackground: false,
    staleTime: 4000,
  });
}
```

### Compound Components Pattern

Use for complex UI sections with shared state (e.g., `ListingCard` with collapsible bid form):

```typescript
const ListingCardContext = React.createContext<ListingCardContextValue | null>(null);

function useListingCardContext() {
  const ctx = React.useContext(ListingCardContext);
  if (!ctx) throw new Error('useListingCardContext must be used inside ListingCard');
  return ctx;
}

export const ListingCard = Object.assign(ListingCardRoot, {
  Header: ListingCardHeader,
  BidForm: ListingCardBidForm,
  PriceDisplay: ListingCardPriceDisplay,
});
```

---

## React 18 Concurrent Features

### useTransition — Non-Urgent Updates

Use for leaderboard sorting and filter changes so polling updates don't stutter:

```typescript
function LeaderboardPage(): React.ReactElement {
  const [sortKey, setSortKey] = React.useState<'portfolioValue' | 'rank'>('portfolioValue');
  const [isPending, startTransition] = React.useTransition();

  function handleSortChange(key: typeof sortKey) {
    startTransition(() => setSortKey(key));
  }

  return (
    <div aria-busy={isPending}>
      <SortControls current={sortKey} onChange={handleSortChange} />
      <RankedTable sortKey={sortKey} />
    </div>
  );
}
```

### useDeferredValue — Search/Filter Inputs

```typescript
function MarketSearch(): React.ReactElement {
  const [query, setQuery] = React.useState('');
  const deferredQuery = React.useDeferredValue(query);
  const isStale = query !== deferredQuery;

  return (
    <>
      <input value={query} onChange={e => setQuery(e.target.value)} />
      <div style={{ opacity: isStale ? 0.6 : 1 }}>
        <ListingsGrid filter={deferredQuery} />
      </div>
    </>
  );
}
```

---

## Memoization Guidelines

**Use `React.memo`** when:
- The component renders frequently due to parent re-renders (polling triggers parent updates)
- Props are primitives or stable references
- Profiling confirms unnecessary renders

**Do NOT use `React.memo`** when:
- Props include inline objects/arrays (new reference every render defeats memoization)
- The component is cheap to render

**Use `useMemo`** for:
- Expensive computations: intrinsicValue calculation across a large inventory grid
- Derived data that feeds into many child components

```typescript
const sortedTraders = React.useMemo(
  () => [...traders].sort((a, b) => b.portfolioValue - a.portfolioValue),
  [traders]
);
```

**Use `useCallback`** only when passing a stable function reference to a memoized child.

---

## Error Boundaries

Wrap each major view section independently so one section failing does not crash the page:

```typescript
// src/components/ErrorBoundary.tsx
interface Props {
  fallback: React.ReactNode;
  children: React.ReactNode;
}

interface State { hasError: boolean; error: Error | null }

export class ErrorBoundary extends React.Component<Props, State> {
  state: State = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.error('[ErrorBoundary]', error, info.componentStack);
  }

  render() {
    if (this.state.hasError) return this.props.fallback;
    return this.props.children;
  }
}
```

Usage in route layout:

```tsx
<ErrorBoundary fallback={<SectionError message="Market data unavailable" />}>
  <MarketView />
</ErrorBoundary>
```

---

## Suspense for Async Data

Use `useSuspenseQuery` when a full loading skeleton is appropriate (initial page load):

```tsx
// Wrap the data-dependent subtree in <Suspense>
<React.Suspense fallback={<LeaderboardSkeleton />}>
  <LeaderboardTable />  {/* uses useSuspenseQuery internally */}
</React.Suspense>
```

Use plain `useQuery` + manual `isLoading` for incremental updates (polling) where you want to
show stale data while refreshing rather than reverting to a skeleton.

---

## File Organization

```
src/
  api/                  # fetch functions + mappers (no hooks)
    market.ts
    trader.ts
    mappers/
  components/           # UI components (no data fetching)
    ListingCard/
      ListingCard.tsx
      ListingCard.test.tsx
      index.ts
  hooks/                # TanStack Query hooks + WebSocket handlers
    useMarketListings.ts
    useTraderPortfolio.ts
    useLeaderboard.ts
  pages/                # Route-level components (lazy loaded)
    MarketPage.tsx
    DashboardPage.tsx
    AnalysisPage.tsx
    LeaderboardPage.tsx
  providers/            # Context providers (Auth, WebSocket, QueryClient)
  types/                # TypeScript types, brands, discriminated unions
  utils/                # Pure utility functions
  mocks/                # MSW handlers (test + dev)
```

---

## ESLint + Prettier Configuration

```jsonc
// .eslintrc.cjs
module.exports = {
  root: true,
  env: { browser: true, es2022: true },
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/strict-type-checked',
    'plugin:react-hooks/recommended',
    'plugin:jsx-a11y/recommended',
    'prettier',
  ],
  parser: '@typescript-eslint/parser',
  parserOptions: { project: true, tsconfigRootDir: __dirname },
  plugins: ['@typescript-eslint', 'react-refresh'],
  rules: {
    'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
    '@typescript-eslint/no-explicit-any': 'error',
    '@typescript-eslint/consistent-type-imports': ['error', { prefer: 'type-imports' }],
    '@typescript-eslint/no-unnecessary-condition': 'error',
  },
};
```

```jsonc
// .prettierrc
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100,
  "tabWidth": 2
}
```

---

## Import Organization

Always use `import type` for type-only imports. Group in this order (enforced by ESLint):

```typescript
// 1. React and framework
import React from 'react';
import { useNavigate } from 'react-router-dom';

// 2. Third-party libraries
import { useQuery } from '@tanstack/react-query';

// 3. Internal absolute imports
import type { TraderId, ListingId } from '@/types/brands';
import { cn } from '@/utils/cn';

// 4. Relative imports
import { ListingCard } from './ListingCard';
```
