import Foundation
import StoreKit

struct VerifiedStoreTransaction: Sendable {
    let productID: String
    let transactionID: String
    let originalTransactionID: String?
    let appAccountToken: UUID?
    let signedTransactionInfo: String?
}

enum StoreKitServiceError: LocalizedError {
    case pending
    case cancelled
    case unverified
    case noActiveTransactions

    var errorDescription: String? {
        switch self {
        case .pending:
            return "The purchase is pending approval."
        case .cancelled:
            return "The purchase was cancelled."
        case .unverified:
            return "StoreKit returned an unverified transaction."
        case .noActiveTransactions:
            return "No verified App Store transactions were available to restore."
        }
    }
}

@MainActor
final class StoreKitService {
    func loadProducts(productIDs: [String]) async throws -> [Product] {
        guard !productIDs.isEmpty else {
            return []
        }
        return try await Product.products(for: productIDs)
    }

    func purchase(_ product: Product) async throws -> VerifiedStoreTransaction {
        let result = try await product.purchase()
        switch result {
        case .success(let verificationResult):
            let transaction = try verifiedTransaction(from: verificationResult)
            await transaction.finish()
            return mappedTransaction(from: transaction)
        case .pending:
            throw StoreKitServiceError.pending
        case .userCancelled:
            throw StoreKitServiceError.cancelled
        @unknown default:
            throw StoreKitServiceError.cancelled
        }
    }

    func restorePurchases() async throws -> [VerifiedStoreTransaction] {
        try await AppStore.sync()
        let transactions = try await currentEntitlements()
        guard !transactions.isEmpty else {
            throw StoreKitServiceError.noActiveTransactions
        }
        return transactions
    }

    func currentEntitlements() async throws -> [VerifiedStoreTransaction] {
        var transactions: [VerifiedStoreTransaction] = []
        for await entitlement in Transaction.currentEntitlements {
            let transaction = try verifiedTransaction(from: entitlement)
            transactions.append(mappedTransaction(from: transaction))
        }
        return transactions
    }

    private func verifiedTransaction<T>(
        from result: VerificationResult<T>
    ) throws -> T {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw StoreKitServiceError.unverified
        }
    }

    private func mappedTransaction(from transaction: Transaction) -> VerifiedStoreTransaction {
        VerifiedStoreTransaction(
            productID: transaction.productID,
            transactionID: String(transaction.id),
            originalTransactionID: String(transaction.originalID),
            appAccountToken: transaction.appAccountToken,
            signedTransactionInfo: nil
        )
    }
}
