import Foundation

public struct UploadsClient: Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func uploadImageData(
        _ data: Data,
        filename: String = "input.jpg",
        mimeType: String = "image/jpeg"
    ) async throws -> UploadReceipt {
        try await httpClient.upload("/v1/uploads", data: data, filename: filename, mimeType: mimeType)
    }
}
