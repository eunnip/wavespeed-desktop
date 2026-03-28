import Foundation

public struct BackendAPI: Sendable {
    public let auth: AuthClient
    public let catalog: CatalogClient
    public let jobs: JobsClient
    public let uploads: UploadsClient
    public let preferences: PreferencesClient

    public init(httpClient: HTTPClient) {
        self.auth = AuthClient(httpClient: httpClient)
        self.catalog = CatalogClient(httpClient: httpClient)
        self.jobs = JobsClient(httpClient: httpClient)
        self.uploads = UploadsClient(httpClient: httpClient)
        self.preferences = PreferencesClient(httpClient: httpClient)
    }
}
