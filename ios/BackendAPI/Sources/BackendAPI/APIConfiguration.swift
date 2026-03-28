import Foundation

public enum APIEnvironment: String, Sendable {
    case mock
    case development
    case staging
    case production
}

public struct APIConfiguration: Sendable {
    public var baseURL: URL
    public var clientName: String
    public var clientVersion: String
    public var clientOS: String
    public var environment: APIEnvironment
    public var apiVersion: String
    public var requiresHTTPS: Bool

    public init(
        baseURL: URL,
        clientName: String = "ios-client",
        clientVersion: String = "1.0",
        clientOS: String = "ios",
        environment: APIEnvironment = .production,
        apiVersion: String = "v1",
        requiresHTTPS: Bool = true
    ) {
        self.baseURL = baseURL
        self.clientName = clientName
        self.clientVersion = clientVersion
        self.clientOS = clientOS
        self.environment = environment
        self.apiVersion = apiVersion
        self.requiresHTTPS = requiresHTTPS
    }
}
