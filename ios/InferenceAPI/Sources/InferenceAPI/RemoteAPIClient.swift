import Foundation

private struct Envelope<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}

private struct BalanceData: Decodable {
    let balance: Double
}

private struct PricingData: Decodable {
    let unit_price: Double
}

private struct UploadData: Decodable {
    let download_url: String
}

private struct CodeMessage: Decodable {
    let code: Int
    let message: String
}

public struct RemoteAPIClient: Sendable {
    private let config: APIConfiguration
    private let session: URLSession
    private let apiKey: @Sendable () -> String

    public init(
        configuration: APIConfiguration = APIConfiguration(),
        session: URLSession = .shared,
        apiKey: @escaping @Sendable () -> String
    ) {
        self.config = configuration
        self.session = session
        self.apiKey = apiKey
    }

    public func listModels() async throws -> [ModelInfo] {
        let (data, response) = try await dataRequest(
            path: "/api/v3/models",
            method: "GET",
            body: nil as Data?
        )
        try throwIfHTTPError(response, data: data)
        let env = try decode(Envelope<[ModelInfo]>.self, from: data)
        try ensureOK(env)
        guard let models = env.data else {
            throw InferenceAPIError(message: env.message, code: env.code)
        }
        return models
    }

    public func runPrediction(
        model: String,
        input: [String: Any],
        timeoutSeconds: TimeInterval = 60
    ) async throws -> PredictionResult {
        let body = try JSONSerialization.data(withJSONObject: input)
        let (data, response) = try await dataRequest(
            path: "/api/v3/\(model)",
            method: "POST",
            body: body,
            timeout: timeoutSeconds
        )
        try throwIfHTTPError(response, data: data)
        let env = try decode(Envelope<PredictionResult>.self, from: data)
        try ensureOK(env)
        guard let result = env.data else {
            throw InferenceAPIError(message: env.message, code: env.code)
        }
        return result
    }

    public func getResult(predictionId: String) async throws -> PredictionResult {
        let (data, response) = try await dataRequest(
            path: "/api/v3/predictions/\(predictionId)/result",
            method: "GET",
            body: nil as Data?
        )
        try throwIfHTTPError(response, data: data)
        let env = try decode(Envelope<PredictionResult>.self, from: data)
        try ensureOK(env)
        guard let result = env.data else {
            throw InferenceAPIError(message: env.message, code: env.code)
        }
        return result
    }

