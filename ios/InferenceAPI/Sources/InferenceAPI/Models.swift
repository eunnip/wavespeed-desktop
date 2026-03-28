import Foundation

public struct ModelInfo: Decodable, Sendable, Identifiable {
    public var id: String { model_id }
    public let model_id: String
    public let name: String
    public let description: String?
    public let type: String?
    public let base_price: Double?
    public let sort_order: Int?
}

public struct PredictionResult: Decodable, Sendable {
    public let id: String
    public let model: String
    public let status: String
    public let outputs: [JSONValue]?
    public let error: String?
    public let has_nsfw_contents: [Bool]?
    public let created_at: String?
}

public struct HistoryPage: Decodable, Sendable {
    public let page: Int
    public let total: Int
    public let items: [HistoryItem]
}

public struct HistoryItem: Decodable, Sendable, Identifiable {
    public let id: String
    public let model: String
    public let status: String
    public let outputs: [JSONValue]?
    public let created_at: String
    public let execution_time: Double?
    public let inputs: [String: JSONValue]?
    public let input: [String: JSONValue]?
}
