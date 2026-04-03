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
                    ZStack {
                        StudioBackgroundView()

                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                header

                                StudioSurface {
                                    developerConnectionContent
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 28)
                            .padding(.bottom, 40)
                        }
                        .scrollIndicators(.hidden)
                    }
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Developer Connection")
                                .font(.headline.weight(.semibold))
                        }
                    }
                }
            } else {
                developerConnectionContent
            }
        }
        .onAppear {
            backendURL = session.backendURLString
            accessToken = session.accessToken
            refreshToken = session.refreshToken
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            StudioStatusBadge(
                icon: "wrench.and.screwdriver.fill",
                title: "Internal testing",
                tint: Color("AccentColor")
            )

            Text("Manual backend connection")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("Use direct backend tokens for development builds only. Once your production auth flow is live, this should stay tucked behind internal tooling.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var developerConnectionContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            StudioInputField(
                title: "Backend URL",
                prompt: "https://api.yourproduct.com",
                text: $backendURL,
                textContentType: nil,
                keyboardType: .URL
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            StudioSecureInputField(
                title: "Access token",
                prompt: "Enter access token",
                text: $accessToken
            )

            StudioSecureInputField(
                title: "Refresh token",
                prompt: "Optional refresh token",
                text: $refreshToken
            )

            Button(action: connect) {
                HStack {
                    Spacer()
                    if session.isBusy {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Connect", systemImage: "arrow.right.circle.fill")
                            .font(.headline.weight(.semibold))
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color("AccentColor"), Color(red: 0.98, green: 0.71, blue: 0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .disabled(isConnectDisabled || session.isBusy)
            .opacity(isConnectDisabled || session.isBusy ? 0.7 : 1)

            if session.allowsDeveloperConnection || session.allowsSimulatorMockSignIn {
                Button(action: useMockBackend) {
                    HStack {
                        Spacer()
                        Label(session.allowsDeveloperConnection ? "Use mock backend" : "Continue in simulator", systemImage: "hammer.fill")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Text("This build expects your own backend tokens. Replace this path with Sign in with Apple or another production auth flow once your backend contract is finalized.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var isConnectDisabled: Bool {
        backendURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || accessToken.isEmpty
    }

    private func connect() {
        Task {
            await session.signIn(
                backendURLString: backendURL,
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        }
    }

    private func useMockBackend() {
        Task {
            await session.signInWithMockSession()
        }
    }
}

private struct StudioInputField: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let textContentType: UITextContentType?
    let keyboardType: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textContentType(textContentType)
                .keyboardType(keyboardType)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct StudioSecureInputField: View {
    let title: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            SecureField(prompt, text: $text)
                .textContentType(.password)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
