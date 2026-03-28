import Foundation

/// Central place for service endpoints and client identification (no product branding).
public struct APIConfiguration: Sendable {
    public var baseURL: URL
    /// Sent as `X-Client-Name` (e.g. bundle identifier or a neutral internal label).
    public var clientName: String
    /// Sent as `X-Client-Version` (e.g. app marketing version).
    public var clientVersion: String
    /// Sent as `X-Client-OS` (e.g. `ios`).
    public var clientOS: String

    public init(
        baseURL: URL = URL(string: "https://api.wavespeed.ai")!,
        clientName: String = "ios-client",
        clientVersion: String = "1.0",
        clientOS: String = "ios"
    ) {
        self.baseURL = baseURL
        self.clientName = clientName
        self.clientVersion = clientVersion
        self.clientOS = clientOS
    }
}
