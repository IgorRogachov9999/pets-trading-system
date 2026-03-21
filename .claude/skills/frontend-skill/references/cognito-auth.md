# Cognito Auth Reference

Deep guidance for Amazon Cognito authentication in the Pets Trading System frontend.

---

## Setup: AWS Amplify v6

Use `@aws-amplify/auth` (Amplify v6+). It is tree-shakeable — only auth is imported, not the full
Amplify library.

```bash
npm install @aws-amplify/auth
```

```typescript
// src/main.tsx (or src/amplify-config.ts imported before render)
import { Amplify } from 'aws-amplify';

Amplify.configure({
  Auth: {
    Cognito: {
      userPoolId: import.meta.env.VITE_COGNITO_USER_POOL_ID,
      userPoolClientId: import.meta.env.VITE_COGNITO_CLIENT_ID,
      loginWith: { email: true },
    },
  },
});
```

Alternatively use `amazon-cognito-identity-js` directly for finer control with no Amplify
dependency overhead.

---

## JWT Storage: In-Memory Only

**Never** write tokens to `localStorage` or `sessionStorage`. XSS can read both.
Tokens live exclusively in React state via `AuthContext`.

```typescript
// src/providers/AuthProvider.tsx
import React from 'react';
import {
  signIn,
  signOut,
  fetchAuthSession,
  getCurrentUser,
} from '@aws-amplify/auth';
import type { TraderId } from '@/types/brands';

interface AuthTokens {
  accessToken: string;
  idToken: string;
  expiresAt: number; // Unix timestamp (ms)
}

export interface AuthContextValue {
  isAuthenticated: boolean;
  traderId: TraderId | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  getIdToken: () => string | null;
  getAccessToken: () => string | null;
}

const AuthContext = React.createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [tokens, setTokens] = React.useState<AuthTokens | null>(null);
  const [traderId, setTraderId] = React.useState<TraderId | null>(null);
  const refreshTimerRef = React.useRef<ReturnType<typeof setTimeout> | null>(null);
  const [sessionExpired, setSessionExpired] = React.useState(false);

  // Schedule silent refresh 60 seconds before expiry
  const scheduleRefresh = React.useCallback((expiresAt: number) => {
    if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current);
    const msUntilRefresh = expiresAt - Date.now() - 60_000;
    if (msUntilRefresh <= 0) {
      void performRefresh();
      return;
    }
    refreshTimerRef.current = setTimeout(() => void performRefresh(), msUntilRefresh);
  }, []);

  const performRefresh = React.useCallback(async () => {
    try {
      const session = await fetchAuthSession({ forceRefresh: true });
      const idToken = session.tokens?.idToken?.toString();
      const accessToken = session.tokens?.accessToken?.toString();
      const exp = session.tokens?.idToken?.payload?.exp as number | undefined;

      if (!idToken || !accessToken || !exp) throw new Error('Incomplete token refresh');

      const expiresAt = exp * 1000;
      setTokens({ idToken, accessToken, expiresAt });
      scheduleRefresh(expiresAt);
    } catch {
      setTokens(null);
      setTraderId(null);
      setSessionExpired(true);
    }
  }, [scheduleRefresh]);

  // On mount: restore session if Cognito has a valid refresh token
  React.useEffect(() => {
    void (async () => {
      try {
        const session = await fetchAuthSession();
        const idToken = session.tokens?.idToken?.toString();
        const accessToken = session.tokens?.accessToken?.toString();
        const exp = session.tokens?.idToken?.payload?.exp as number | undefined;
        const sub = session.tokens?.idToken?.payload?.sub as string | undefined;

        if (idToken && accessToken && exp && sub) {
          const expiresAt = exp * 1000;
          setTokens({ idToken, accessToken, expiresAt });
          setTraderId(sub as TraderId);
          scheduleRefresh(expiresAt);
        }
      } catch {
        // No active session — user needs to log in
      }
    })();

    return () => {
      if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current);
    };
  }, [scheduleRefresh]);

  const login = React.useCallback(async (email: string, password: string) => {
    await signIn({ username: email, password });
    const session = await fetchAuthSession();
    const idToken = session.tokens?.idToken?.toString();
    const accessToken = session.tokens?.accessToken?.toString();
    const exp = session.tokens?.idToken?.payload?.exp as number | undefined;
    const sub = session.tokens?.idToken?.payload?.sub as string | undefined;

    if (!idToken || !accessToken || !exp || !sub) throw new Error('Auth failed: incomplete tokens');

    const expiresAt = exp * 1000;
    setTokens({ idToken, accessToken, expiresAt });
    setTraderId(sub as TraderId);
    scheduleRefresh(expiresAt);
  }, [scheduleRefresh]);

  const logout = React.useCallback(async () => {
    if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current);
    await signOut();
    setTokens(null);
    setTraderId(null);
  }, []);

  const getIdToken = React.useCallback(() => tokens?.idToken ?? null, [tokens]);
  const getAccessToken = React.useCallback(() => tokens?.accessToken ?? null, [tokens]);

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated: !!tokens && Date.now() < tokens.expiresAt,
        traderId,
        login,
        logout,
        getIdToken,
        getAccessToken,
      }}
    >
      {sessionExpired && (
        <SessionExpiredModal onDismiss={() => setSessionExpired(false)} />
      )}
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = React.useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}
```

