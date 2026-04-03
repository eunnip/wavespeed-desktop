# iOS Backend

This backend supports two deployment shapes behind the same route contract:

- local Node server with JSON metadata and filesystem blobs
- Vercel API functions with Supabase metadata and WaveSpeed orchestration

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
- Keeps Apple sign-in and subscription enforcement server-side.
- Keeps the route contract stable across local and deployed environments.
- Uploads reference images to WaveSpeed and submits generation jobs with the backend-owned `WAVESPEED_API_KEY`.
- Stores per-user job history locally while returning WaveSpeed media URLs directly to the iOS app.

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

- `vercel.json` rewrites `/health` and `/v1/*` to `api/backend.ts`
- `vercel.json` also forces the project framework preset to `Other` so this API-only repo deploys cleanly on Vercel

### Supabase

- apply [schema.sql](./supabase/schema.sql)
- set `IOS_BACKEND_SUPABASE_URL` and `IOS_BACKEND_SUPABASE_SERVICE_ROLE_KEY`
- set `IOS_BACKEND_STORE=supabase`

### WaveSpeed

- set `WAVESPEED_API_KEY`
- optionally set `WAVESPEED_MODEL_ALLOWLIST` to a comma-separated list of model IDs you want exposed in the app
- leave `WAVESPEED_MODEL_ALLOWLIST` empty to auto-expose compatible text-to-image, image-to-image, text-to-video, and image-to-video models

## Important limitations

- Uploaded files and generated media stay on WaveSpeed’s retention window. The backend stores metadata and task IDs, not durable media copies.
- Apple auth and App Store verification can be hardened further with the existing server-side verification env flags.
