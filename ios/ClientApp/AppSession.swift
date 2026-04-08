import Foundation
import SwiftUI

enum AuthFailureReason: String {
    case invalidBackendURL
    case unauthorized
    case refreshExpired
    case networkUnavailable
    case backendUnavailable
    case unknown

    var guidance: String {
        switch self {
        case .invalidBackendURL:
            return "Enter a valid backend URL or switch to mock mode for local iOS development."
        case .unauthorized:
            return "Your session is no longer valid. Sign in again to continue."
        case .refreshExpired:
            return "The saved refresh token can no longer renew this session. Sign in again."
        case .networkUnavailable:
            return "The backend could not be reached. Check connectivity and try again."
        case .backendUnavailable:
            return "The backend returned an error. Check the server logs and request ID if available."
        case .unknown:
            return "Review the backend response and try again."
        }
    }
}

@MainActor
final class AppSession: ObservableObject {
    @Published var backendURLString: String
    @Published var sessionTokens: SessionTokens?
    @Published var authState: AuthState
    @Published var user: UserProfile?
    @Published var entitlement: EntitlementSummary?
    @Published var entitlementState = EntitlementState()
    @Published var storeKitState = StoreKitState()
    @Published var appConfig = AppConfig()
    @Published var catalog: [CatalogModel] = []
    @Published var jobs: [Job] = []
    @Published var localAssets: [LocalAsset] = []
    @Published var isBootstrapping = true
    @Published var isBusy = false
    @Published var presentPaywall = false
    @Published var errorText: String?
    @Published var authFailureReason: AuthFailureReason?
    @Published var pendingAppleNonce: String?

    private let documentsStore = LocalAssetStore()
    private var tokenRefreshTask: Task<SessionTokens, Error>?

    init() {
        let defaultBackendURL = Bundle.main.object(forInfoDictionaryKey: "WSBackendBaseURL") as? String
        let environmentName = (Bundle.main.object(forInfoDictionaryKey: "WSEnvironmentName") as? String) ?? "development"
        let storedBackendURL = UserDefaults.standard.string(forKey: "backend_url")
        let isProduction = environmentName == APIEnvironment.production.rawValue
        let resolvedDefaultBackendURL = Self.normalizedBackendURLString(
            from: defaultBackendURL,
            environmentName: environmentName
        )
        let resolvedStoredBackendURL = Self.normalizedBackendURLString(
            from: storedBackendURL,
            environmentName: environmentName
        )
        self.backendURLString = isProduction
            ? (resolvedDefaultBackendURL ?? "https://example.com")
            : (resolvedStoredBackendURL ?? resolvedDefaultBackendURL ?? "https://example.com")
        if isProduction, let resolvedDefaultBackendURL {
            UserDefaults.standard.set(resolvedDefaultBackendURL, forKey: "backend_url")
        }
        let storedSessionTokens = KeychainStore.loadSessionTokens()
        let storedAccessToken = storedSessionTokens?.accessToken ?? KeychainStore.loadAccessToken()
        let storedRefreshToken = storedSessionTokens?.refreshToken ?? KeychainStore.loadRefreshToken()
        self.sessionTokens = storedSessionTokens ?? (storedAccessToken.isEmpty
            ? nil
            : SessionTokens(accessToken: storedAccessToken, refreshToken: storedRefreshToken))
        self.authState = storedAccessToken.isEmpty ? .signedOut : .restoring
        self.localAssets = documentsStore.loadAssets()
        self.storeKitState.productIDs = subscriptionProductIDs
    }

    var isAuthenticated: Bool {
        !(sessionTokens?.accessToken.isEmpty ?? true)
    }

    var accessToken: String {
        sessionTokens?.accessToken ?? ""
    }

    var refreshToken: String {
        sessionTokens?.refreshToken ?? ""
    }

    private var configuredBackendURLString: String? {
        Self.normalizedBackendURLString(
            from: Bundle.main.object(forInfoDictionaryKey: "WSBackendBaseURL") as? String,
            environmentName: environmentName
        )
    }

    var activeBackendURLString: String {
        if usesMockBackendURL {
            return backendURLString
        }
        if environmentName == APIEnvironment.production.rawValue,
           let configuredBackendURLString
        {
            return configuredBackendURLString
        }
        return backendURLString
    }

    var backendURL: URL? {
        URL(string: activeBackendURLString)
    }

