import SwiftUI

struct AuthGatewayView: View {
    @EnvironmentObject private var session: AppSession
    @State private var showDeveloperOptions = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Start with your account")
                            .font(.title2.bold())
                        Text("This iOS app is built to authenticate against your backend and unlock generation through your subscription state.")
                            .foregroundStyle(.secondary)
                        SignInWithAppleButtonView()
                    }
                    .padding(.vertical, 8)
                }

                Section("Environment") {
                    LabeledContent("Backend", value: session.backendURLString)
                    LabeledContent("Environment", value: session.environmentName)
                    if session.isMockEnvironment {
                        Text("Mock mode is active. The app is using local sample auth, models, entitlements, and jobs.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if session.isDeveloperMode {
                        Text("Developer mode is enabled. Manual backend token sign-in is available for testing.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if session.isDeveloperMode {
                    Section {
                        DisclosureGroup("Developer connection", isExpanded: $showDeveloperOptions) {
                            SignInView(showsNavigationChrome: false)
                        }
                    } footer: {
                        Text("Use the developer connection only until your production auth endpoint and Sign in with Apple exchange flow are live.")
                    }
                }

                if let failureReason = session.authFailureReason {
                    Section("Sign-in status") {
                        Text(failureReason.guidance)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Welcome")
        }
    }
}
