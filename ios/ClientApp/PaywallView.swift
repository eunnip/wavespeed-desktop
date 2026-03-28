import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SubscriptionViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Unlock generation")
                        .font(.title2.bold())
                    Text("Purchases should be handled with StoreKit 2 and then synced to your backend entitlement endpoints.")
                        .foregroundStyle(.secondary)
                }

                if !session.subscriptionProductIDs.isEmpty {
                    Section("Plans") {
                        if viewModel.isLoading {
                            ProgressView()
                        } else if viewModel.products.isEmpty {
                            Text("No subscription products are configured yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.products, id: \.id) { product in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(product.displayName)
                                    Text(product.displayPrice)
                                        .foregroundStyle(.secondary)
                                    Button("Purchase") {
                                        Task {
                                            await viewModel.purchaseAndSync(product) { transaction in
                                                try await session.syncPurchasedSubscription(transaction)
                                            }
                                        }
                                    }
                                    .disabled(viewModel.isPurchasing)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Section("Developer fallback") {
                    Text("If backend entitlement sync is unavailable, use the developer connection from the welcome screen for token-based testing.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Subscription")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.loadProducts(productIDs: session.subscriptionProductIDs)
            }
            .alert("StoreKit", isPresented: Binding(
                get: { viewModel.errorText != nil },
                set: { value in
                    if !value { viewModel.errorText = nil }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorText ?? "")
            }
        }
    }
}
