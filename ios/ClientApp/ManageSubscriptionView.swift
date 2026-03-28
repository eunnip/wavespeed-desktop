import SwiftUI

struct ManageSubscriptionView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var viewModel = SubscriptionViewModel()

    var body: some View {
        List {
            Section("Status") {
                LabeledContent("State", value: session.entitlementState.isActive ? "Active" : "Inactive")
                if let tierName = session.entitlementState.summary?.tierName {
                    LabeledContent("Tier", value: tierName)
                }
                if let usageDescription = session.entitlementState.summary?.usageDescription {
                    Text(usageDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Refresh entitlement") {
                    Task { await session.refreshEntitlement() }
                }
                Button("Restore purchases") {
                    Task {
                        await viewModel.restorePurchasesAndSync { transactions in
                            try await session.restorePurchasedSubscriptions(transactions)
                        }
                    }
                }
                .disabled(viewModel.isRestoring)
                if let managementURL = session.entitlementState.summary?.managementURL ?? session.appConfig.subscriptionManagementURL {
                    Link("Manage in browser", destination: managementURL)
                }
            } header: {
                Text("Actions")
            } footer: {
                Text("Restore submits verified StoreKit transactions to the backend and refreshes entitlements.")
            }
        }
        .navigationTitle("Subscription")
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
