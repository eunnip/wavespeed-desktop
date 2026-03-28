import Foundation
import StoreKit

@MainActor
final class SubscriptionViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var isPurchasing = false
    @Published var isRestoring = false
    @Published var errorText: String?

    private let service = StoreKitService()

    func loadProducts(productIDs: [String]) async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            products = try await service.loadProducts(productIDs: productIDs)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        errorText = nil
        defer { isPurchasing = false }
        do {
            _ = try await service.purchase(product)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func restorePurchases() async {
        isRestoring = true
        errorText = nil
        defer { isRestoring = false }
        do {
            _ = try await service.restorePurchases()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func purchaseAndSync(
        _ product: Product,
        sync: @escaping @Sendable (VerifiedStoreTransaction) async throws -> Void
    ) async {
        isPurchasing = true
        errorText = nil
        defer { isPurchasing = false }
        do {
            let transaction = try await service.purchase(product)
            try await sync(transaction)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func restorePurchasesAndSync(
        sync: @escaping @Sendable ([VerifiedStoreTransaction]) async throws -> Void
    ) async {
        isRestoring = true
        errorText = nil
        defer { isRestoring = false }
        do {
            let transactions = try await service.restorePurchases()
            try await sync(transactions)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}
