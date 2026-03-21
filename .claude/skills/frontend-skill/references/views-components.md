# Views & Components Reference

Deep guidance for the 4 required views of the Pets Trading System frontend.

---

## View Overview

| View | Route | Auth | Polling | WS Triggers |
|---|---|---|---|---|
| Trader Panel | `/dashboard` | Required | portfolio 5s | `bid.received`, `bid.accepted`, `bid.rejected`, `outbid`, `trade.completed`, `listing.withdrawn` |
| Market View | `/market` | Optional | listings 5s | `trade.completed`, `listing.withdrawn` |
| Analysis | `/analysis/:petId` | Optional | pet data 5s | none |
| Leaderboard | `/leaderboard` | Optional | 5s | `trade.completed` |

---

## View 1: Trader Panel (`/dashboard`)

### Route Setup

```tsx
// Protected route — must be authenticated
<Route element={<PrivateRoute />}>
  <Route path="/dashboard" element={<DashboardPage />} />
</Route>
```

### Page Structure

```tsx
// src/pages/DashboardPage.tsx
export default function DashboardPage(): React.ReactElement {
  return (
    <main aria-label="Trader dashboard">
      <ErrorBoundary fallback={<SectionError name="Portfolio" />}>
        <CashDisplay />
      </ErrorBoundary>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mt-6">
        <div className="lg:col-span-2">
          <ErrorBoundary fallback={<SectionError name="Inventory" />}>
            <React.Suspense fallback={<InventorySkeleton />}>
              <InventoryGrid />
            </React.Suspense>
          </ErrorBoundary>
        </div>
        <aside>
          <ErrorBoundary fallback={<SectionError name="Notifications" />}>
            <NotificationFeed />
          </ErrorBoundary>
        </aside>
      </div>
    </main>
  );
}
```

### CashDisplay Component

```tsx
// src/components/CashDisplay/CashDisplay.tsx
export function CashDisplay(): React.ReactElement {
  const { traderId } = useAuth();
  const { data: portfolio } = useTraderPortfolio(traderId!);

  return (
    <div className="grid grid-cols-3 gap-4 p-4 bg-white rounded-lg shadow-sm">
      <Stat label="Available Cash" value={portfolio?.availableCash} format="currency" />
      <Stat label="Locked (Active Bids)" value={portfolio?.lockedCash} format="currency"
            tooltip="Cash reserved for your active bids" />
      <Stat label="Portfolio Value" value={portfolio?.portfolioValue} format="currency"
            highlight />
    </div>
  );
}

// portfolioValue = availableCash + lockedCash + sum(intrinsicValue of owned pets)
// Display all three — never aggregate without showing the breakdown
```

### InventoryGrid Component

```tsx
// src/components/InventoryGrid/InventoryGrid.tsx
export function InventoryGrid(): React.ReactElement {
  const { traderId } = useAuth();
  const { data: inventory } = useSuspenseQuery({
    queryKey: queryKeys.trader.inventory(traderId!),
    queryFn: () => api.get<Pet[]>(`/traders/${traderId}/inventory`),
    refetchInterval: 5_000,
  });

  if (inventory.length === 0) {
    return (
      <section aria-label="Inventory">
        <h2 className="text-lg font-semibold">My Pets</h2>
        <EmptyState message="You don't own any pets yet. Visit the market to buy some!" />
      </section>
    );
  }

  return (
    <section aria-label="Inventory">
      <h2 className="text-lg font-semibold">My Pets ({inventory.length})</h2>
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mt-4">
        {inventory.map((pet) => (
          <PetInventoryCard key={pet.petId} pet={pet} />
        ))}
      </div>
    </section>
  );
}
```

### NotificationFeed Component

Notifications are pushed via WebSocket events; the feed re-queries from server on each push.

```tsx
// src/components/NotificationFeed/NotificationFeed.tsx
export function NotificationFeed(): React.ReactElement {
  const { traderId } = useAuth();
  const { data: notifications = [] } = useTraderNotifications(traderId!);

  return (
    <section aria-label="Notifications" aria-live="polite" aria-atomic="false">
      <h2 className="text-lg font-semibold mb-3">Notifications</h2>
      {notifications.length === 0 ? (
        <p className="text-gray-500 text-sm">No notifications yet.</p>
      ) : (
        <ul className="space-y-2 max-h-96 overflow-y-auto">
          {notifications.map((notif) => (
            <NotificationItem key={notif.notificationId} notification={notif} />
          ))}
        </ul>
      )}
    </section>
  );
}

// Notification types and icons
const NOTIFICATION_CONFIG: Record<NotificationType, { icon: string; color: string; label: string }> = {
  'bid.received':      { icon: '📥', color: 'text-blue-600',   label: 'Bid received' },
  'bid.accepted':      { icon: '✅', color: 'text-green-600',  label: 'Bid accepted' },
  'bid.rejected':      { icon: '❌', color: 'text-red-600',    label: 'Bid rejected' },
  'outbid':            { icon: '⬆️', color: 'text-orange-500', label: 'Outbid' },
  'trade.completed':   { icon: '🤝', color: 'text-green-700',  label: 'Trade completed' },
  'listing.withdrawn': { icon: '↩️', color: 'text-gray-500',   label: 'Listing withdrawn' },
};
```