    /// Submits a job and polls until completed, failed, or timeout.
    public func run(
        model: String,
        input: [String: Any],
        pollInterval: TimeInterval = 1,
        timeout: TimeInterval = 3600,
        enableSyncMode: Bool = false,
        cancellation: (@Sendable () -> Bool)? = nil
    ) async throws -> PredictionResult {
        if enableSyncMode {
            var payload = input
            payload["enable_sync_mode"] = true
            return try await runPrediction(model: model, input: payload, timeoutSeconds: 120)
        }

        let prediction = try await runPrediction(model: model, input: input)
        guard !prediction.id.isEmpty else {
            throw InferenceAPIError(message: "Missing prediction id")
        }
        let requestId = prediction.id

        let start = Date()
        var consecutiveErrors = 0

        while true {
            if cancellation?() == true {
                throw CancellationError()
            }
            if Date().timeIntervalSince(start) > timeout {
                throw InferenceAPIError(message: "Prediction timed out")
            }

            do {
                let result = try await getResult(predictionId: requestId)
                consecutiveErrors = 0

                if result.status == "completed" {
                    return result
                }
                if result.status == "failed" {
                    throw InferenceAPIError(message: result.error ?? "Prediction failed")
                }
            } catch let error as URLError {
                if cancellation?() == true { throw CancellationError() }
                if isConnectionError(error) || error.code == .timedOut {
                    consecutiveErrors += 1
                    let backoffNs = min(
                        UInt64(1_000_000_000 * pow(2.0, Double(consecutiveErrors - 1))),
                        10_000_000_000
                    )
                    try await Task.sleep(nanoseconds: backoffNs)
                    continue
                }
                throw error
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if cancellation?() == true { throw CancellationError() }
                throw error
            }

            if cancellation?() == true {
                throw CancellationError()
            }
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }

    public func getHistory(
        page: Int = 1,
        pageSize: Int = 20,
        createdAfter: Date? = nil,
        createdBefore: Date? = nil
    ) async throws -> HistoryPage {
        let now = createdBefore ?? Date()
        let defaultStart = createdAfter ?? Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let body: [String: Any] = [
            "page": page,
            "page_size": pageSize,
            "created_after": formatter.string(from: defaultStart),
            "created_before": formatter.string(from: now),
            "include_inputs": true,
        ]

        let dataBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await dataRequest(
            path: "/api/v3/predictions",
            method: "POST",
            body: dataBody
        )
        try throwIfHTTPError(response, data: data)
        let env = try decode(Envelope<HistoryPage>.self, from: data)
        try ensureOK(env)
        guard let pageData = env.data else {
            throw InferenceAPIError(message: env.message, code: env.code)
        }
        return pageData
    }

    public func deletePredictions(ids: [String]) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["ids": ids])
        let (data, response) = try await dataRequest(
            path: "/api/v3/predictions/delete",
            method: "POST",
            body: body
        )
        try throwIfHTTPError(response, data: data)
        let env = try decode(CodeMessage.self, from: data)
        guard env.code == 200 else {
            throw InferenceAPIError(message: env.message, code: env.code)
        }
    }

    public func uploadFile(fileURL: URL) async throws -> String {
        let data = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        return try await uploadBinary(data: data, filename: filename)
    }

    public func uploadBinary(
        data: Data,
        filename: String,
        mimeType: String = "application/octet-stream"
    ) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let minTimeout: TimeInterval = 120
        let maxTimeout: TimeInterval = 600
        let mb = Double(data.count) / (1024 * 1024)
        let timeout = min(maxTimeout, max(minTimeout, ceil(mb) + minTimeout))

        let (respData, response) = try await dataRequest(
            path: "/api/v3/media/upload/binary",
            method: "POST",
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)",
            timeout: timeout
        )
        try throwIfHTTPError(response, data: respData)
        let env = try decode(Envelope<UploadData>.self, from: respData)
        try ensureOK(env)
        guard let url = env.data?.download_url else {
            throw InferenceAPIError(message: env.message, code: env.code)
        }
        return url
    }

    public func getBalance() async throws -> Double {
        let (data, response) = try await dataRequest(
            path: "/api/v3/balance",
            method: "GET",
            body: nil as Data?
        )
        try throwIfHTTPError(response, data: data)
        let env = try decode(Envelope<BalanceData>.self, from: data)
        try ensureOK(env)
        guard let balance = env.data?.balance else {
            throw InferenceAPIError(message: env.message, code: env.code)
        }
        return balance
    }

    public func calculatePricing(modelId: String, inputs: [String: Any]) async throws -> Double {
        let body = try JSONSerialization.data(withJSONObject: ["model_id": modelId, "inputs": inputs])
        let (data, response) = try await dataRequest(
            path: "/api/v3/model/pricing",
            method: "POST",
            body: body
        )
        try throwIfHTTPError(response, data: data)
        let env = try decode(Envelope<PricingData>.self, from: data)
        try ensureOK(env)
        guard let price = env.data?.unit_price else {
            throw InferenceAPIError(message: env.message, code: env.code)
        }
        return price
    }

    // MARK: - Private

    private func dataRequest(
        path: String,
        method: String,
        body: Data?,
        contentType: String = "application/json",
        timeout: TimeInterval = 60
    ) async throws -> (Data, URLResponse) {
        guard let url = URL(string: path, relativeTo: config.baseURL)?.absoluteURL else {
            throw InferenceAPIError(message: "Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(config.clientName, forHTTPHeaderField: "X-Client-Name")
        request.setValue(config.clientVersion, forHTTPHeaderField: "X-Client-Version")
        request.setValue(config.clientOS, forHTTPHeaderField: "X-Client-OS")
        let key = apiKey()
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        return try await session.data(for: request)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func ensureOK<T>(_ env: Envelope<T>) throws {
        if env.code != 200 {
            throw InferenceAPIError(message: env.message, code: env.code)
        }
    }

    private func throwIfHTTPError(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ..< 300).contains(http.statusCode) else {
            let message = Self.parseErrorMessage(data: data) ?? "HTTP \(http.statusCode)"
            throw InferenceAPIError(message: message, httpStatus: http.statusCode, details: data)
        }
    }

    private static func parseErrorMessage(data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let m = obj["message"] as? String { return m }
        if let e = obj["error"] as? String { return e }
        if let d = obj["detail"] as? String { return d }
        return nil
    }

    private func isConnectionError(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}
