import Foundation

enum AuthState: String {
    case signedOut
    case restoring
    case signedIn
    case refreshing
    case failed
}

enum EntitlementSource: String {
    case backend
    case storekitPending
    case stale
    case unavailable
}

struct EntitlementState {
    var summary: EntitlementSummary?
    var lastRefreshedAt: Date?
    var source: EntitlementSource = .unavailable

    var isActive: Bool {
        summary?.isActive == true
    }
}

struct StoreKitState {
    var productIDs: [String] = []
    var isLoadingProducts = false
    var isPurchasing = false
    var isRestoring = false
}