    var isMockEnvironment: Bool {
        environmentName == APIEnvironment.mock.rawValue || usesMockBackendURL || hasMockSessionTokens
    }

    var isDeveloperMode: Bool {
        environmentName != APIEnvironment.production.rawValue || isMockEnvironment
    }

    var allowsDeveloperConnection: Bool {
        #if DEBUG
        return isDeveloperMode
        #else
        return false
        #endif
    }

    var allowsSimulatorMockSignIn: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    var environmentName: String {
        (Bundle.main.object(forInfoDictionaryKey: "WSEnvironmentName") as? String) ?? "development"
    }

    var subscriptionProductIDs: [String] {
        let rawValue = (Bundle.main.object(forInfoDictionaryKey: "WSSubscriptionProductIDs") as? String) ?? ""
        return rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var api: BackendAPI? {
        guard let backendURL else {
            return nil
        }
        let session = self
        let client = HTTPClient(
            configuration: makeAPIConfiguration(for: backendURL),
            accessTokenProvider: {
                await session.currentAccessTokenForHTTPClient()
            },
            accessTokenRefresher: {
                try await session.refreshAccessTokenForHTTPClient()
            }
        )
        return BackendAPI(httpClient: client)
    }

    func bootstrap() async {
        defer { isBootstrapping = false }
        if isMockEnvironment {
            loadMockSessionData()
            authState = .signedIn
            return
        }
        if refreshToken.isEmpty, !isAuthenticated {
            authState = .signedOut
            return
        }
        authState = .restoring
        await refreshAccessTokenIfNeeded()
        guard isAuthenticated else {
            authState = .signedOut
            return
        }
        await refreshSessionData()
        await loadLocalAssets()
    }

    func signIn(backendURLString: String, accessToken: String, refreshToken: String) async {
        let trimmedURL = backendURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRefreshToken = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.backendURLString = trimmedURL
        if trimmedURL.lowercased().hasPrefix("mock://") {
            sessionTokens = SessionTokens(
                accessToken: "mock-access-token",
                refreshToken: "mock-refresh-token"
            )
            authState = .signedIn
            persistCredentials()
            loadMockSessionData()
            return
        }
        guard let normalizedURL = normalizedBackendURLString(from: trimmedURL) else {
            authState = .failed
            authFailureReason = .invalidBackendURL
            errorText = authFailureReason?.guidance
            return
        }
        if environmentName == APIEnvironment.production.rawValue,
           let configuredBackendURLString
        {
            self.backendURLString = configuredBackendURLString
        } else {
            self.backendURLString = normalizedURL
        }
        self.sessionTokens = SessionTokens(
            accessToken: trimmedAccessToken,
            refreshToken: trimmedRefreshToken.isEmpty ? nil : trimmedRefreshToken
        )
        authState = .signedIn
        authFailureReason = nil
        persistCredentials()
        await refreshSessionData()
    }

    func signInWithMockSession() async {
        await signIn(
            backendURLString: "mock://local",
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token"
        )
    }

    func signInWithApplePlaceholder(
        identityToken: String?,
        authorizationCode: String?,
        nonce: String?
    ) async {
        guard let identityToken, !identityToken.isEmpty else {
            errorText = "Sign in with Apple completed, but no identity token was returned to exchange with your backend."
            authState = .failed
            authFailureReason = .unauthorized
            return
        }
        if isMockEnvironment {
            sessionTokens = SessionTokens(
                accessToken: "mock-apple-access-token",
                refreshToken: "mock-apple-refresh-token"
            )
            persistCredentials()
            loadMockSessionData()
            authState = .signedIn
            return
        }
        guard let api else {
            errorText = "Enter a valid backend URL before using Sign in with Apple."
            authState = .failed
            authFailureReason = .invalidBackendURL
            return
        }
        isBusy = true
        errorText = nil
        defer { isBusy = false }
        do {
            backendURLString = activeBackendURLString
            let tokens = try await api.auth.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                nonce: nonce
            )
            backendURLString = backendURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            sessionTokens = tokens
            user = tokens.user
            entitlement = tokens.entitlements
            if let summary = tokens.entitlements {
                entitlementState = EntitlementState(
                    summary: summary,
                    lastRefreshedAt: Date(),
                    source: .backend
                )
            }
            authState = .signedIn
            authFailureReason = nil
            persistCredentials()
            await refreshSessionData()
        } catch {
            errorText = displayMessage(for: error)
            authState = .failed
            authFailureReason = failureReason(for: error)
        }
        pendingAppleNonce = nil
    }

