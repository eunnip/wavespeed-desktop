# iOS Backend Auth Contract

This document defines the backend authentication contract the iOS app is now shaped around.

## Goals

- Keep provider credentials server-side.
- Use short-lived access tokens plus refresh tokens.
- Let the iOS app authenticate with Sign in with Apple, then operate only against your backend.
- Make entitlements queryable independently from full session refresh.

## Recommended token model

- `access_token`: JWT or opaque token, 15-30 minute TTL.
- `refresh_token`: opaque, revocable, device-scoped token, 30-90 day TTL.
- `token_type`: `"Bearer"`.
- `expires_at`: ISO-8601 timestamp in UTC.

Persist on iOS:

- Access token in Keychain.
- Refresh token in Keychain.
- Backend base URL in `UserDefaults`.
- No Apple credential payloads after exchange.

## Recommended endpoints

### `POST /v1/auth/sign-in/apple`

Exchanges Apple credentials for app session tokens.

Request:

```json
{
  "identity_token": "<apple-jwt>",
  "authorization_code": "<optional-apple-auth-code>"
}
```

Response:

```json
{
  "data": {
    "access_token": "at_123",
    "refresh_token": "rt_123",
    "expires_at": "2026-03-27T12:00:00Z",
    "token_type": "Bearer",
    "user": {
      "id": "usr_123",
      "display_name": "Stephen",
      "email": "user@example.com"
    },
    "entitlements": {
      "is_active": true,
      "tier_name": "Pro Monthly",
      "renewal_date": "2026-04-27T12:00:00Z",
      "usage_description": "Unlimited image generation within fair use.",
      "management_url": "https://apps.apple.com/account/subscriptions"
    }
  }
}
```

Notes:

- Treat `identity_token` as mandatory.
- `authorization_code` is useful for server-side audits and future verification, but the app can proceed without it if Apple omits it.
- Create or attach a device-scoped refresh token on sign-in.

### `POST /v1/auth/refresh`

Request:

```json
{
  "refresh_token": "rt_123"
}
```

Response shape: same as `POST /v1/auth/sign-in/apple`.

Notes:

- Rotate refresh tokens if possible.
- If the refresh token is invalid, return `401`.

### `POST /v1/auth/sign-out`

Request:

```json
{
  "refresh_token": "rt_123",
  "revoke_all_sessions": false
}
```

Response:

```json
{
  "data": {}
}
```

Notes:

- Revoke only the current device refresh token by default.

### `POST /v1/auth/revoke`

Same payload as sign-out, but intended for administrative/session-security flows.

### `GET /v1/me`

Returns the current user profile.

### `GET /v1/me/entitlements`

Returns the current effective entitlement without requiring a full session bootstrap.

### `POST /v1/me/delete`

Supports App Store account deletion expectations.

## Status codes

- `200`: success.
- `401`: invalid or expired access token, invalid refresh token.
- `403`: authenticated but not entitled or blocked.
- `409` or `422`: malformed Apple credential exchange or invalid request shape.
- `429`: rate-limited.

## Error envelope

Recommended server response:

```json
{
  "error": "Refresh token has expired",
  "code": 10041,
  "request_id": "req_123"
}
```

Recommended headers:

- `X-Request-ID`
- `Retry-After` for rate limiting

## Device/session guidance

- Refresh tokens should be device-scoped.
- Include device metadata server-side: app version, platform, environment, last seen time.
- If the same Apple account signs in on multiple devices, issue separate refresh tokens.

## iOS behavior expected by the current app

- The app will attempt token refresh automatically when an authenticated request returns `401`.
- The app may call `GET /v1/me/entitlements` independently when returning to foreground or after purchase sync.
- The app supports a `mock://local` backend URL for development-only mock mode.
