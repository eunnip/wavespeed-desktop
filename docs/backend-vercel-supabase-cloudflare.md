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
IOS_BACKEND_DATA_DIR=/tmp/wavespeed-ios-backend
IOS_BACKEND_PRODUCT_IDS=ai.wavespeed.pro.monthly
IOS_BACKEND_DATABASE_PROVIDER=supabase
IOS_BACKEND_BLOB_PROVIDER=r2
IOS_BACKEND_JOB_MODE=inline
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

Apple sign-in and StoreKit hardening:

```text
IOS_BACKEND_APPLE_SIGN_IN_CLIENT_ID=com.example.ios
IOS_BACKEND_APPLE_SIGN_IN_EXPECTED_ISSUER=https://appleid.apple.com
IOS_BACKEND_APPLE_SIGN_IN_REQUIRE_NONCE=true
IOS_BACKEND_APPLE_SIGN_IN_ENFORCE_VERIFICATION=true
IOS_BACKEND_APP_STORE_BUNDLE_ID=com.example.ios
IOS_BACKEND_APP_STORE_ENVIRONMENT=Production
IOS_BACKEND_APP_STORE_REQUIRE_SIGNED_TRANSACTIONS=true
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

- Configure real Apple client/bundle IDs and enable verification env flags in production
- Optionally add App Store Server API certificate or transaction-history verification on top of the current signed-payload checks
- Replace generated SVG mock outputs with real model orchestration
