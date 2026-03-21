# TanStack Query + WebSocket Reference

Deep guidance for TanStack Query v5 and the API Gateway WebSocket client in the Pets Trading System.

---

## TanStack Query v5 Setup

```typescript
// src/providers/QueryProvider.tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 4_000,           // data considered fresh for 4s (just under the 5s poll)
      gcTime: 5 * 60 * 1000,      // keep unused cache for 5 minutes
      refetchInterval: false,     // opt-in per query; default is no polling
      refetchIntervalInBackground: false,
      retry: 2,
      retryDelay: (attempt) => Math.min(1000 * 2 ** attempt, 10_000),
    },
    mutations: {
      retry: 0,                   // never retry mutations automatically
    },
  },
});

export function QueryProvider({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
      {import.meta.env.DEV && <ReactQueryDevtools initialIsOpen={false} />}
    </QueryClientProvider>
  );
}
```

---

## Query Keys Structure

All query keys live in a centralized factory to prevent typos and enable granular invalidation:

```typescript
// src/api/queryKeys.ts
export const queryKeys = {
  trader: {
    all: (traderId: TraderId) => ['trader', traderId] as const,
    portfolio: (traderId: TraderId) => ['trader', traderId, 'portfolio'] as const,
    notifications: (traderId: TraderId) => ['trader', traderId, 'notifications'] as const,
    inventory: (traderId: TraderId) => ['trader', traderId, 'inventory'] as const,
  },
  market: {
    all: () => ['market'] as const,
    listings: () => ['market', 'listings'] as const,
    supply: () => ['market', 'supply'] as const,
  },
  leaderboard: () => ['leaderboard'] as const,
  pet: {
    all: (petId: PetId) => ['pet', petId] as const,
    analysis: (petId: PetId) => ['pet', petId, 'analysis'] as const,
  },
} as const;
```

---

## Polling Setup

Queries that need polling declare `refetchInterval` explicitly:

```typescript
// src/hooks/useMarketListings.ts
export function useMarketListings() {
  return useQuery({
    queryKey: queryKeys.market.listings(),
    queryFn: () => api.get<MarketListing[]>('/market/listings'),
    refetchInterval: 5_000,
    refetchIntervalInBackground: false,
    staleTime: 4_000,
  });
}

// src/hooks/useLeaderboard.ts
export function useLeaderboard() {
  return useQuery({
    queryKey: queryKeys.leaderboard(),
    queryFn: () => api.get<TraderRank[]>('/leaderboard'),
    refetchInterval: 5_000,
    refetchIntervalInBackground: false,
    staleTime: 4_000,
    // Wrap in useTransition at the component level for smooth re-renders
  });
}

// src/hooks/useTraderPortfolio.ts
export function useTraderPortfolio(traderId: TraderId) {
  return useQuery({
    queryKey: queryKeys.trader.portfolio(traderId),
    queryFn: () => api.get<TraderPortfolio>(`/traders/${traderId}/portfolio`),
    refetchInterval: 5_000,
    staleTime: 4_000,
    enabled: !!traderId,
  });
}

// src/hooks/usePetAnalysis.ts — polling for live health/desirability updates
export function usePetAnalysis(petId: PetId) {
  return useQuery({
    queryKey: queryKeys.pet.analysis(petId),
    queryFn: () => api.get<PetAnalysis>(`/pets/${petId}/analysis`),
    refetchInterval: 5_000,
    staleTime: 4_000,
    enabled: !!petId,
  });
}
```

---

## WebSocket Client Implementation

### WebSocket Context Provider

