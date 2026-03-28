# iOS Backend

This backend supports two deployment shapes behind the same route contract:

- local Node server with JSON metadata and filesystem blobs
- Vercel API functions with Supabase metadata and Cloudflare R2 blobs

## What it implements

- `POST /v1/auth/sign-in/apple`
- `POST /v1/auth/refresh`
- `POST /v1/auth/sign-out`
- `POST /v1/auth/revoke`
- `POST /v1/me/delete`
- `GET /v1/me`
- `GET /v1/me/entitlements`
- `POST /v1/iap/apple/sync`
- `POST /v1/iap/apple/restore`
- `GET /v1/catalog/models`
- `GET /v1/app/config`
- `POST /v1/jobs`
- `GET /v1/jobs`
- `GET /v1/jobs/:id`
- `POST /v1/jobs/:id/cancel`
- `POST /v1/uploads`
- `GET /v1/uploads/:id/content`

## Behavior

- Uses opaque bearer tokens.
- Treats Apple sign-in exchange and IAP sync as stubbed backend-owned flows until real Apple verification is added.
- Keeps the route contract stable across local and deployed environments.
- Generates simple SVG job outputs so the iOS app has something renderable.
- Supports delayed local jobs and inline Vercel-safe jobs through `IOS_BACKEND_JOB_MODE`.

## Commands

From the repo root:

```bash
npm run backend:build
npm run backend:start
```

Default URL:

```text
http://127.0.0.1:8787
```

## Production wiring

### Vercel

- `vercel.json` rewrites `/health` and `/v1/*` to `api/health.ts` and `api/v1/[...route].ts`
- those handlers reuse the same core app as the local Node server

### Supabase

- apply [schema.sql](./supabase/schema.sql)
- set `IOS_BACKEND_SUPABASE_URL` and `IOS_BACKEND_SUPABASE_SERVICE_ROLE_KEY`
- set `IOS_BACKEND_STORE=supabase`

### Cloudflare R2

- create a bucket
- create an R2 API token with object read/write access
- set `IOS_BACKEND_R2_ACCOUNT_ID`, `IOS_BACKEND_R2_BUCKET`, `IOS_BACKEND_R2_ACCESS_KEY_ID`, and `IOS_BACKEND_R2_SECRET_ACCESS_KEY`
- set `IOS_BACKEND_OBJECT_STORAGE=r2`

## Important limitations

- Apple identity tokens are still treated as accepted inputs; server-side Apple verification is not wired yet.
- StoreKit sync/restore endpoints still accept transactions without App Store Server verification.
- The backend is production-shaped now, but Apple auth and billing validation still need real provider integration.