---

## View 2: Market View (`/market`)

### Page Structure

```tsx
// src/pages/MarketPage.tsx
export default function MarketPage(): React.ReactElement {
  return (
    <main aria-label="Pet market">
      <ErrorBoundary fallback={<SectionError name="New Supply" />}>
        <NewSupplyBanner />
      </ErrorBoundary>
      <ErrorBoundary fallback={<SectionError name="Listings" />}>
        <React.Suspense fallback={<ListingsSkeleton />}>
          <ListingsGrid />
        </React.Suspense>
      </ErrorBoundary>
    </main>
  );
}
```

### ListingsGrid

```tsx
// src/components/ListingsGrid/ListingsGrid.tsx
export function ListingsGrid(): React.ReactElement {
  const { data: listings } = useMarketListings(); // polls every 5s
  const { traderId } = useAuth();

  // Sort: newest first (by listing creation date)
  const sorted = React.useMemo(
    () => [...(listings ?? [])].sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    ),
    [listings]
  );

  return (
    <section aria-label="Active listings">
      <h2 className="text-xl font-semibold mb-4">
        Active Listings ({sorted.length})
      </h2>
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {sorted.map((listing) => (
          <ListingCard
            key={listing.listingId}
            listing={listing}
            isOwnListing={listing.traderId === traderId}
          />
        ))}
      </div>
    </section>
  );
}
```

### ListingCard — Bid Form Rules

```tsx
// src/components/ListingCard/ListingCard.tsx
interface ListingCardProps {
  listing: MarketListing;
  isOwnListing: boolean;
}

export function ListingCard({ listing, isOwnListing }: ListingCardProps): React.ReactElement {
  const [bidAmount, setBidAmount] = React.useState('');
  const { data: portfolio } = useTraderPortfolio(traderId!);
  const placeBid = usePlaceBid();

  const canBid = !isOwnListing && !!traderId;
  const hasEnoughCash = portfolio ? Number(bidAmount) <= portfolio.availableCash : false;
  const bidDisabledReason = isOwnListing
    ? "You can't bid on your own listing"
    : !traderId
    ? 'Log in to place a bid'
    : !hasEnoughCash
    ? 'Insufficient available cash'
    : null;

  return (
    <article
      className="bg-white rounded-lg shadow-sm p-4 border border-gray-200"
      aria-label={`Listing: ${listing.breedName}`}
    >
      <PetBreedHeader breed={listing.breedName} species={listing.species} />

      <div className="mt-3 space-y-1 text-sm">
        <PriceRow label="Asking Price" amount={listing.askingPrice} />
        {listing.lastTradePrice && (
          <PriceRow label="Last Trade" amount={listing.lastTradePrice} muted />
        )}
        {listing.myBid && <MyBidStatus bid={listing.myBid} />}
      </div>

      {/* Bid form — disabled for own listings */}
      {canBid && (
        <form
          className="mt-4"
          onSubmit={(e) => {
            e.preventDefault();
            placeBid.mutate({ listingId: listing.listingId, amount: Number(bidAmount) });
          }}
        >
          <div className="flex gap-2">
            <input
              type="number"
              min={1}
              step={0.01}
              value={bidAmount}
              onChange={(e) => setBidAmount(e.target.value)}
              placeholder="Your bid"
              aria-label="Bid amount"
              className="flex-1 border rounded px-2 py-1 text-sm"
            />
            <button
              type="submit"
              disabled={!hasEnoughCash || placeBid.isPending || !bidAmount}
              aria-disabled={!hasEnoughCash}
              className="px-3 py-1 bg-indigo-600 text-white rounded text-sm disabled:opacity-50"
            >
              {placeBid.isPending ? 'Placing…' : 'Bid'}
            </button>
          </div>
          {!hasEnoughCash && bidAmount && (
            <p role="alert" className="text-red-500 text-xs mt-1">
              Insufficient available cash
            </p>
          )}
        </form>
      )}

      {/* Own listing — show reason, no bid form */}
      {isOwnListing && (
        <p className="mt-3 text-xs text-gray-400 italic">
          {bidDisabledReason}
        </p>
      )}
    </article>
  );
}
```

