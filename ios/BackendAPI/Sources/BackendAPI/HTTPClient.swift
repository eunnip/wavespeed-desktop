import Foundation

private struct APIEnvelope<T: Decodable>: Decodable {
    let data: T?
    let error: String?
    let message: String?
    let code: Int?
    let requestId: String?
}

private struct EmptyBody: Encodable {}
public struct EmptyAPIResponse: Codable, Sendable {}

public final class HTTPClient: @unchecked Sendable {
    private let session: URLSession
    private let accessTokenProvider: @Sendable () async -> String?
    private let accessTokenRefresher: (@Sendable () async throws -> String?)?
    public let configuration: APIConfiguration

    public init(
        configuration: APIConfiguration,
        session: URLSession = .shared,
        accessTokenProvider: @escaping @Sendable () async -> String?,
        accessTokenRefresher: (@Sendable () async throws -> String?)? = nil
    ) {
        self.configuration = configuration
        self.session = session
        self.accessTokenProvider = accessTokenProvider
        self.accessTokenRefresher = accessTokenRefresher
    }

    public func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        try await request(path, method: "GET", queryItems: queryItems, body: Optional<String>.none)
    }

    public func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body
    ) async throws -> Response {
        try await request(path, method: "POST", queryItems: [], body: body)
    }

    public func patch<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body
    ) async throws -> Response {
        try await request(path, method: "PATCH", queryItems: [], body: body)
    }

    public func postEmpty<Response: Decodable>(_ path: String) async throws -> Response {
        return try await request(path, method: "POST", queryItems: [], body: EmptyBody())
    }

    public func upload(
        _ path: String,
        data: Data,
        filename: String,
        mimeType: String
    ) async throws -> UploadReceipt {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(
                using: .utf8
            )!
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let request = try makeRequest(
            path,
            method: "POST",
            queryItems: [],
            contentType: "multipart/form-data; boundary=\(boundary)",
            body: body,
            accessToken: await accessTokenProvider()
        )
        let (responseData, response) = try await session.data(for: request)
        try validateHTTP(response, data: responseData)
        return try decodeEnvelope(UploadReceipt.self, from: responseData)
    }

    private func request<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: Body
    ) async throws -> Response {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let encoded = try encoder.encode(body)
        let token = await accessTokenProvider()
        let request = try makeRequest(
            path,
            method: method,
            queryItems: queryItems,
            body: encoded,
            accessToken: token
        )
        let (responseData, response) = try await session.data(for: request)
        do {
            try validateHTTP(response, data: responseData)
            return try decodeEnvelope(Response.self, from: responseData)
        } catch let error as APIError where error.isUnauthorized {
            guard let accessTokenRefresher else {
                throw error
            }
            let refreshedToken = try await accessTokenRefresher()
            guard let refreshedToken, !refreshedToken.isEmpty else {
                throw error
            }
            let retryRequest = try makeRequest(
                path,
                method: method,
                queryItems: queryItems,
                body: encoded,
                accessToken: refreshedToken
            )
            let (retryData, retryResponse) = try await session.data(for: retryRequest)
            try validateHTTP(retryResponse, data: retryData)
            return try decodeEnvelope(Response.self, from: retryData)
        }
    }

    private func makeRequest(
        _ path: String,
        method: String,
        queryItems: [URLQueryItem],
        contentType: String = "application/json",
        body: Data? = nil,
        accessToken: String? = nil
    ) throws -> URLRequest {
        if configuration.requiresHTTPS,
           configuration.environment != .mock,
           configuration.baseURL.scheme?.lowercased() != "https" {
            throw APIError(message: "HTTPS is required for this environment.")
        }
        guard var components = URLComponents(
            url: configuration.baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError(message: "Invalid URL")
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError(message: "Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 60
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(configuration.clientName, forHTTPHeaderField: "X-Client-Name")
        request.setValue(configuration.clientVersion, forHTTPHeaderField: "X-Client-Version")
        request.setValue(configuration.clientOS, forHTTPHeaderField: "X-Client-OS")
        request.setValue(configuration.environment.rawValue, forHTTPHeaderField: "X-Client-Environment")
        request.setValue(configuration.apiVersion, forHTTPHeaderField: "X-API-Version")
        if let token = accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func decodeEnvelope<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        if let envelope = try? decoder.decode(APIEnvelope<T>.self, from: data), let payload = envelope.data {
            return payload
        }
        if let value = try? decoder.decode(T.self, from: data) {
            return value
        }
        if let envelope = try? decoder.decode(APIEnvelope<T>.self, from: data) {
            throw APIError(
                message: envelope.error ?? envelope.message ?? "Unexpected API response",
                code: envelope.code,
                category: .decodingFailed,
                requestID: envelope.requestId
            )
        }
        throw APIError(
            message: "Could not decode API response",
            details: data,
            category: .decodingFailed
        )
    }

    private func validateHTTP(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            return
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            let message = extractMessage(from: data) ?? "HTTP \(http.statusCode)"
            throw APIError(
                message: message,
                httpStatus: http.statusCode,
                details: data,
                category: category(for: http.statusCode, message: message),
                requestID: http.value(forHTTPHeaderField: "X-Request-ID")
                    ?? http.value(forHTTPHeaderField: "X-Correlation-ID"),
                retryAfterSeconds: Int(http.value(forHTTPHeaderField: "Retry-After") ?? "")
            )
        }
    }

    private func category(for statusCode: Int, message: String) -> APIErrorCategory {
        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            if message.localizedCaseInsensitiveContains("quota") {
                return .quotaExceeded
            }
            return .forbidden
        case 409, 422:
            return .validationFailed
        case 429:
            return .rateLimited
        case 500 ... 599:
            return .serverError
        default:
            return .unknown
        }
    }

    private func extractMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let message = object["message"] as? String {
            return message
        }
        if let message = object["error"] as? String {
            return message
        }
        if let message = object["detail"] as? String {
            return message
        }
        return nil
    }
}
