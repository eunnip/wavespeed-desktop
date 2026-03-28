import Foundation

public struct SessionTokens: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: String?
    public let tokenType: String
    public let user: UserProfile?
    public let entitlements: EntitlementSummary?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: String? = nil,
        tokenType: String = "Bearer",
        user: UserProfile? = nil,
        entitlements: EntitlementSummary? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tokenType = tokenType
        self.user = user
        self.entitlements = entitlements
    }

    public var expiryDate: Date? {
        guard let expiresAt else { return nil }
        return SessionTokens.iso8601Fractional.date(from: expiresAt)
            ?? SessionTokens.iso8601.date(from: expiresAt)
    }

    public func isExpired(relativeTo date: Date = Date(), leeway: TimeInterval = 30) -> Bool {
        guard let expiryDate else { return false }
        return expiryDate <= date.addingTimeInterval(leeway)
    }

    public var shouldRefresh: Bool {
        accessToken.isEmpty || isExpired(leeway: 5 * 60)
    }

    public var authorizationHeaderValue: String {
        "\(tokenType) \(accessToken)"
    }

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

public struct AppleSignInRequest: Codable, Sendable {
    public let identityToken: String
    public let authorizationCode: String?

    public init(identityToken: String, authorizationCode: String? = nil) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
    }
}

public struct RefreshSessionRequest: Codable, Sendable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

public struct SignOutRequest: Codable, Sendable {
    public let refreshToken: String?
    public let revokeAllSessions: Bool

    public init(refreshToken: String? = nil, revokeAllSessions: Bool = false) {
        self.refreshToken = refreshToken
        self.revokeAllSessions = revokeAllSessions
    }
}

public struct AppleSubscriptionSyncRequest: Codable, Sendable {
    public let productID: String
    public let transactionID: String
    public let originalTransactionID: String?
    public let appAccountToken: UUID?
    public let signedTransactionInfo: String?

    public init(
        productID: String,
        transactionID: String,
        originalTransactionID: String? = nil,
        appAccountToken: UUID? = nil,
        signedTransactionInfo: String? = nil
    ) {
        self.productID = productID
        self.transactionID = transactionID
        self.originalTransactionID = originalTransactionID
        self.appAccountToken = appAccountToken
        self.signedTransactionInfo = signedTransactionInfo
    }
}

public struct AppleSubscriptionRestoreRequest: Codable, Sendable {
    public let originalTransactionIDs: [String]

    public init(originalTransactionIDs: [String]) {
        self.originalTransactionIDs = originalTransactionIDs
    }
}

public struct AppleSubscriptionSyncResult: Codable, Sendable {
    public let accepted: Bool
    public let entitlement: EntitlementSummary?
    public let message: String?

    public init(
        accepted: Bool,
        entitlement: EntitlementSummary? = nil,
        message: String? = nil
    ) {
        self.accepted = accepted
        self.entitlement = entitlement
        self.message = message
    }
}

public struct UserProfile: Codable, Sendable, Identifiable {
    public let id: String
    public let displayName: String?
    public let email: String?
}

public struct EntitlementSummary: Codable, Sendable {
    public let isActive: Bool
    public let tierName: String?
    public let renewalDate: String?
    public let usageDescription: String?
    public let managementURL: URL?
}

public struct AppConfig: Codable, Sendable {
    public let supportEmail: String?
    public let privacyURL: URL?
    public let termsURL: URL?
    public let subscriptionManagementURL: URL?
    public let featuredModelIds: [String]

    public init(
        supportEmail: String? = nil,
        privacyURL: URL? = nil,
        termsURL: URL? = nil,
        subscriptionManagementURL: URL? = nil,
        featuredModelIds: [String] = []
    ) {
        self.supportEmail = supportEmail
        self.privacyURL = privacyURL
        self.termsURL = termsURL
        self.subscriptionManagementURL = subscriptionManagementURL
        self.featuredModelIds = featuredModelIds
    }
}

public struct CatalogModel: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let summary: String?
    public let kind: String?
    public let thumbnailURL: URL?
    public let requiresImageInput: Bool

    public init(
        id: String,
        name: String,
        summary: String? = nil,
        kind: String? = nil,
        thumbnailURL: URL? = nil,
        requiresImageInput: Bool = false
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.kind = kind
        self.thumbnailURL = thumbnailURL
        self.requiresImageInput = requiresImageInput
    }
}

public struct JobOutput: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let url: URL
    public let mimeType: String?

    public init(id: String, url: URL, mimeType: String? = nil) {
        self.id = id
        self.url = url
        self.mimeType = mimeType
    }
}

public enum JobStatus: String, Codable, Sendable {
    case queued
    case running
    case completed
    case failed
    case canceled

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .canceled:
            return true
        case .queued, .running:
            return false
        }
    }
}

public struct Job: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let modelId: String
    public let modelName: String?
    public let prompt: String?
    public let status: JobStatus
    public let createdAt: String?
    public let updatedAt: String?
    public let errorMessage: String?
    public let outputs: [JobOutput]

    public init(
        id: String,
        modelId: String,
        modelName: String? = nil,
        prompt: String? = nil,
        status: JobStatus,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        errorMessage: String? = nil,
        outputs: [JobOutput] = []
    ) {
        self.id = id
        self.modelId = modelId
        self.modelName = modelName
        self.prompt = prompt
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.errorMessage = errorMessage
        self.outputs = outputs
    }
}

public struct JobPage: Codable, Sendable {
    public let items: [Job]
    public let nextCursor: String?

    public init(items: [Job], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct CreateJobRequest: Codable, Sendable {
    public let modelId: String
    public let prompt: String
    public let negativePrompt: String?
    public let imageURL: URL?
    public let parameters: [String: JSONValue]

    public init(
        modelId: String,
        prompt: String,
        negativePrompt: String? = nil,
        imageURL: URL? = nil,
        parameters: [String: JSONValue] = [:]
    ) {
        self.modelId = modelId
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.imageURL = imageURL
        self.parameters = parameters
    }
}

public struct UploadReceipt: Codable, Sendable {
    public let id: String
    public let fileURL: URL
    public let mimeType: String?
}

public struct EmptyResponse: Codable, Sendable {
    public init() {}
}
