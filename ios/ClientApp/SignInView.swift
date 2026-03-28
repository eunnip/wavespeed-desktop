import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var session: AppSession
    let showsNavigationChrome: Bool
    @State private var backendURL = ""
    @State private var accessToken = ""
    @State private var refreshToken = ""

    init(showsNavigationChrome: Bool = true) {
        self.showsNavigationChrome = showsNavigationChrome
    }

    var body: some View {
        Group {
            if showsNavigationChrome {
                NavigationStack {
                    developerConnectionForm
                        .navigationTitle("Welcome")
                }
            } else {
                developerConnectionForm
            }
        }
        .onAppear {
            backendURL = session.backendURLString
            accessToken = session.accessToken
            refreshToken = session.refreshToken
        }
    }

    private var developerConnectionForm: some View {
        Form {
            Section("Backend") {
                TextField("https://api.yourproduct.com", text: $backendURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Access token", text: $accessToken)
                    .textContentType(.password)
                SecureField("Refresh token (optional)", text: $refreshToken)
                    .textContentType(.password)
            }

            Section {
                Button {
                    Task {
                        await session.signIn(
                            backendURLString: backendURL,
                            accessToken: accessToken,
                            refreshToken: refreshToken
                        )
                    }
                } label: {
                    if session.isBusy {
                        ProgressView()
                    } else {
                        Text("Connect")
                    }
                }
                .disabled(backendURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || accessToken.isEmpty)
                Button("Use mock backend") {
                    Task {
                        await session.signIn(
                            backendURLString: "mock://local",
                            accessToken: "mock-access-token",
                            refreshToken: "mock-refresh-token"
                        )
                    }
                }
                .disabled(!session.isDeveloperMode)
            } footer: {
                Text("This build expects your own backend tokens. Replace this screen with Sign in with Apple or another production auth flow once your backend contract is finalized.")
            }
        }
    }
}