    func syncPurchasedSubscription(_ transaction: VerifiedStoreTransaction) async throws {
        if isMockEnvironment {
            entitlement = makeMockEntitlement()
            entitlementState = EntitlementState(
                summary: entitlement,
                lastRefreshedAt: Date(),
                source: .backend
            )
            return
        }
        guard let api else {
            throw APIError(message: "Enter a valid backend URL.")
        }
        let result = try await api.auth.syncAppleSubscription(
            AppleSubscriptionSyncRequest(
                productID: transaction.productID,
                transactionID: transaction.transactionID,
                originalTransactionID: transaction.originalTransactionID,
                appAccountToken: transaction.appAccountToken,
                signedTransactionInfo: transaction.signedTransactionInfo
            )
        )
        if let summary = result.entitlement {
            entitlement = summary
            entitlementState = EntitlementState(
                summary: summary,
                lastRefreshedAt: Date(),
                source: .backend
            )
        } else {
            await refreshEntitlement()
        }
    }

    func restorePurchasedSubscriptions(_ transactions: [VerifiedStoreTransaction]) async throws {
        if isMockEnvironment {
            entitlement = makeMockEntitlement()
            entitlementState = EntitlementState(
                summary: entitlement,
                lastRefreshedAt: Date(),
                source: .backend
            )
            return
        }
        guard let api else {
            throw APIError(message: "Enter a valid backend URL.")
        }
        let originalTransactionIDs = transactions.compactMap(\.originalTransactionID)
        let result = try await api.auth.restoreAppleSubscriptions(
            originalTransactionIDs: Array(Set(originalTransactionIDs))
        )
        if let summary = result.entitlement {
            entitlement = summary
            entitlementState = EntitlementState(
                summary: summary,
                lastRefreshedAt: Date(),
                source: .backend
            )
        } else {
            await refreshEntitlement()
        }
    }

    func signOut() {
        let currentAPI = api
        let currentRefreshToken = refreshToken
        sessionTokens = nil
        user = nil
        entitlement = nil
        entitlementState = EntitlementState()
        catalog = []
        jobs = []
        presentPaywall = false
        errorText = nil
        authFailureReason = nil
        authState = .signedOut
        persistCredentials()
        if !isMockEnvironment {
            Task {
                _ = try? await currentAPI?.auth.signOut(refreshToken: currentRefreshToken)
            }
        }
    }

    func refreshAccessTokenIfNeeded() async {
        guard !isMockEnvironment else { return }
        guard !refreshToken.isEmpty else { return }
        let needsRefresh = accessToken.isEmpty || (sessionTokens?.isExpired() ?? false)
        guard needsRefresh else { return }
        do {
            _ = try await refreshAccessTokenForHTTPClient()
            authFailureReason = nil
        } catch {
            errorText = displayMessage(for: error)
            authState = .failed
            authFailureReason = failureReason(for: error)
        }
    }

    func refreshSessionData() async {
        if isMockEnvironment {
            loadMockSessionData()
            authState = .signedIn
            return
        }
        guard let api else {
            errorText = "Enter a valid backend URL."
            authState = .failed
            authFailureReason = .invalidBackendURL
            return
        }
        isBusy = true
        authState = .refreshing
        errorText = nil
        authFailureReason = nil
        defer { isBusy = false }
        do {
            async let profile = api.auth.currentUser()
            async let entitlement = api.auth.currentEntitlement()
            async let config = api.catalog.appConfig()
            async let models = api.catalog.listModels()
            async let jobsPage = api.jobs.listJobs()

            self.user = try await profile
            self.entitlement = try await entitlement
            self.entitlementState = EntitlementState(
                summary: self.entitlement,
                lastRefreshedAt: Date(),
                source: .backend
            )
            self.appConfig = try await config
            self.catalog = try await models
            self.jobs = try await jobsPage.items
            self.authState = .signedIn
        } catch {
            errorText = displayMessage(for: error)
            authState = .failed
            authFailureReason = failureReason(for: error)
        }
    }

