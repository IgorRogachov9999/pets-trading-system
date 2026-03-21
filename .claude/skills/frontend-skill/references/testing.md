# Testing Reference

Deep guidance for Vitest + React Testing Library in the Pets Trading System frontend.

---

## Vitest Configuration

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      thresholds: {
        lines:     70,
        functions: 70,
        branches:  70,
        statements: 70,
      },
      // Higher threshold for business logic hooks
      include: ['src/hooks/**', 'src/utils/**', 'src/api/**'],
    },
  },
  resolve: {
    alias: { '@': '/src' },
  },
});
```

```typescript
// src/test/setup.ts
import '@testing-library/jest-dom';
import { server } from '@/mocks/server';

// Start MSW server before all tests
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// Suppress noisy console.error in tests
vi.spyOn(console, 'error').mockImplementation(() => undefined);
```

---

## Custom Render Wrapper

All tests must use `renderWithProviders` to ensure consistent context setup:

```typescript
// src/test/renderWithProviders.tsx
import { render, type RenderOptions } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, type MemoryRouterProps } from 'react-router-dom';
import type { ReactElement } from 'react';

// Stable mock auth context
interface MockAuthState {
  isAuthenticated?: boolean;
  traderId?: string;
}

const AuthContext = React.createContext<AuthContextValue | null>(null);

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,         // never retry in tests
        gcTime: Infinity,     // keep data for the entire test
      },
    },
  });
}

interface RenderConfig {
  auth?: MockAuthState;
  routerProps?: MemoryRouterProps;
  queryClient?: QueryClient;
}

export function renderWithProviders(
  ui: ReactElement,
  {
    auth = { isAuthenticated: false },
    routerProps = { initialEntries: ['/'] },
    queryClient = createTestQueryClient(),
  }: RenderConfig = {},
  options?: Omit<RenderOptions, 'wrapper'>
) {
  const mockAuthValue: AuthContextValue = {
    isAuthenticated: auth.isAuthenticated ?? false,
    traderId: auth.traderId as TraderId ?? null,
    login: vi.fn(),
    logout: vi.fn(),
    getIdToken: () => auth.isAuthenticated ? 'mock-id-token' : null,
    getAccessToken: () => auth.isAuthenticated ? 'mock-access-token' : null,
  };

  function Wrapper({ children }: { children: React.ReactNode }) {
    return (
      <QueryClientProvider client={queryClient}>
        <AuthContext.Provider value={mockAuthValue}>
          <MemoryRouter {...routerProps}>
            {children}
          </MemoryRouter>
        </AuthContext.Provider>
      </QueryClientProvider>
    );
  }

  return {
    ...render(ui, { wrapper: Wrapper, ...options }),
    queryClient,
  };
}
```

---

## MSW Setup for API Mocking

```typescript
// src/mocks/handlers.ts
import { http, HttpResponse } from 'msw';

const BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000';

export const handlers = [
  // Market listings
  http.get(`${BASE}/market/listings`, () =>
    HttpResponse.json(mockListings)
  ),

  // Trader portfolio
  http.get(`${BASE}/traders/:traderId/portfolio`, ({ params }) =>
    HttpResponse.json(mockPortfolios[params.traderId as string] ?? mockPortfolios['default'])
  ),

  // Leaderboard
  http.get(`${BASE}/leaderboard`, () =>
    HttpResponse.json(mockLeaderboard)
  ),

  // Pet analysis
  http.get(`${BASE}/pets/:petId/analysis`, ({ params }) =>
    HttpResponse.json(mockPetAnalysis(params.petId as string))
  ),

  // Place bid
  http.post(`${BASE}/listings/:listingId/bids`, async ({ request, params }) => {
    const body = await request.json() as { amount: number };
    return HttpResponse.json({
      bidId: 'bid-123',
      listingId: params.listingId,
      amount: body.amount,
      status: 'active',
    }, { status: 201 });
  }),

  // Withdraw listing
  http.delete(`${BASE}/listings/:listingId`, () =>
    new HttpResponse(null, { status: 204 })
  ),
];
```

```typescript
// src/mocks/server.ts
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

```typescript
// src/mocks/browser.ts (for dev mode)
import { setupWorker } from 'msw/browser';
import { handlers } from './handlers';

export const worker = setupWorker(...handlers);
```

---

## Testing Polling Behavior