---

## View 3: Analysis / Drill-Down (`/analysis/:petId`)

### Page Structure

```tsx
// src/pages/AnalysisPage.tsx
export default function AnalysisPage(): React.ReactElement {
  const { petId } = useParams<{ petId: string }>();

  return (
    <main aria-label="Pet analysis">
      <ErrorBoundary fallback={<SectionError name="Pet Analysis" />}>
        <React.Suspense fallback={<AnalysisSkeleton />}>
          <PetAnalysisView petId={petId as PetId} />
        </React.Suspense>
      </ErrorBoundary>
    </main>
  );
}
```

### PetAnalysisView

```tsx
function PetAnalysisView({ petId }: { petId: PetId }): React.ReactElement {
  const { data: pet } = usePetAnalysis(petId); // polls every 5s

  // Intrinsic value formula — computed client-side for display only
  // Server is authoritative; this is for illustration
  const intrinsicValue = computeIntrinsicValue(pet);
  const isExpired = pet.age >= pet.lifespan;

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div className="flex items-center gap-3">
        <h1 className="text-2xl font-bold">{pet.breedName}</h1>
        {isExpired && (
          <span
            className="px-2 py-0.5 bg-red-100 text-red-700 rounded text-sm font-medium"
            role="status"
          >
            Expired
          </span>
        )}
      </div>

      <IntrinsicValueGauge value={intrinsicValue} maxValue={pet.basePrice} />

      <section aria-label="Pet statistics">
        <h2 className="text-lg font-semibold mb-3">Statistics</h2>
        <div className="space-y-3">
          <StatBar label="Health" value={pet.health} max={100} color="green" />
          <StatBar label="Desirability" value={pet.desirability} max={10} color="blue" />
          <StatBar label="Age" value={pet.age} max={pet.lifespan} color={isExpired ? 'red' : 'amber'} />
        </div>
      </section>

      <section aria-label="Pet details">
        <dl className="grid grid-cols-2 gap-2 text-sm">
          <dt className="text-gray-500">Base Price</dt>
          <dd className="font-medium">${pet.basePrice.toFixed(2)}</dd>
          <dt className="text-gray-500">Intrinsic Value</dt>
          <dd className="font-medium">${intrinsicValue.toFixed(2)}</dd>
          <dt className="text-gray-500">Age / Lifespan</dt>
          <dd className="font-medium">{pet.age.toFixed(1)} / {pet.lifespan} ticks</dd>
        </dl>
      </section>
    </div>
  );
}

function computeIntrinsicValue(pet: PetAnalysis): number {
  const ageFactor = Math.max(0, 1 - pet.age / pet.lifespan);
  return pet.basePrice * (pet.health / 100) * (pet.desirability / 10) * ageFactor;
}
```

### IntrinsicValueGauge

```tsx
// src/components/IntrinsicValueGauge/IntrinsicValueGauge.tsx
interface Props { value: number; maxValue: number }

export function IntrinsicValueGauge({ value, maxValue }: Props): React.ReactElement {
  const pct = Math.min(100, (value / maxValue) * 100);
  const color = pct > 60 ? 'bg-green-500' : pct > 30 ? 'bg-amber-500' : 'bg-red-500';

  return (
    <div aria-label={`Intrinsic value: $${value.toFixed(2)} of $${maxValue.toFixed(2)} base`}>
      <div className="flex justify-between text-sm mb-1">
        <span className="font-medium">Intrinsic Value</span>
        <span className="font-bold text-lg">${value.toFixed(2)}</span>
      </div>
      <div className="w-full bg-gray-200 rounded-full h-3" role="progressbar"
           aria-valuenow={value} aria-valuemin={0} aria-valuemax={maxValue}>
        <div
          className={`h-3 rounded-full transition-all duration-500 ${color}`}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}
```

---

## View 4: Leaderboard (`/leaderboard`)

### Page Structure

```tsx
// src/pages/LeaderboardPage.tsx
export default function LeaderboardPage(): React.ReactElement {
  const [sortKey, setSortKey] = React.useState<'portfolioValue' | 'rank'>('portfolioValue');
  const [isPending, startTransition] = React.useTransition();

  return (
    <main aria-label="Trader leaderboard">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Leaderboard</h1>
        <LiveIndicator />
      </div>
      <ErrorBoundary fallback={<SectionError name="Leaderboard" />}>
        <React.Suspense fallback={<LeaderboardSkeleton />}>
          <div aria-busy={isPending} style={{ opacity: isPending ? 0.7 : 1 }}>
            <RankedTable sortKey={sortKey} />
          </div>
        </React.Suspense>
      </ErrorBoundary>
    </main>
  );
}
```

