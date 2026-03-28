# iOS IAP Backend Contract

This document defines the StoreKit-to-backend synchronization flow expected by the current iOS app architecture.

## Source of truth

- Apple is the source of truth for transaction validity.
- Your backend is the source of truth for app entitlement state.
- The iOS app should not infer final access from local StoreKit state alone.

## Flow

1. The app loads product identifiers from build config or backend app config.
2. The user purchases or restores via StoreKit 2.
3. The app sends transaction metadata to your backend.
4. The backend verifies with Apple and updates entitlements.
5. The app refreshes `GET /v1/me/entitlements`.

## Recommended endpoints

### `POST /v1/iap/apple/sync`

Use after a successful StoreKit purchase.

Request:

```json
{
  "product_id": "ai.wavespeed.pro.monthly",
  "transaction_id": "2000001234567890",
  "original_transaction_id": "2000001234500000",
  "app_account_token": "11111111-2222-3333-4444-555555555555",
  "signed_transaction_info": "<optional-jws>"
}
```

Response:

```json
{
  "data": {
    "accepted": true,
    "message": "Transaction verified",
    "entitlement": {
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

- Idempotent by `transaction_id`.
- If the transaction is already processed, still return `accepted: true`.

### `POST /v1/iap/apple/restore`

Use after `AppStore.sync()` or when the user explicitly taps restore.

Request:

```json
{
  "original_transaction_ids": [
    "2000001234500000",
    "2000001234500001"
  ]
}
```

Response: same shape as `/v1/iap/apple/sync`.

### `GET /v1/me/entitlements`

The app uses this as the final confirmation step after purchase or restore.

## Backend requirements

- Prefer App Store Server API as the production source of truth.
- Use signed StoreKit transaction payloads only as an optimization or fallback when available.
- Persist:
  - user id
  - product id
  - transaction id
  - original transaction id
  - purchase date
  - expiration date
  - revocation date
  - environment
- Handle:
  - grace period
  - billing retry
  - refunds/revocations
  - upgrades/downgrades

## Recommended production verification path

1. App sends `transaction_id`, `original_transaction_id`, `product_id`, and `app_account_token`.
2. Backend calls App Store Server API `Get Transaction History`.
3. Backend derives the effective entitlement from Apple transaction history.
4. Backend stores normalized purchase rows and returns `GET /v1/me/entitlements` data.

Required backend env for this path:

- `IOS_BACKEND_APP_STORE_ISSUER_ID`
- `IOS_BACKEND_APP_STORE_KEY_ID`
- `IOS_BACKEND_APP_STORE_PRIVATE_KEY_PEM`
- `IOS_BACKEND_APP_STORE_ENABLE_SERVER_API=true`

## Failure behavior

- If StoreKit succeeds locally but backend sync fails, the app should show a recoverable error and ask the user to retry or restore.
- If backend says transaction is invalid, do not unlock access.
- If backend is unavailable, the app can keep a temporary local “purchase pending sync” state, but must refresh entitlements before allowing long-lived access.

## Product configuration

Recommended `Info.plist` or backend-driven values:

- subscription product ids
- subscription group name for support/debugging
- management URL fallback

## Suggested future addition

Expose `GET /v1/app-config` with:

```json
{
  "data": {
    "subscription_product_ids": [
      "ai.wavespeed.pro.monthly"
    ],
    "subscription_management_url": "https://apps.apple.com/account/subscriptions",
    "privacy_url": "https://example.com/privacy",
    "terms_url": "https://example.com/terms",
    "support_email": "support@example.com"
  }
}
```

That lets the app avoid hardcoding product IDs per build once production is live.