```typescript
// src/hooks/useMarketListings.test.ts
import { renderHook, waitFor, act } from '@testing-library/react';
import { useMarketListings } from './useMarketListings';
import { createTestWrapper } from '@/test/renderWithProviders';
import { server } from '@/mocks/server';
import { http, HttpResponse } from 'msw';

describe('useMarketListings', () => {
  it('fetches listings on mount', async () => {
    const { result } = renderHook(() => useMarketListings(), {
      wrapper: createTestWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(result.current.data).toHaveLength(mockListings.length);
  });

  it('re-fetches every 5 seconds', async () => {
    vi.useFakeTimers();
    const fetchSpy = vi.fn().mockResolvedValue(mockListings);
    server.use(http.get('*/market/listings', fetchSpy));

    const { result } = renderHook(() => useMarketListings(), {
      wrapper: createTestWrapper(),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(fetchSpy).toHaveBeenCalledTimes(1);

    // Advance 5 seconds — should trigger a refetch
    act(() => { vi.advanceTimersByTime(5_000); });
    await waitFor(() => expect(fetchSpy).toHaveBeenCalledTimes(2));

    vi.useRealTimers();
  });

  it('shows stale data while re-fetching', async () => {
    // First call returns initial data, second returns updated data
    let callCount = 0;
    server.use(
      http.get('*/market/listings', () => {
        callCount++;
        return HttpResponse.json(callCount === 1 ? mockListings : updatedListings);
      })
    );

    vi.useFakeTimers();
    const { result } = renderHook(() => useMarketListings(), {
      wrapper: createTestWrapper(),
    });

    await waitFor(() => expect(result.current.data).toEqual(mockListings));

    act(() => { vi.advanceTimersByTime(5_000); });

    // Data from first fetch still visible (not undefined) while refetching
    expect(result.current.data).toEqual(mockListings);
    await waitFor(() => expect(result.current.data).toEqual(updatedListings));

    vi.useRealTimers();
  });
});
```

---

## Testing WebSocket Event Handlers

```typescript
// src/providers/WebSocketProvider.test.tsx
import { render, waitFor } from '@testing-library/react';
import { WebSocketProvider } from './WebSocketProvider';
import { queryClient } from './QueryProvider';
import { queryKeys } from '@/api/queryKeys';

// Minimal WebSocket mock
class MockWebSocket {
  static instance: MockWebSocket;
  onopen: (() => void) | null = null;
  onmessage: ((e: { data: string }) => void) | null = null;
  onclose: (() => void) | null = null;
  onerror: (() => void) | null = null;
  close = vi.fn();

  constructor() { MockWebSocket.instance = this; }

  simulateOpen()    { this.onopen?.(); }
  simulateMessage(data: object) { this.onmessage?.({ data: JSON.stringify(data) }); }
  simulateClose()   { this.onclose?.(); }
}

vi.stubGlobal('WebSocket', MockWebSocket);

describe('WebSocketProvider — cache invalidation', () => {
  beforeEach(() => {
    vi.spyOn(queryClient, 'invalidateQueries');
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  function setup() {
    return render(
      <WebSocketProvider>
        <div />
      </WebSocketProvider>,
      { wrapper: createAuthenticatedWrapper() }
    );
  }

  it('invalidates market listings on trade.completed', async () => {
    setup();
    MockWebSocket.instance.simulateOpen();

    MockWebSocket.instance.simulateMessage({
      type: 'trade.completed',
      payload: { buyerId: 'trader-1', sellerId: 'trader-2' },
    });

    await waitFor(() => {
      expect(queryClient.invalidateQueries).toHaveBeenCalledWith(
        expect.objectContaining({ queryKey: queryKeys.market.listings() })
      );
    });
  });

  it('invalidates leaderboard on trade.completed', async () => {
    setup();
    MockWebSocket.instance.simulateOpen();
    MockWebSocket.instance.simulateMessage({ type: 'trade.completed', payload: {} });

    await waitFor(() => {
      expect(queryClient.invalidateQueries).toHaveBeenCalledWith(
        expect.objectContaining({ queryKey: queryKeys.leaderboard() })
      );
    });
  });

  it('shows ConnectionLostBanner after 3 failed reconnect attempts', async () => {
    vi.useFakeTimers();
    const { getByRole } = setup();
    MockWebSocket.instance.simulateOpen();

    // Simulate 3 connection drops
    for (let i = 0; i < 3; i++) {
      MockWebSocket.instance.simulateClose();
      act(() => vi.advanceTimersByTime(16_000));
      await waitFor(() => MockWebSocket.instance); // new instance created
    }
    MockWebSocket.instance.simulateClose(); // 4th close → max retries exceeded

    await waitFor(() => {
      expect(getByRole('alert')).toBeInTheDocument();
    });

    vi.useRealTimers();
  });
});
```

---

## Testing Auth Flows

