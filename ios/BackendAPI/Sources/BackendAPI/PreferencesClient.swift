import Foundation

public struct PreferencesClient: Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func appConfig() async throws -> AppConfig {
        try await httpClient.get("/v1/app/config")
    }
}