    func refreshEntitlement() async {
        if isMockEnvironment {
            entitlement = makeMockEntitlement()
            entitlementState = EntitlementState(
                summary: entitlement,
                lastRefreshedAt: Date(),
                source: .backend
            )
            return
        }
        guard let api else { return }
        do {
            let summary = try await api.auth.currentEntitlement()
            entitlement = summary
            entitlementState = EntitlementState(
                summary: summary,
                lastRefreshedAt: Date(),
                source: .backend
            )
        } catch {
            errorText = displayMessage(for: error)
            entitlementState.source = .stale
        }
    }

    func refreshJobs() async {
        if isMockEnvironment {
            jobs = makeMockJobs()
            return
        }
        guard let api else { return }
        do {
            jobs = try await api.jobs.listJobs().items
        } catch {
            errorText = displayMessage(for: error)
        }
    }

    func submitJob(
        model: CatalogModel,
        prompt: String,
        negativePrompt: String,
        selectedImageData: Data?
    ) async throws -> Job {
        if isMockEnvironment {
            let mockJob = Job(
                id: UUID().uuidString,
                modelId: model.id,
                modelName: model.name,
                prompt: prompt,
                status: .completed,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                outputs: []
            )
            upsert(mockJob)
            return mockJob
        }
        guard let api else {
            throw APIError(message: "Enter a valid backend URL.")
        }
        guard entitlementState.isActive || entitlement?.isActive == true else {
            presentPaywall = true
            throw APIError(message: "An active subscription is required to create a job.")
        }
        let uploadReceipt: UploadReceipt?
        if let selectedImageData {
            uploadReceipt = try await api.uploads.uploadImageData(selectedImageData)
        } else {
            uploadReceipt = nil
        }
        let request = CreateJobRequest(
            modelId: model.id,
            prompt: prompt,
            negativePrompt: negativePrompt.isEmpty ? nil : negativePrompt,
            imageURL: uploadReceipt?.fileURL
        )
        let job = try await api.jobs.createJob(request)
        upsert(job)
        Task { await pollJobIfNeeded(jobID: job.id) }
        return job
    }

    private func refreshAccessTokenForHTTPClient() async throws -> String? {
        guard !isMockEnvironment else {
            return accessToken.isEmpty ? nil : accessToken
        }
        if let task = tokenRefreshTask {
            let refreshed = try await task.value
            return refreshed.accessToken
        }
        guard !refreshToken.isEmpty, let backendURL else {
            return nil
        }
        let refreshToken = refreshToken
        let config = makeAPIConfiguration(for: backendURL)
        let task = Task<SessionTokens, Error> {
            let client = HTTPClient(configuration: config, accessTokenProvider: { nil })
            let api = BackendAPI(httpClient: client)
            return try await api.auth.refreshSession(refreshToken: refreshToken)
        }
        tokenRefreshTask = task
        defer { tokenRefreshTask = nil }
        let refreshed = try await task.value
        sessionTokens = refreshed
        user = refreshed.user ?? user
        if let refreshedEntitlements = refreshed.entitlements {
            entitlement = refreshedEntitlements
            entitlementState = EntitlementState(
                summary: refreshedEntitlements,
                lastRefreshedAt: Date(),
                source: .backend
            )
        }
        persistCredentials()
        return refreshed.accessToken
    }

    private func currentAccessTokenForHTTPClient() -> String? {
        accessToken
    }

    private func makeAPIConfiguration(for backendURL: URL) -> APIConfiguration {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let bundleId = Bundle.main.bundleIdentifier ?? "ios-client"
        return APIConfiguration(
            baseURL: backendURL,
            clientName: bundleId,
            clientVersion: version,
            clientOS: "ios",
            environment: APIEnvironment(rawValue: environmentName) ?? .development,
            apiVersion: "v1",
            requiresHTTPS: !environmentName.contains("dev") && !isMockEnvironment
        )
    }

