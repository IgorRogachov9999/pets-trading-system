# Deployment Reference

Deep guidance for Vite build, S3+CloudFront hosting, and GitHub Actions CI/CD for the Pets Trading System frontend.

---

## Vite Production Build Config

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { visualizer } from 'rollup-plugin-visualizer';

export default defineConfig(({ mode }) => ({
  plugins: [
    react(),
    // Bundle analysis — generates stats.html in dist/ (dev only)
    mode === 'analyze' && visualizer({
      open: true,
      filename: 'dist/stats.html',
      gzipSize: true,
      brotliSize: true,
    }),
  ],
  resolve: {
    alias: { '@': '/src' },
  },
  build: {
    target: 'es2022',
    sourcemap: mode === 'production' ? false : true,
    rollupOptions: {
      output: {
        // Manual chunk splitting strategy
        manualChunks: (id) => {
          // Vendor: React ecosystem
          if (id.includes('node_modules/react') ||
              id.includes('node_modules/react-dom') ||
              id.includes('node_modules/react-router-dom') ||
              id.includes('node_modules/scheduler')) {
            return 'vendor-react';
          }
          // Vendor: TanStack Query
          if (id.includes('@tanstack')) {
            return 'vendor-tanstack';
          }
          // Vendor: AWS Amplify auth
          if (id.includes('@aws-amplify') || id.includes('amazon-cognito-identity-js')) {
            return 'vendor-auth';
          }
          // Route-level lazy chunks are handled by dynamic imports below
        },
        // Content-hashed filenames for long-lived CDN caching
        entryFileNames: 'assets/[name]-[hash].js',
        chunkFileNames: 'assets/[name]-[hash].js',
        assetFileNames: 'assets/[name]-[hash][extname]',
      },
    },
    // Warn when any chunk exceeds 500 KB (before gzip)
    chunkSizeWarningLimit: 500,
  },
}));
```

### Lazy Route Setup (code splitting per view)

```typescript
// src/App.tsx
const MarketPage      = React.lazy(() => import('@/pages/MarketPage'));
const DashboardPage   = React.lazy(() => import('@/pages/DashboardPage'));
const AnalysisPage    = React.lazy(() => import('@/pages/AnalysisPage'));
const LeaderboardPage = React.lazy(() => import('@/pages/LeaderboardPage'));
const LoginPage       = React.lazy(() => import('@/pages/LoginPage'));
```

Each page is its own chunk. Initial page load only downloads the `vendor-react` + `vendor-tanstack`
+ the specific page chunk. Subsequent navigation is instantaneous if the chunk is already cached.

---

## Environment Variables

All `VITE_` prefixed variables are embedded at build time (not runtime). They are public — do not
put secrets in them.

| Variable | Purpose | Example |
|---|---|---|
| `VITE_API_BASE_URL` | REST API base URL | `https://api.example.com/v1` |
| `VITE_WS_URL` | WebSocket endpoint | `wss://abc123.execute-api.us-east-1.amazonaws.com/prod` |
| `VITE_COGNITO_USER_POOL_ID` | Cognito user pool | `us-east-1_AbCdEfGhI` |
| `VITE_COGNITO_CLIENT_ID` | Cognito app client | `1abc2defg3hij4klmno5pqrst` |
| `VITE_COGNITO_REGION` | AWS region | `us-east-1` |

**Local development**: copy `.env.example` to `.env.local` and fill in values. `.env.local` is gitignored.

**GitHub Actions**: set as repository secrets, then pass to the build step:

```yaml
- name: Build
  run: npm run build
  env:
    VITE_API_BASE_URL: ${{ secrets.VITE_API_BASE_URL }}
    VITE_WS_URL: ${{ secrets.VITE_WS_URL }}
    VITE_COGNITO_USER_POOL_ID: ${{ secrets.VITE_COGNITO_USER_POOL_ID }}
    VITE_COGNITO_CLIENT_ID: ${{ secrets.VITE_COGNITO_CLIENT_ID }}
    VITE_COGNITO_REGION: ${{ secrets.VITE_COGNITO_REGION }}
```

