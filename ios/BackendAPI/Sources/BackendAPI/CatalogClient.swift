import Foundation

public struct CatalogClient: Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func listModels() async throws -> [CatalogModel] {
        try await httpClient.get("/v1/catalog/models")
    }

    public func appConfig() async throws -> AppConfig {
        try await httpClient.get("/v1/app/config")
    }
}