```typescript
// src/providers/WebSocketProvider.tsx
import React from 'react';
import { queryClient } from './QueryProvider';
import { queryKeys } from '@/api/queryKeys';
import { useAuth } from '@/providers/AuthProvider';
import type { TraderId } from '@/types/brands';

type WsStatus = 'connecting' | 'connected' | 'reconnecting' | 'failed';

interface WebSocketContextValue {
  status: WsStatus;
}

const WebSocketContext = React.createContext<WebSocketContextValue | null>(null);

const WS_BASE_URL = import.meta.env.VITE_WS_URL as string;
const MAX_RETRIES = 3;

export function WebSocketProvider({ children }: { children: React.ReactNode }) {
  const { getIdToken, traderId, isAuthenticated } = useAuth();
  const [status, setStatus] = React.useState<WsStatus>('connecting');
  const socketRef = React.useRef<WebSocket | null>(null);
  const retryCountRef = React.useRef(0);
  const retryTimerRef = React.useRef<ReturnType<typeof setTimeout> | null>(null);

  const connect = React.useCallback(() => {
    const token = getIdToken();
    if (!token || !isAuthenticated) return;

    setStatus(retryCountRef.current > 0 ? 'reconnecting' : 'connecting');
    const ws = new WebSocket(`${WS_BASE_URL}?token=${encodeURIComponent(token)}`);
    socketRef.current = ws;

    ws.onopen = () => {
      setStatus('connected');
      retryCountRef.current = 0;
    };

    ws.onmessage = (event: MessageEvent<string>) => {
      handleWsMessage(event, traderId);
    };

    ws.onclose = () => {
      if (retryCountRef.current < MAX_RETRIES) {
        const delay = Math.min(1000 * 2 ** retryCountRef.current, 16_000);
        retryCountRef.current += 1;
        setStatus('reconnecting');
        retryTimerRef.current = setTimeout(connect, delay);
      } else {
        setStatus('failed');
      }
    };

    ws.onerror = () => {
      ws.close(); // triggers onclose which handles retry
    };
  }, [getIdToken, isAuthenticated, traderId]);

  React.useEffect(() => {
    if (!isAuthenticated) return;
    connect();

    return () => {
      retryTimerRef.current && clearTimeout(retryTimerRef.current);
      socketRef.current?.close();
    };
  }, [connect, isAuthenticated]);

  return (
    <WebSocketContext.Provider value={{ status }}>
      {status === 'failed' && <ConnectionLostBanner />}
      {children}
    </WebSocketContext.Provider>
  );
}

export function useWebSocketStatus(): WsStatus {
  const ctx = React.useContext(WebSocketContext);
  if (!ctx) throw new Error('useWebSocketStatus must be used inside WebSocketProvider');
  return ctx.status;
}
```

### WebSocket Message Handler

Map all 6 event types to targeted cache invalidations. Never use payload data to update the cache
directly — always re-fetch to keep the server as the single source of truth.

```typescript
// src/providers/WebSocketProvider.tsx (continued)
interface WsMessage {
  type:
    | 'bid.received'
    | 'bid.accepted'
    | 'bid.rejected'
    | 'outbid'
    | 'trade.completed'
    | 'listing.withdrawn';
  payload: {
    traderId?: TraderId;
    buyerId?: TraderId;
    sellerId?: TraderId;
    listingId?: string;
    petId?: string;
  };
}

function handleWsMessage(event: MessageEvent<string>, currentTraderId: TraderId | null) {
  let msg: WsMessage;
  try {
    msg = JSON.parse(event.data) as WsMessage;
  } catch {
    console.warn('[WS] Failed to parse message', event.data);
    return;
  }

  switch (msg.type) {
    case 'bid.received':
      // Listing owner's dashboard: new bid on one of their pets
      if (currentTraderId) {
        void queryClient.invalidateQueries({ queryKey: queryKeys.market.listings() });
        void queryClient.invalidateQueries({ queryKey: queryKeys.trader.notifications(currentTraderId) });
      }
      break;

    case 'bid.accepted':
    case 'bid.rejected':
    case 'outbid':
      // Bidder: their bid status changed
      if (currentTraderId) {
        void queryClient.invalidateQueries({ queryKey: queryKeys.trader.notifications(currentTraderId) });
        void queryClient.invalidateQueries({ queryKey: queryKeys.trader.portfolio(currentTraderId) });
      }
      break;

    case 'trade.completed':
      // Both buyer and seller; also updates market and leaderboard
      void queryClient.invalidateQueries({ queryKey: queryKeys.market.listings() });
      void queryClient.invalidateQueries({ queryKey: queryKeys.leaderboard() });
      if (currentTraderId) {
        void queryClient.invalidateQueries({ queryKey: queryKeys.trader.portfolio(currentTraderId) });
        void queryClient.invalidateQueries({ queryKey: queryKeys.trader.notifications(currentTraderId) });
        void queryClient.invalidateQueries({ queryKey: queryKeys.trader.inventory(currentTraderId) });
      }
      break;

    case 'listing.withdrawn':
      // Active bidder: their bid was rejected because listing was withdrawn
      void queryClient.invalidateQueries({ queryKey: queryKeys.market.listings() });
      if (currentTraderId) {
        void queryClient.invalidateQueries({ queryKey: queryKeys.trader.notifications(currentTraderId) });
        void queryClient.invalidateQueries({ queryKey: queryKeys.trader.portfolio(currentTraderId) });
      }
      break;

    default:
      console.warn('[WS] Unknown event type', (msg as { type: string }).type);
  }
}
```

