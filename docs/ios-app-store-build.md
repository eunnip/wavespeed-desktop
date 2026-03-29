# iOS App Build

This repo now includes a buildable and archivable iOS target at `ios/PhotoGStudio.xcodeproj`.

## Requirements

- Xcode 26.1 or later
- An Apple Developer team for signing and archive export
- A backend that exposes the production-facing API contract described in `docs/standalone-ios-app-architecture.md`

## Project Setup

1. Open [ios/PhotoGStudio.xcodeproj](/Users/stephenyip/wavespeed/wavespeed-desktop/ios/PhotoGStudio.xcodeproj) in Xcode.
2. In the `PhotoGStudio` target, set your Apple team under Signing & Capabilities.
3. Adjust values in:
   - [ios/Config/Debug.xcconfig](/Users/stephenyip/wavespeed/wavespeed-desktop/ios/Config/Debug.xcconfig)
   - [ios/Config/Release.xcconfig](/Users/stephenyip/wavespeed/wavespeed-desktop/ios/Config/Release.xcconfig)
4. Replace the placeholder app icons in [ios/ClientApp/Assets.xcassets/AppIcon.appiconset](/Users/stephenyip/wavespeed/wavespeed-desktop/ios/ClientApp/Assets.xcassets/AppIcon.appiconset).

## Local Build

From the repo root:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project ios/PhotoGStudio.xcodeproj \
-scheme PhotoGStudio \
-configuration Debug \
-derivedDataPath /tmp/wavespeed-ios-derived \
-destination 'generic/platform=iOS' \
CODE_SIGNING_ALLOWED=NO build
```

## Archive

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project ios/PhotoGStudio.xcodeproj \
-scheme PhotoGStudio \
-configuration Release \
-derivedDataPath /tmp/wavespeed-ios-derived \
-destination 'generic/platform=iOS' \
archive -archivePath /tmp/wavespeed-ios-archive/PhotoGStudio.xcarchive
```

Or use Xcode:

1. Select the `PhotoGStudio` scheme.
2. Choose `Any iOS Device (arm64)`.
3. Run `Product > Archive`.
4. In Organizer, validate and export.

## Export

For scripted export, use [ios/exportOptions.plist](/Users/stephenyip/wavespeed/wavespeed-desktop/ios/exportOptions.plist) as a template and replace the team ID.

## Runtime Configuration

- `WS_BACKEND_BASE_URL` is provided through the active `.xcconfig`.
- `WS_ENVIRONMENT_NAME` is provided through the active `.xcconfig`.
- `WS_SUBSCRIPTION_PRODUCT_IDS` can be set as a comma-separated list when StoreKit products are ready.

## Current Auth State

The app includes:

- a production-facing Sign in with Apple entry point placeholder
- a developer fallback that accepts backend URL plus bearer tokens

The production auth flow still requires backend implementation for Apple identity exchange and entitlement sync.
