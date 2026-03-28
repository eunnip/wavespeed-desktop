import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("User", value: session.user?.displayName ?? session.user?.email ?? "Unknown")
                    LabeledContent("Backend", value: session.backendURLString)
                }

                Section("Subscription") {
                    LabeledContent("Status", value: session.entitlement?.isActive == true ? "Active" : "Inactive")
                    if let tierName = session.entitlement?.tierName {
                        LabeledContent("Tier", value: tierName)
                    }
                    if let usageDescription = session.entitlement?.usageDescription {
                        Text(usageDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let managementURL = session.entitlement?.managementURL ?? session.appConfig.subscriptionManagementURL {
                        Link("Manage subscription", destination: managementURL)
                    }
                    NavigationLink("Subscription details") {
                        ManageSubscriptionView()
                    }
                }

                Section("Support") {
                    if let privacyURL = session.appConfig.privacyURL {
                        Link("Privacy policy", destination: privacyURL)
                    }
                    if let termsURL = session.appConfig.termsURL {
                        Link("Terms of service", destination: termsURL)
                    }
                    if let supportEmail = session.appConfig.supportEmail,
                       let supportURL = URL(string: "mailto:\(supportEmail)") {
                        Link("Email support", destination: supportURL)
                    }
                }

                Section {
                    Button("Refresh account") {
                        Task { await session.refreshSessionData() }
                    }
                    Button("Sign out", role: .destructive) {
                        session.signOut()
                    }
                } footer: {
                    Text("StoreKit purchase and receipt sync should be added on top of this account surface once your backend entitlement endpoints are finalized.")
                }
            }
            .navigationTitle("Account")
        }
    }
}