    private func loadMockSessionData() {
        user = UserProfile(id: "mock-user", displayName: "Photo G Tester", email: "hello@photo-g.app")
        entitlement = makeMockEntitlement()
        entitlementState = EntitlementState(
            summary: entitlement,
            lastRefreshedAt: Date(),
            source: .backend
        )
        appConfig = AppConfig(
            supportEmail: "hello@photo-g.app",
            privacyURL: URL(string: "https://photo-g.app/privacy"),
            termsURL: URL(string: "https://photo-g.app/terms"),
            subscriptionManagementURL: URL(string: "https://apps.apple.com/account/subscriptions"),
            featuredModelIds: ["bytedance-seedream-v5", "google-nano-banana-pro", "openai-gpt-image-1.5", "black-forest-flux-kontext-pro"]
        )
        catalog = [
            CatalogModel(
                id: "bytedance-seedream-v3",
                name: "Seedream v3",
                summary: "ByteDance image model for polished image generations.",
                kind: "image"
            ),
            CatalogModel(
                id: "bytedance-seedream-v4",
                name: "Seedream v4",
                summary: "Sharper detail and stronger prompt following for still images.",
                kind: "image"
            ),
            CatalogModel(
                id: "bytedance-seedream-v5",
                name: "Seedream v5",
                summary: "Latest Seedream image generation tuned for premium quality.",
                kind: "image"
            ),
            CatalogModel(
                id: "bytedance-seedream-v5-edit",
                name: "Seedream v5 Edit",
                summary: "Reference-based Seedream editing mode for guided image changes.",
                kind: "edit",
                requiresImageInput: true
            ),
            CatalogModel(
                id: "bytedance-seedream-v5-sequential",
                name: "Seedream v5 Sequential",
                summary: "Sequential Seedream mode for consistent multi-step image outputs.",
                kind: "image"
            ),
            CatalogModel(
                id: "google-nano-banana",
                name: "Nano Banana",
                summary: "Google family baseline model for compact image generation.",
                kind: "image"
            ),
            CatalogModel(
                id: "google-nano-banana-2",
                name: "Nano Banana 2",
                summary: "Second generation Nano Banana with improved instruction following.",
                kind: "image"
            ),
            CatalogModel(
                id: "google-nano-banana-pro",
                name: "Nano Banana Pro",
                summary: "Google’s leading Nano Banana tier for higher quality image outputs.",
                kind: "image"
            ),
            CatalogModel(
                id: "openai-gpt-image-1",
                name: "GPT Image 1",
                summary: "OpenAI image model for prompt-driven visual generation.",
                kind: "image"
            ),
            CatalogModel(
                id: "openai-gpt-image-1.5",
                name: "GPT Image 1.5",
                summary: "OpenAI’s current leading GPT Image family for high quality stills.",
                kind: "image"
            ),
            CatalogModel(
                id: "openai-dall-e-3",
                name: "DALL-E 3",
                summary: "Legacy OpenAI image family kept for backward compatibility.",
                kind: "image"
            ),
            CatalogModel(
                id: "black-forest-flux-kontext-pro",
                name: "Flux Kontext Pro",
                summary: "Black Forest Labs family for premium prompt-based image generation.",
                kind: "image"
            ),
            CatalogModel(
                id: "black-forest-flux-kontext-edit",
                name: "Flux Kontext Edit",
                summary: "Reference-based Flux Kontext edit mode.",
                kind: "edit",
                requiresImageInput: true
            ),
            CatalogModel(
                id: "kling-v2.1-master",
                name: "Kling v2.1 Master",
                summary: "Kuaishou video generation family for premium motion output.",
                kind: "video"
            ),
            CatalogModel(
                id: "kling-v2.1-master-edit",
                name: "Kling v2.1 Master Edit",
                summary: "Reference-guided Kling mode for motion edits.",
                kind: "edit",
                requiresImageInput: true
            ),
            CatalogModel(
                id: "minimax-hailuo-video-02",
                name: "Hailuo Video 02",
                summary: "MiniMax video model for cinematic short clips.",
                kind: "video"
            ),
            CatalogModel(
                id: "minimax-hailuo-video-02-sequential",
                name: "Hailuo Video 02 Sequential",
                summary: "Sequential MiniMax mode for consistent motion sequences.",
                kind: "video"
            ),
            CatalogModel(
                id: "runway-gen4-image",
                name: "Runway Gen-4 Image",
                summary: "Runway still-image model for cinematic concepts.",
                kind: "image"
            )
        ]
        jobs = makeMockJobs()
    }

