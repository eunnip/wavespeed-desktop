import Foundation

public struct AuthClient: Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func currentUser() async throws -> UserProfile {
        try await httpClient.get("/v1/me")
    }

    public func currentEntitlement() async throws -> EntitlementSummary {
        try await httpClient.get("/v1/me/entitlements")
    }

    public func refreshSession(refreshToken: String) async throws -> SessionTokens {
        try await httpClient.post("/v1/auth/refresh", body: RefreshSessionRequest(refreshToken: refreshToken))
    }

    public func signInWithApple(
        identityToken: String,
        authorizationCode: String?
    ) async throws -> SessionTokens {
        return try await httpClient.post(
            "/v1/auth/sign-in/apple",
            body: AppleSignInRequest(identityToken: identityToken, authorizationCode: authorizationCode)
        )
    }

    public func signOut(refreshToken: String?) async throws -> EmptyAPIResponse {
        try await httpClient.post(
            "/v1/auth/sign-out",
            body: SignOutRequest(refreshToken: refreshToken)
        )
    }

    public func revokeSession(refreshToken: String?) async throws -> EmptyAPIResponse {
        try await httpClient.post(
            "/v1/auth/revoke",
            body: SignOutRequest(refreshToken: refreshToken)
        )
    }

    public func deleteAccount() async throws -> EmptyAPIResponse {
        try await httpClient.postEmpty("/v1/me/delete")
    }

    public func syncAppleSubscription(
        _ request: AppleSubscriptionSyncRequest
    ) async throws -> AppleSubscriptionSyncResult {
        try await httpClient.post("/v1/iap/apple/sync", body: request)
    }

    public func restoreAppleSubscriptions(
        originalTransactionIDs: [String]
    ) async throws -> AppleSubscriptionSyncResult {
        try await httpClient.post(
            "/v1/iap/apple/restore",
            body: AppleSubscriptionRestoreRequest(originalTransactionIDs: originalTransactionIDs)
        )
    }
}
