# Photo G iOS

This repository has been reduced to the standalone iOS app under [`ios/`](./).

## What runs in the app

The iOS app is a SwiftUI client named `PhotoGStudio`. It does not call the old Electron runtime. The active runtime path is:

1. The app signs in against your backend.
2. The app loads the model catalog from your backend.
3. The app optionally uploads a reference image to your backend.
4. The app creates a generation job on your backend.
5. The app polls the backend job until it finishes.
6. The app opens or saves the returned output URLs locally on device.

The core source lives in:

- [`ios/ClientApp`](./ClientApp)
- [`ios/BackendAPI`](./BackendAPI)

`ios/InferenceAPI` is a legacy direct-upstream experiment and is not used by the current SwiftUI app target.

## iOS app structure

- [`ios/ClientApp/ClientApp.swift`](./ClientApp/ClientApp.swift): app entry point.
- [`ios/ClientApp/RootView.swift`](./ClientApp/RootView.swift): boot, auth gate, main tabs, paywall presentation.
- [`ios/ClientApp/AppSession.swift`](./ClientApp/AppSession.swift): shared session state, backend auth, model catalog loading, job submission, polling, local asset persistence.
- [`ios/ClientApp/MainTabView.swift`](./ClientApp/MainTabView.swift): tab shell.
- [`ios/ClientApp/CreateView.swift`](./ClientApp/CreateView.swift): model discovery / launch surface.
- [`ios/ClientApp/ComposerView.swift`](./ClientApp/ComposerView.swift): prompt + optional reference image composer.
- [`ios/ClientApp/ActivityView.swift`](./ClientApp/ActivityView.swift): job history and status feed.
- [`ios/ClientApp/JobDetailView.swift`](./ClientApp/JobDetailView.swift): output viewing and save actions.
- [`ios/ClientApp/LibraryView.swift`](./ClientApp/LibraryView.swift): locally saved outputs.
- [`ios/ClientApp/AccountView.swift`](./ClientApp/AccountView.swift): entitlement, support, account actions.

## Runtime configuration

The app reads these values from [`ios/ClientApp/Info.plist`](./ClientApp/Info.plist), which is fed by the active xcconfig:

- `WSBackendBaseURL`
- `WSEnvironmentName`
- `WSSubscriptionProductIDs`

Current config files:

- [`ios/Config/Debug.xcconfig`](./Config/Debug.xcconfig)
- [`ios/Config/Release.xcconfig`](./Config/Release.xcconfig)

Current defaults:

- Debug backend URL: `https://example.com`
- Release backend URL: `https://wavespeed-desktop.vercel.app`
- Environment names: `development` and `production`
- Subscription product ID: `com.altarisgroup.photogstudio.pro.monthly`

## Authentication and app bootstrap

The app session is owned by [`ios/ClientApp/AppSession.swift`](./ClientApp/AppSession.swift).

Important behavior:

- Access and refresh tokens are stored in Keychain.
- The backend URL is stored in `UserDefaults`.
- On launch, `bootstrap()` restores tokens, refreshes them if needed, then loads:
  - current user
  - current entitlement
  - app config
  - model catalog
  - job list
  - local saved assets

Backend auth endpoints used by the app:

- `POST /v1/auth/sign-in/apple`
- `POST /v1/auth/refresh`
- `POST /v1/auth/sign-out`
- `GET /v1/me`
- `GET /v1/me/entitlements`
- `POST /v1/iap/apple/sync`
- `POST /v1/iap/apple/restore`

The transport layer lives in:

- [`ios/BackendAPI/Sources/BackendAPI/AuthClient.swift`](./BackendAPI/Sources/BackendAPI/AuthClient.swift)
- [`ios/BackendAPI/Sources/BackendAPI/HTTPClient.swift`](./BackendAPI/Sources/BackendAPI/HTTPClient.swift)
- [`ios/BackendAPI/Sources/BackendAPI/Models.swift`](./BackendAPI/Sources/BackendAPI/Models.swift)

## How the app accesses all models

The model catalog is fetched from:

- `GET /v1/catalog/models`

Code path:

- [`ios/BackendAPI/Sources/BackendAPI/CatalogClient.swift`](./BackendAPI/Sources/BackendAPI/CatalogClient.swift)
- [`ios/ClientApp/AppSession.swift`](./ClientApp/AppSession.swift), `refreshSessionData()`

The backend returns `CatalogModel` values with:

- `id`: canonical model identifier used for job creation
- `name`: display name
- `summary`: short UI description
- `kind`: display grouping such as `image`, `video`, or `edit`
- `thumbnailURL`: optional remote preview
- `requiresImageInput`: whether the model needs a reference image before submission

The UI currently surfaces those models in:

- [`ios/ClientApp/CreateView.swift`](./ClientApp/CreateView.swift)

Filtering today is display-oriented only:

- search by `name`, `summary`, or `displayKind`
- kind chips derived from `CatalogModel.kind`
- featured models sourced from `AppConfig.featuredModelIds`

## How a generation job is created

### 1. Optional image upload

If the selected model requires a reference image and the user picks one, the app uploads it first:

- endpoint: `POST /v1/uploads`
- code: [`ios/BackendAPI/Sources/BackendAPI/UploadsClient.swift`](./BackendAPI/Sources/BackendAPI/UploadsClient.swift)

The upload response is an `UploadReceipt`:

- `id`
- `fileURL`
- `mimeType`

The returned `fileURL` is then reused as `imageURL` in the job request.

### 2. Job creation

The app submits:

- endpoint: `POST /v1/jobs`
- code: [`ios/BackendAPI/Sources/BackendAPI/JobsClient.swift`](./BackendAPI/Sources/BackendAPI/JobsClient.swift)

Current request model:

```json
{
  "model_id": "model-id-from-catalog",
  "prompt": "user prompt",
  "negative_prompt": "optional negative prompt",
  "image_url": "optional uploaded image URL",
  "parameters": {}
}
```

In code this is `CreateJobRequest` in [`ios/BackendAPI/Sources/BackendAPI/Models.swift`](./BackendAPI/Sources/BackendAPI/Models.swift).

The current iOS app only fills:

- `modelId`
- `prompt`
- `negativePrompt`
- `imageURL`

It does not currently populate `parameters`.

Submission path:

- [`ios/ClientApp/ComposerView.swift`](./ClientApp/ComposerView.swift), `submit()`
- [`ios/ClientApp/AppSession.swift`](./ClientApp/AppSession.swift), `submitJob(...)`

## How outputs are returned and used

The backend job response returns a `Job` with:

- `id`
- `modelId`
- `modelName`
- `prompt`
- `status`
- `createdAt`
- `updatedAt`
- `errorMessage`
- `outputs`

Each output is a `JobOutput` with:

- `id`
- `url`
- `mimeType`

Code:

- [`ios/BackendAPI/Sources/BackendAPI/Models.swift`](./BackendAPI/Sources/BackendAPI/Models.swift)

### Polling

After job creation, the app polls:

- endpoint: `GET /v1/jobs/{id}`
- code: [`ios/ClientApp/AppSession.swift`](./ClientApp/AppSession.swift), `pollJobIfNeeded(jobID:)`

Polling stops when `status.isTerminal` is true.

### Displaying the resulting picture

In the UI:

- image outputs are detected when `mimeType` starts with `image/`
- image URLs are rendered with `AsyncImage`
- non-image outputs are shown as external-file cards

Code:

- [`ios/ClientApp/JobDetailView.swift`](./ClientApp/JobDetailView.swift)
- [`ios/ClientApp/ActivityView.swift`](./ClientApp/ActivityView.swift), `JobOutput.isImageOutput`

### Opening the result externally

Every output card can open the backend-returned `url` directly using `Link`.

### Saving the result locally

When the user taps save, the app downloads the data at `JobOutput.url` and stores it locally:

- code: [`ios/ClientApp/AppSession.swift`](./ClientApp/AppSession.swift), `saveOutput(_:for:)`
- local storage implementation: [`ios/ClientApp/LocalAssetStore.swift`](./ClientApp/LocalAssetStore.swift)

Saved outputs are written to:

- `Documents/SavedOutputs/`

The app also writes:

- `Documents/SavedOutputs/index.json`

Each local asset records:

- `id`
- `filename`
- `createdAt`
- `mimeType`

The Library tab reads from that local index and folder.

## Subscription and entitlement gating

The app blocks job submission unless the entitlement is active:

- checked in [`ios/ClientApp/AppSession.swift`](./ClientApp/AppSession.swift), `submitJob(...)`
- if inactive, the app presents the paywall

The StoreKit and backend sync path lives in:

- [`ios/ClientApp/StoreKitService.swift`](./ClientApp/StoreKitService.swift)
- [`ios/ClientApp/SubscriptionViewModel.swift`](./ClientApp/SubscriptionViewModel.swift)
- [`ios/ClientApp/PaywallView.swift`](./ClientApp/PaywallView.swift)
- [`ios/ClientApp/ManageSubscriptionView.swift`](./ClientApp/ManageSubscriptionView.swift)

## Build and run

Requirements:

- Xcode 26.1 or later
- valid Apple signing team
- backend implementing the endpoints above

Build from repo root:

```bash
xcodebuild -project ios/PhotoGStudio.xcodeproj \
  -scheme PhotoGStudio \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

## Current development shortcuts

The app still supports internal development modes:

- `mock://local` backend URL for fully mocked auth/catalog/jobs
- manual developer connection UI in non-production environments
- simulator shortcut sign-in for local UI work

Those paths are controlled in:

- [`ios/ClientApp/AuthGatewayView.swift`](./ClientApp/AuthGatewayView.swift)
- [`ios/ClientApp/AppSession.swift`](./ClientApp/AppSession.swift)

## Files you need if you keep only the iOS app

The minimum product code is:

- [`ios/ClientApp`](./ClientApp)
- [`ios/BackendAPI`](./BackendAPI)
- [`ios/Config`](./Config)
- [`ios/PhotoGStudio.xcodeproj`](./PhotoGStudio.xcodeproj)
- [`ios/exportOptions.plist`](./exportOptions.plist)

`ios/InferenceAPI` is not required for the current app target.
