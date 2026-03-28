import Foundation

public struct JobsClient: Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func createJob(_ request: CreateJobRequest) async throws -> Job {
        try await httpClient.post("/v1/jobs", body: request)
    }

    public func getJob(id: String) async throws -> Job {
        try await httpClient.get("/v1/jobs/\(id)")
    }

    public func listJobs(cursor: String? = nil) async throws -> JobPage {
        let queryItems: [URLQueryItem] = cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? []
        return try await httpClient.get("/v1/jobs", queryItems: queryItems)
    }

    public func cancelJob(id: String) async throws -> Job {
        try await httpClient.postEmpty("/v1/jobs/\(id)/cancel")
    }
}
