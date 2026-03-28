# Backend Deployment Shape

This backend is now structured to run in two modes behind the same `/health` and `/v1/*` contract:

- local development: `node --experimental-transform-types backend/src/server.ts`
- Vercel deployment: `api/backend.ts` via `vercel.json` rewrites

## Recommended stack

- Vercel: public HTTP API
- Supabase Postgres: users, sessions, purchases, uploads, jobs
- Cloudflare R2: uploaded media and generated outputs

## Environment variables

Core:

```text
IOS_BACKEND_BASE_URL=https://your-api-domain.example
IOS_BACKEND_PRODUCT_IDS=ai.wavespeed.pro.monthly
IOS_BACKEND_DATABASE_PROVIDER=supabase
IOS_BACKEND_BLOB_PROVIDER=r2
```

Supabase:

```text
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=...
SUPABASE_SCHEMA=public
```

Cloudflare R2:

```text
R2_ACCOUNT_ID=...
R2_BUCKET=wavespeed-ios
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
```

## Supabase setup

Apply [schema.sql](/Users/stephenyip/wavespeed/wavespeed-desktop/backend/supabase/schema.sql).

Tables created:

- `ios_users`
- `ios_refresh_sessions`
- `ios_access_sessions`
- `ios_purchases`
- `ios_uploads`
- `ios_jobs`

## Cloudflare R2 setup

The backend uses R2 via the S3-compatible API and signs requests with AWS Signature V4.

Current usage:

- `POST /v1/uploads` writes to `uploads/{userId}/{uploadId}.{ext}`
- generated outputs write to `outputs/{userId}/{jobId}/{outputId}.svg`
- authenticated content routes proxy bytes back through the backend

## Remaining production work

- Verify Apple identity tokens server-side in `POST /v1/auth/sign-in/apple`
- Verify StoreKit/App Store transactions server-side in:
  - `POST /v1/iap/apple/sync`
  - `POST /v1/iap/apple/restore`
- Replace generated SVG mock outputs with real model orchestration