### RankedTable

```tsx
// src/components/RankedTable/RankedTable.tsx
export function RankedTable({ sortKey }: { sortKey: 'portfolioValue' | 'rank' }): React.ReactElement {
  const { traderId } = useAuth();
  const { data: traders } = useSuspenseQuery({
    queryKey: queryKeys.leaderboard(),
    queryFn: () => api.get<TraderRank[]>('/leaderboard'),
    refetchInterval: 5_000,
    staleTime: 4_000,
  });

  const sorted = React.useMemo(
    () => [...traders].sort((a, b) =>
      sortKey === 'portfolioValue'
        ? b.portfolioValue - a.portfolioValue
        : a.rank - b.rank
    ),
    [traders, sortKey]
  );

  return (
    <table className="w-full border-collapse">
      <caption className="sr-only">Trader portfolio leaderboard, sorted by {sortKey}</caption>
      <thead>
        <tr className="border-b border-gray-200 text-left text-sm text-gray-500">
          <th scope="col" className="py-2 pr-4 w-12">Rank</th>
          <th scope="col" className="py-2 pr-4">Trader</th>
          <th scope="col" className="py-2 text-right">Portfolio Value</th>
        </tr>
      </thead>
      <tbody>
        {sorted.map((trader, idx) => {
          const isCurrentUser = trader.traderId === traderId;
          return (
            <tr
              key={trader.traderId}
              className={cn(
                'border-b border-gray-100 text-sm',
                isCurrentUser && 'bg-indigo-50 font-semibold'
              )}
              aria-current={isCurrentUser ? 'true' : undefined}
            >
              <td className="py-3 pr-4">
                <span className="font-mono">{idx + 1}</span>
                {trader.rankChange !== 0 && (
                  <RankChangeIndicator change={trader.rankChange} />
                )}
              </td>
              <td className="py-3 pr-4">
                {trader.displayName}
                {isCurrentUser && <span className="ml-2 text-indigo-600 text-xs">(you)</span>}
              </td>
              <td className="py-3 text-right font-mono">
                ${trader.portfolioValue.toFixed(2)}
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}
```

---

## Shared Design Tokens (Tailwind)

```typescript
// tailwind.config.ts
import type { Config } from 'tailwindcss';

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          50:  '#eef2ff',
          600: '#4f46e5',
          700: '#4338ca',
        },
        success:  '#16a34a',
        warning:  '#d97706',
        danger:   '#dc2626',
      },
      animation: {
        'price-up':   'flashGreen 1s ease-out',
        'price-down': 'flashRed 1s ease-out',
        'bid-pulse':  'pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      },
    },
  },
} satisfies Config;
```

### Real-Time Visual Indicators

```tsx
// Flash green/red on price change using usePrevious hook
function PriceRow({ amount, label }: { amount: number; label: string }) {
  const prevAmount = usePrevious(amount);
  const direction = prevAmount === undefined ? null
    : amount > prevAmount ? 'up'
    : amount < prevAmount ? 'down'
    : null;

  return (
    <div className={cn(
      'flex justify-between',
      direction === 'up'   && 'animate-price-up',
      direction === 'down' && 'animate-price-down',
    )}>
      <span className="text-gray-500">{label}</span>
      <span className={cn(
        'font-mono font-medium',
        direction === 'up'   && 'text-green-600',
        direction === 'down' && 'text-red-600',
      )}>
        ${amount.toFixed(2)}
      </span>
    </div>
  );
}
```

---

## Navigation

```tsx
// src/components/Nav/Nav.tsx
export function Nav(): React.ReactElement {
  const { isAuthenticated, logout } = useAuth();

  return (
    <nav aria-label="Main navigation" className="flex items-center gap-6 px-6 py-3 bg-white shadow-sm">
      <NavLink to="/market">Market</NavLink>
      <NavLink to="/leaderboard">Leaderboard</NavLink>
      {isAuthenticated && <NavLink to="/dashboard">My Portfolio</NavLink>}
      {isAuthenticated
        ? <button onClick={() => void logout()} className="ml-auto text-sm text-gray-500 hover:text-gray-800">Log out</button>
        : <NavLink to="/login" className="ml-auto">Log in</NavLink>
      }
    </nav>
  );
}
```