---

## Optimistic Updates for Bid Placement

Show the user's bid immediately; roll back on error:

```typescript
// src/hooks/usePlaceBid.ts
export function usePlaceBid() {
  return useMutation({
    mutationFn: ({ listingId, amount }: { listingId: ListingId; amount: number }) =>
      api.post<BidResponse>(`/listings/${listingId}/bids`, { amount }),

    onMutate: async ({ listingId, amount }) => {
      // Cancel outgoing refetches to prevent race conditions
      await queryClient.cancelQueries({ queryKey: queryKeys.market.listings() });

      // Snapshot current state for rollback
      const previousListings = queryClient.getQueryData<MarketListing[]>(queryKeys.market.listings());

      // Optimistically update the listing to show pending bid
      queryClient.setQueryData<MarketListing[]>(
        queryKeys.market.listings(),
        (old) =>
          old?.map((listing) =>
            listing.listingId === listingId
              ? {
                  ...listing,
                  myBid: { status: 'active' as const, amount, bidId: 'pending' as BidId },
                }
              : listing,
          ),
      );

      return { previousListings };
    },

    onError: (_err, _vars, context) => {
      // Roll back optimistic update
      if (context?.previousListings) {
        queryClient.setQueryData(queryKeys.market.listings(), context.previousListings);
      }
    },

    onSettled: () => {
      // Always refetch after mutation to sync with server state
      void queryClient.invalidateQueries({ queryKey: queryKeys.market.listings() });
    },
  });
}
```

---

## Other Mutation Patterns

```typescript
// src/hooks/useWithdrawListing.ts
export function useWithdrawListing() {
  return useMutation({
    mutationFn: (listingId: ListingId) =>
      api.delete(`/listings/${listingId}`),
    onSuccess: (_data, listingId) => {
      void queryClient.invalidateQueries({ queryKey: queryKeys.market.listings() });
      void queryClient.invalidateQueries({ queryKey: queryKeys.trader.inventory(currentTraderId) });
    },
  });
}

// src/hooks/usePurchaseSupply.ts
export function usePurchaseSupply() {
  return useMutation({
    mutationFn: (breedId: string) =>
      api.post<Pet>('/supply/purchase', { breedId }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: queryKeys.market.supply() });
      void queryClient.invalidateQueries({ queryKey: queryKeys.trader.portfolio(currentTraderId) });
      void queryClient.invalidateQueries({ queryKey: queryKeys.trader.inventory(currentTraderId) });
    },
  });
}
```

---

## useQuery vs useSuspenseQuery

| Scenario | Use |
|---|---|
| Initial page load with skeleton placeholder | `useSuspenseQuery` |
| Polling with stale-data shown during refresh | `useQuery` |
| Optional/conditional data | `useQuery` with `enabled` |
| Multiple concurrent independent queries | `useQueries` |
| Parallel queries in Suspense boundary | `useSuspenseQueries` |

`useSuspenseQuery` throws a Promise (caught by `<Suspense>`) during loading and throws an error
(caught by `<ErrorBoundary>`) on failure. No `isLoading` / `isError` state to check.

`useQuery` returns `{ data, isLoading, isError, error }` — more flexible for polling because you
can show stale data while `isFetching` is `true`.

---

## Invalidation Cascade Reference

| WebSocket Event | Invalidated Query Keys |
|---|---|
| `bid.received` | `market.listings`, `trader.notifications` |
| `bid.accepted` | `trader.notifications`, `trader.portfolio` |
| `bid.rejected` | `trader.notifications`, `trader.portfolio` |
| `outbid` | `trader.notifications`, `trader.portfolio` |
| `trade.completed` | `market.listings`, `leaderboard`, `trader.portfolio`, `trader.notifications`, `trader.inventory` |
| `listing.withdrawn` | `market.listings`, `trader.notifications`, `trader.portfolio` |