---

## API Request Authentication

Attach the ID token to every API request via a centralized `api` client:

```typescript
// src/api/client.ts
import axios from 'axios';
import { queryClient } from '@/providers/QueryProvider';

const BASE_URL = import.meta.env.VITE_API_BASE_URL as string;

export const apiClient = axios.create({ baseURL: BASE_URL });

// This interceptor is wired up in AuthProvider after tokens are available
export function attachAuthInterceptor(getIdToken: () => string | null) {
  apiClient.interceptors.request.use((config) => {
    const token = getIdToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  });
}

// Convenience wrappers
export const api = {
  get: <T>(url: string) => apiClient.get<T>(url).then((r) => r.data),
  post: <T>(url: string, data?: unknown) => apiClient.post<T>(url, data).then((r) => r.data),
  put: <T>(url: string, data?: unknown) => apiClient.put<T>(url, data).then((r) => r.data),
  delete: (url: string) => apiClient.delete(url).then((r) => r.data),
};
```

Wire the interceptor in `AuthProvider` after the token state is set:

```typescript
// Inside AuthProvider, after tokens are populated:
React.useEffect(() => {
  attachAuthInterceptor(getIdToken);
}, [getIdToken]);
```

---

## WebSocket Authentication

Pass the ID token as a query parameter at connection time (API Gateway WebSocket does not support
custom headers on the `GET /connect` handshake):

```typescript
const idToken = getIdToken();
const ws = new WebSocket(`${WS_BASE_URL}?token=${encodeURIComponent(idToken ?? '')}`);
```

The token is validated by the API Gateway Cognito authorizer on `$connect`. If the token is
invalid or missing, the connection is rejected with a `401`.

**Token rotation for long-lived connections**: After a silent refresh, there is no need to
reconnect — the existing WebSocket session remains authenticated. The token is only checked at
connect time.

---

## Protected Route Pattern (React Router v6)

```typescript
// src/components/PrivateRoute.tsx
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '@/providers/AuthProvider';

export function PrivateRoute(): React.ReactElement {
  const { isAuthenticated } = useAuth();
  const location = useLocation();

  if (!isAuthenticated) {
    // Preserve the attempted URL for post-login redirect
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <Outlet />;
}
```

```typescript
// src/App.tsx — route configuration
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { PrivateRoute } from '@/components/PrivateRoute';
import React from 'react';

const MarketPage      = React.lazy(() => import('@/pages/MarketPage'));
const DashboardPage   = React.lazy(() => import('@/pages/DashboardPage'));
const AnalysisPage    = React.lazy(() => import('@/pages/AnalysisPage'));
const LeaderboardPage = React.lazy(() => import('@/pages/LeaderboardPage'));
const LoginPage       = React.lazy(() => import('@/pages/LoginPage'));

export function App() {
  return (
    <BrowserRouter>
      <React.Suspense fallback={<PageSkeleton />}>
        <Routes>
          {/* Public routes */}
          <Route path="/login" element={<LoginPage />} />
          <Route path="/market" element={<MarketPage />} />
          <Route path="/leaderboard" element={<LeaderboardPage />} />

          {/* Protected routes */}
          <Route element={<PrivateRoute />}>
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/analysis/:petId" element={<AnalysisPage />} />
          </Route>

          <Route path="/" element={<Navigate to="/market" replace />} />
        </Routes>
      </React.Suspense>
    </BrowserRouter>
  );
}
```

Post-login redirect to the original intended URL:

```typescript
// src/pages/LoginPage.tsx
function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const from = (location.state as { from?: Location })?.from?.pathname ?? '/dashboard';

  async function handleSubmit(email: string, password: string) {
    await login(email, password);
    navigate(from, { replace: true });
  }
  // ...
}
```

---

## Logout Flow

```typescript
async function handleLogout() {
  // 1. Close WebSocket before clearing tokens (graceful disconnect)
  closeWebSocket();

  // 2. Clear in-memory tokens and call Cognito signOut (revokes refresh token)
  await logout();

  // 3. Clear TanStack Query cache (avoid leaking other users' data)
  queryClient.clear();

  // 4. Redirect to login
  navigate('/login', { replace: true });
}
```

---

## Session Expired Modal

```typescript
// src/components/SessionExpiredModal.tsx
interface Props { onDismiss: () => void }

export function SessionExpiredModal({ onDismiss }: Props): React.ReactElement {
  const navigate = useNavigate();

  function handleLogin() {
    onDismiss();
    navigate('/login', { replace: true });
  }

  return (
    <div role="dialog" aria-modal="true" aria-labelledby="session-expired-title">
      <h2 id="session-expired-title">Your session has expired</h2>
      <p>Please log in again to continue trading.</p>
      <button onClick={handleLogin} autoFocus>
        Log in again
      </button>
    </div>
  );
}
```

---

## Environment Variables

| Variable | Example |
|---|---|
| `VITE_COGNITO_USER_POOL_ID` | `us-east-1_AbCdEfGhI` |
| `VITE_COGNITO_CLIENT_ID` | `1abc2defg3hij4klmno5pqrst` |
| `VITE_COGNITO_REGION` | `us-east-1` |

All are injected at build time — they are public (client-side). Never put Cognito client secrets
in environment variables (Cognito app clients for SPAs should have no client secret).