---

## S3 Deployment

### Bucket Policy (Static Website Hosting via CloudFront OAC)

The S3 bucket is **private**. CloudFront Origin Access Control (OAC) is used — never make the
bucket public or use OAI (legacy).

```bash
# Sync build output to S3
aws s3 sync dist/ "s3://${S3_BUCKET}" \
  --delete \
  --cache-control "no-cache,no-store,must-revalidate" \
  --exclude "assets/*"

# Long-lived cache for content-hashed assets
aws s3 sync dist/assets/ "s3://${S3_BUCKET}/assets/" \
  --cache-control "public,max-age=31536000,immutable"

# Explicit no-cache for index.html (ensure clients always get latest)
aws s3 cp dist/index.html "s3://${S3_BUCKET}/index.html" \
  --cache-control "no-cache,no-store,must-revalidate" \
  --content-type "text/html"
```

**Why separate sync for assets**: All `dist/assets/*` files have content hashes in their names
(`main-3f4a9b2c.js`). They can be cached forever because a changed file gets a new hash. The
root `index.html` must never be cached because it is the entry point that references the current
hashed assets.

---

## CloudFront Configuration

### Key Behaviors

| Setting | Value | Reason |
|---|---|---|
| Origin | S3 bucket (OAC) | Private S3, secure access |
| Default root object | `index.html` | SPA entry point |
| Compress objects | Yes | Brotli + gzip |
| Price class | Use only North America and Europe | Cost optimization for hackathon |
| HTTPS only | Yes | HTTP → HTTPS redirect |
| Custom error page | 404 → `/index.html` (HTTP 200) | SPA routing |

### Custom Error Page (SPA Routing)