```typescript
// src/components/PrivateRoute.test.tsx
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/renderWithProviders';
import { PrivateRoute } from './PrivateRoute';
import { Route, Routes } from 'react-router-dom';

describe('PrivateRoute', () => {
  it('redirects unauthenticated users to /login', () => {
    renderWithProviders(
      <Routes>
        <Route path="/dashboard" element={<PrivateRoute />}>
          <Route index element={<div>Dashboard content</div>} />
        </Route>
        <Route path="/login" element={<div>Login page</div>} />
      </Routes>,
      {
        auth: { isAuthenticated: false },
        routerProps: { initialEntries: ['/dashboard'] },
      }
    );

    expect(screen.getByText('Login page')).toBeInTheDocument();
    expect(screen.queryByText('Dashboard content')).not.toBeInTheDocument();
  });

  it('renders protected content for authenticated users', () => {
    renderWithProviders(
      <Routes>
        <Route element={<PrivateRoute />}>
          <Route path="/dashboard" element={<div>Dashboard content</div>} />
        </Route>
      </Routes>,
      {
        auth: { isAuthenticated: true, traderId: 'trader-1' },
        routerProps: { initialEntries: ['/dashboard'] },
      }
    );

    expect(screen.getByText('Dashboard content')).toBeInTheDocument();
  });
});
```

---

## Testing Bid Placement with Optimistic Updates

```typescript
// src/hooks/usePlaceBid.test.ts
import { renderHook, act, waitFor } from '@testing-library/react';
import { usePlaceBid } from './usePlaceBid';
import { server } from '@/mocks/server';
import { http, HttpResponse } from 'msw';

describe('usePlaceBid', () => {
  it('optimistically adds bid to listings cache', async () => {
    // Seed initial cache state
    const queryClient = createTestQueryClient();
    queryClient.setQueryData(queryKeys.market.listings(), mockListings);

    const { result } = renderHook(() => usePlaceBid(), {
      wrapper: createTestWrapper({ queryClient }),
    });

    act(() => {
      result.current.mutate({ listingId: 'listing-1' as ListingId, amount: 25 });
    });

    // Optimistic update should be applied before the server responds
    const listings = queryClient.getQueryData<MarketListing[]>(queryKeys.market.listings());
    const updated = listings?.find((l) => l.listingId === 'listing-1');
    expect(updated?.myBid?.status).toBe('active');
    expect(updated?.myBid?.amount).toBe(25);
  });

  it('rolls back optimistic update on server error', async () => {
    server.use(
      http.post('*/listings/listing-1/bids', () =>
        HttpResponse.json({ error: 'Insufficient cash' }, { status: 422 })
      )
    );

    const queryClient = createTestQueryClient();
    queryClient.setQueryData(queryKeys.market.listings(), mockListings);

    const { result } = renderHook(() => usePlaceBid(), {
      wrapper: createTestWrapper({ queryClient }),
    });

    act(() => {
      result.current.mutate({ listingId: 'listing-1' as ListingId, amount: 25 });
    });

    await waitFor(() => expect(result.current.isError).toBe(true));

    // Cache should be rolled back to original
    const listings = queryClient.getQueryData<MarketListing[]>(queryKeys.market.listings());
    const unchanged = listings?.find((l) => l.listingId === 'listing-1');
    expect(unchanged?.myBid).toBeUndefined();
  });
});
```

---

## Testing Component Behavior (Preferred over Snapshots)

```typescript
// src/components/ListingCard/ListingCard.test.tsx
describe('ListingCard', () => {
  it('disables bid form for own listings', () => {
    const { getByText } = renderWithProviders(
      <ListingCard
        listing={{ ...mockListing, traderId: 'trader-1' as TraderId }}
        isOwnListing={true}
      />,
      { auth: { isAuthenticated: true, traderId: 'trader-1' } }
    );

    expect(screen.queryByRole('textbox', { name: /bid amount/i })).not.toBeInTheDocument();
    expect(getByText("You can't bid on your own listing")).toBeInTheDocument();
  });

  it('shows only the current user\'s bid status', () => {
    renderWithProviders(
      <ListingCard listing={mockListingWithMyBid} isOwnListing={false} />,
      { auth: { isAuthenticated: true, traderId: 'trader-2' } }
    );

    // Shows own bid
    expect(screen.getByText(/your bid/i)).toBeInTheDocument();
    // Does NOT show other bidders
    expect(screen.queryByText(/competing bid/i)).not.toBeInTheDocument();
  });
});
```

---

## Coverage Targets

| Scope | Target |
|---|---|
| `src/hooks/` (business logic) | 80%+ lines |
| `src/api/` (mappers, client) | 80%+ lines |
| `src/utils/` (pure functions) | 90%+ lines |
| Overall project | 70%+ lines |

---

## GitHub Actions Test Job

```yaml
# .github/workflows/ci.yml (test job excerpt)
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
    - run: npm ci
    - run: npm run lint
    - run: npm run type-check
    - run: npm run test -- --coverage --reporter=verbose
    - uses: actions/upload-artifact@v4
      if: always()
      with:
        name: coverage-report
        path: coverage/
```

Scripts in `package.json`:

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "coverage": "vitest run --coverage",
    "type-check": "tsc --noEmit",
    "lint": "eslint src --max-warnings 0"
  }
}
```
