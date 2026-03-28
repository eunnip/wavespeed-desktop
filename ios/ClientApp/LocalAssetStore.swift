import Foundation

struct LocalAsset: Codable, Identifiable, Hashable {
    let id: String
    let filename: String
    let createdAt: Date
    let mimeType: String?

    var fileURL: URL {
        LocalAssetStore.directoryURL.appending(path: filename)
    }
}

struct LocalAssetStore {
    static let directoryURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: "SavedOutputs", directoryHint: .isDirectory)
    }()

    private var indexURL: URL {
        Self.directoryURL.appending(path: "index.json")
    }

    func loadAssets() -> [LocalAsset] {
        do {
            try createDirectoryIfNeeded()
            let data = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([LocalAsset].self, from: data)
                .sorted(by: { $0.createdAt > $1.createdAt })
        } catch {
            return []
        }
    }

    func save(data: Data, suggestedFilename: String, mimeType: String?) throws -> LocalAsset {
        try createDirectoryIfNeeded()
        let ext = preferredFileExtension(from: mimeType)
        let asset = LocalAsset(
            id: UUID().uuidString,
            filename: "\(suggestedFilename)-\(UUID().uuidString.prefix(6)).\(ext)",
            createdAt: Date(),
            mimeType: mimeType
        )
        try data.write(to: asset.fileURL)
        var assets = loadAssets()
        assets.insert(asset, at: 0)
        try persist(assets)
        return asset
    }

    private func persist(_ assets: [LocalAsset]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(assets)
        try data.write(to: indexURL, options: .atomic)
    }

    private func createDirectoryIfNeeded() throws {
        try FileManager.default.createDirectory(
            at: Self.directoryURL,
            withIntermediateDirectories: true
        )
    }

    private func preferredFileExtension(from mimeType: String?) -> String {
        switch mimeType {
        case "image/jpeg":
            return "jpg"
        case "image/webp":
            return "webp"
        case "video/mp4":
            return "mp4"
        default:
            return "png"
        }
    }
}
