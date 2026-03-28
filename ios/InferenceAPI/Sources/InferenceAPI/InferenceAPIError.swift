import Foundation

public struct InferenceAPIError: Error, LocalizedError, Sendable {
    public let message: String
    public let code: Int?
    public let httpStatus: Int?
    public let details: Data?

    public init(
        message: String,
        code: Int? = nil,
        httpStatus: Int? = nil,
        details: Data? = nil
    ) {
        self.message = message
        self.code = code
        self.httpStatus = httpStatus
        self.details = details
    }

    public var errorDescription: String? { message }
}
