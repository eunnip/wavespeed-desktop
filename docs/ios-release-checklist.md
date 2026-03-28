# iOS Release Checklist

## Before Submission

- Set the real bundle identifier and signing team in the Xcode target.
- Replace placeholder app icons in [ios/ClientApp/Assets.xcassets](/Users/stephenyip/wavespeed/wavespeed-desktop/ios/ClientApp/Assets.xcassets).
- Set production values in [ios/Config/Release.xcconfig](/Users/stephenyip/wavespeed/wavespeed-desktop/ios/Config/Release.xcconfig).
- Confirm privacy, terms, and support URLs are returned by your backend app config.
- Confirm backend auth endpoints exist for:
  - sign in with Apple
  - refresh session
  - sign out
  - entitlement fetch
  - jobs list/create/cancel
  - upload flow
- Confirm StoreKit product IDs are configured if subscriptions are enabled.
- Replace placeholder text in the auth and paywall views if shipping to testers.

## QA

- Sign in with the developer connection.
- Sign in with Apple placeholder path shows the expected warning until backend exchange is live.
- Refresh account and entitlement state.
- Create a job and verify polling updates.
- Save an output locally and confirm it appears in Library.
- Archive the release target in Xcode Organizer.

## App Store Readiness

- Final app icon set is present.
- Privacy nutrition labels match actual data collection.
- Terms and privacy policy URLs are live.
- Support email is live.
- Signing and provisioning validate in Organizer.