Without this, refreshing `/dashboard` returns a 404 (S3 doesn't have a `/dashboard` file).
CloudFront intercepts the 404 and serves `index.html` with HTTP 200 instead:

```json
{
  "ErrorCode": 404,
  "ResponseCode": "200",
  "ResponsePagePath": "/index.html",
  "ErrorCachingMinTTL": 0
}
```

Also add a rule for 403 (S3 returns 403 for missing objects when the bucket is private):

```json
{
  "ErrorCode": 403,
  "ResponseCode": "200",
  "ResponsePagePath": "/index.html",
  "ErrorCachingMinTTL": 0
}
```

### CloudFront Invalidation After Deploy

After every deployment, invalidate only what changed. Invalidating `/*` is expensive and
unnecessary for content-hashed assets (they are already new URLs):

```bash
aws cloudfront create-invalidation \
  --distribution-id "${CF_DISTRIBUTION_ID}" \
  --paths "/index.html"
```

Only `index.html` needs invalidation — the new `index.html` references the new hashed asset
filenames, so browsers will fetch the new assets automatically.

---

## GitHub Actions CI/CD Workflow

```yaml
# .github/workflows/frontend.yml
name: Frontend CI/CD

on:
  push:
    branches: [main]
    paths: ['frontend/**', '.github/workflows/frontend.yml']
  pull_request:
    branches: [main]
    paths: ['frontend/**']

permissions:
  id-token: write   # Required for OIDC
  contents: read

jobs:
  test:
    name: Lint, Type-check & Test
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: 'frontend/package-lock.json'
      - run: npm ci
      - run: npm run lint
      - run: npm run type-check
      - run: npm run test -- --coverage --reporter=verbose
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage
          path: frontend/coverage/

  build-and-deploy:
    name: Build & Deploy
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: 'frontend/package-lock.json'

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ secrets.VITE_COGNITO_REGION }}

      - run: npm ci

      - name: Build
        run: npm run build
        env:
          VITE_API_BASE_URL:          ${{ secrets.VITE_API_BASE_URL }}
          VITE_WS_URL:                ${{ secrets.VITE_WS_URL }}
          VITE_COGNITO_USER_POOL_ID:  ${{ secrets.VITE_COGNITO_USER_POOL_ID }}
          VITE_COGNITO_CLIENT_ID:     ${{ secrets.VITE_COGNITO_CLIENT_ID }}
          VITE_COGNITO_REGION:        ${{ secrets.VITE_COGNITO_REGION }}

      - name: Sync hashed assets (long-lived cache)
        run: |
          aws s3 sync dist/assets/ "s3://${{ secrets.S3_BUCKET }}/assets/" \
            --cache-control "public,max-age=31536000,immutable"

      - name: Sync root files (no-cache)
        run: |
          aws s3 sync dist/ "s3://${{ secrets.S3_BUCKET }}" \
            --exclude "assets/*" \
            --delete \
            --cache-control "no-cache,no-store,must-revalidate"

      - name: Invalidate CloudFront index.html
        run: |
          aws cloudfront create-invalidation \
            --distribution-id "${{ secrets.CF_DISTRIBUTION_ID }}" \
            --paths "/index.html"

  preview:
    name: Branch Preview Deploy
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: 'frontend/package-lock.json'

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ secrets.VITE_COGNITO_REGION }}

      - run: npm ci

      - name: Build (preview env)
        run: npm run build
        env:
          VITE_API_BASE_URL:          ${{ secrets.VITE_API_BASE_URL_STAGING }}
          VITE_WS_URL:                ${{ secrets.VITE_WS_URL_STAGING }}
          VITE_COGNITO_USER_POOL_ID:  ${{ secrets.VITE_COGNITO_USER_POOL_ID }}
          VITE_COGNITO_CLIENT_ID:     ${{ secrets.VITE_COGNITO_CLIENT_ID }}
          VITE_COGNITO_REGION:        ${{ secrets.VITE_COGNITO_REGION }}

      - name: Deploy to preview path
        run: |
          BRANCH="${{ github.head_ref }}"
          SLUG="${BRANCH//\//-}"
          aws s3 sync dist/ "s3://${{ secrets.S3_BUCKET }}/previews/${SLUG}/" \
            --delete
          echo "Preview URL: https://${{ secrets.CF_DOMAIN }}/previews/${SLUG}/"
```

---

## OIDC Role Configuration (no static AWS credentials)

GitHub Actions never stores `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`. Instead, OIDC allows
the workflow to assume an IAM role:

```json
// IAM Role trust policy
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/pets-trading-system:ref:refs/heads/main"
      }
    }
  }]
}
```

```json
// IAM Role permissions policy (least privilege)
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::your-frontend-bucket",
        "arn:aws:s3:::your-frontend-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "cloudfront:CreateInvalidation",
      "Resource": "arn:aws:cloudfront::ACCOUNT_ID:distribution/YOUR_DISTRIBUTION_ID"
    }
  ]
}
```

---

## Rollback Strategy

**Option 1: S3 Versioning** (recommended)
Enable versioning on the S3 bucket. Rolling back means restoring the previous `index.html` version
and re-invalidating CloudFront:

```bash
# List versions
aws s3api list-object-versions --bucket your-bucket --prefix index.html

# Restore specific version
aws s3api copy-object \
  --bucket your-bucket \
  --copy-source "your-bucket/index.html?versionId=PREV_VERSION_ID" \
  --key index.html \
  --cache-control "no-cache,no-store,must-revalidate"

# Invalidate
aws cloudfront create-invalidation --distribution-id DIST_ID --paths "/index.html"
```

**Option 2: Tagged S3 Prefixes**
Before each deploy, snapshot the current `dist/` to `s3://bucket/releases/<git-sha>/`. Roll back
by syncing from a previous release prefix to the root.

---

## Bundle Size Budget

Track bundle size in CI to catch regressions:

```yaml
# In build job, after npm run build:
- name: Check bundle size
  run: |
    MAIN_BUNDLE=$(ls dist/assets/index-*.js | head -1)
    SIZE=$(stat -f%z "$MAIN_BUNDLE" 2>/dev/null || stat -c%s "$MAIN_BUNDLE")
    echo "Main bundle: ${SIZE} bytes"
    # Fail if over 200KB gzipped (approximately 600KB raw)
    if [ "$SIZE" -gt 614400 ]; then
      echo "ERROR: Main bundle exceeds 600KB"
      exit 1
    fi
```
