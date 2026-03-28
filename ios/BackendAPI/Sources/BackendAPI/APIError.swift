import Foundation

public enum APIErrorCategory: String, Sendable {
    case unauthorized
    case forbidden
    case validationFailed
    case rateLimited
    case quotaExceeded
    case serverError
    case networkUnavailable
    case decodingFailed
    case unknown
}

public struct APIError: Error, LocalizedError, Sendable {
    public let message: String
    public let code: Int?
    public let httpStatus: Int?
    public let details: Data?
    public let category: APIErrorCategory
    public let requestID: String?
    public let retryAfterSeconds: Int?

    public init(
        message: String,
        code: Int? = nil,
        httpStatus: Int? = nil,
        details: Data? = nil,
        category: APIErrorCategory = .unknown,
        requestID: String? = nil,
        retryAfterSeconds: Int? = nil
    ) {
        self.message = message
        self.code = code
        self.httpStatus = httpStatus
        self.details = details
        self.category = category
        self.requestID = requestID
        self.retryAfterSeconds = retryAfterSeconds
    }

    public var errorDescription: String? {
        message
    }

    public var isUnauthorized: Bool {
        category == .unauthorized
    }

    public var isRetriable: Bool {
        switch category {
        case .rateLimited, .serverError, .networkUnavailable:
            return true
        case .unauthorized, .forbidden, .validationFailed, .quotaExceeded, .decodingFailed, .unknown:
            return false
        }
    }
}
