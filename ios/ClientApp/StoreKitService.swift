import Foundation
import StoreKit

@MainActor
final class StoreKitService {
    func loadProducts(productIDs: [String]) async throws -> [Product] {
        guard !productIDs.isEmpty else {
            return []
        }
        return try await Product.products(for: productIDs)
    }

    func purchase(_ product: Product) async throws -> Product.PurchaseResult {
        try await product.purchase()
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
    }
}