    private func makeMockEntitlement() -> EntitlementSummary {
        EntitlementSummary(
            isActive: true,
            tierName: "Creator Access",
            renewalDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400 * 27)),
            usageDescription: "Placeholder access enabled for simulator previews.",
            managementURL: URL(string: "https://apps.apple.com/account/subscriptions")
        )
    }

    private func makeMockJobs() -> [Job] {
        [
            Job(
                id: "job-mock-001",
                modelId: "bytedance-seedream-v5",
                modelName: "Seedream v5",
                prompt: "Bright natural portrait with clean skin tones and soft window light",
                status: .completed,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1800)),
                updatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1700)),
                outputs: []
            ),
            Job(
                id: "job-mock-002",
                modelId: "kling-v2.1-master",
                modelName: "Kling v2.1 Master",
                prompt: "Dreamy handheld clip of a beach walk at sunset",
                status: .running,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-300)),
                updatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-10)),
                outputs: []
            )
        ]
    }

    func pollJobIfNeeded(jobID: String) async {
        guard let api else { return }
        do {
            while true {
                let job = try await api.jobs.getJob(id: jobID)
                upsert(job)
                if job.status.isTerminal {
                    break
                }
                try await Task.sleep(for: .seconds(2))
            }
        } catch {
            errorText = displayMessage(for: error)
        }
    }

    func cancel(job: Job) async {
        guard let api else { return }
        do {
            let updated = try await api.jobs.cancelJob(id: job.id)
            upsert(updated)
        } catch {
            errorText = displayMessage(for: error)
        }
    }

    func saveOutput(_ output: JobOutput, for job: Job) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: output.url)
            let savedAsset = try documentsStore.save(
                data: data,
                suggestedFilename: "\(job.modelId)-\(job.id)-\(output.id)",
                mimeType: output.mimeType
            )
            localAssets.insert(savedAsset, at: 0)
        } catch {
            errorText = displayMessage(for: error)
        }
    }

    func loadLocalAssets() async {
        localAssets = documentsStore.loadAssets()
    }

    private func upsert(_ job: Job) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
        } else {
            jobs.insert(job, at: 0)
        }
    }

    private func persistCredentials() {
        let persistedBackendURL = usesMockBackendURL ? backendURLString : activeBackendURLString
        if backendURLString != persistedBackendURL {
            backendURLString = persistedBackendURL
        }
        UserDefaults.standard.set(persistedBackendURL, forKey: "backend_url")
        if accessToken.isEmpty {
            KeychainStore.clearTokens()
        } else {
            if let sessionTokens {
                KeychainStore.saveSessionTokens(sessionTokens)
            } else {
                KeychainStore.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
            }
        }
    }

    private func normalizedBackendURLString(from value: String) -> String? {
        Self.normalizedBackendURLString(from: value, environmentName: environmentName)
    }

    private var usesMockBackendURL: Bool {
        URL(string: backendURLString)?.scheme?.lowercased() == "mock"
    }

    private var hasMockSessionTokens: Bool {
        let access = sessionTokens?.accessToken ?? ""
        let refresh = sessionTokens?.refreshToken ?? ""
        return access.hasPrefix("mock-") || refresh.hasPrefix("mock-")
    }

    private static func normalizedBackendURLString(from value: String?, environmentName: String) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else {
            return nil
        }
        if components.scheme == nil {
            components.scheme = "https"
        }
        guard let url = components.url else {
            return nil
        }
        let isProduction = environmentName == APIEnvironment.production.rawValue
        if isProduction && url.scheme?.lowercased() != "https" {
            return nil
        }
        if url.host?.isEmpty != false {
            return nil
        }
        return url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func failureReason(for error: Error) -> AuthFailureReason {
        if let apiError = error as? APIError {
            switch apiError.category {
            case .unauthorized:
                return refreshToken.isEmpty ? .unauthorized : .refreshExpired
            case .serverError:
                return .backendUnavailable
            case .networkUnavailable:
                return .networkUnavailable
            default:
                return .unknown
            }
        }
        return .unknown
    }

    private func displayMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            var lines: [String] = []
            if let httpStatus = apiError.httpStatus {
                lines.append("HTTP \(httpStatus): \(apiError.message)")
            } else {
                lines.append(apiError.message)
            }
            if let requestMethod = apiError.requestMethod,
               let requestURL = apiError.requestURL,
               !requestMethod.isEmpty,
               !requestURL.isEmpty
            {
                lines.append("Request: \(requestMethod) \(requestURL)")
            }
            if let requestID = apiError.requestID, !requestID.isEmpty {
                lines.append("Request ID: \(requestID)")
            }
            return lines.joined(separator: "\n")
        }
        if let localized = error as? LocalizedError, let message = localized.errorDescription {
            return message
        }
        return String(describing: error)
    }
}
