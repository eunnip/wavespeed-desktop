import AuthenticationServices
import CryptoKit
import SwiftUI

struct SignInWithAppleButtonView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        ZStack {
            SignInWithAppleButton(.signIn) { request in
                let rawNonce = randomNonce()
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256(rawNonce)
                session.pendingAppleNonce = rawNonce
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                        session.errorText = "Apple sign-in completed without an Apple ID credential."
                        return
                    }
                    let identityToken = credential.identityToken.flatMap {
                        String(data: $0, encoding: .utf8)
                    }
                    let authorizationCode = credential.authorizationCode.flatMap {
                        String(data: $0, encoding: .utf8)
                    }
                    Task {
                        await session.signInWithApplePlaceholder(
                            identityToken: identityToken,
                            authorizationCode: authorizationCode,
                            nonce: session.pendingAppleNonce
                        )
                    }
                case .failure(let error):
                    session.errorText = message(for: error)
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .disabled(session.isBusy)
            .opacity(session.isBusy ? 0.88 : 1)

            if session.isBusy {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("Connecting...")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.72), in: Capsule())
                .allowsHitTesting(false)
            }
        }
    }

    private func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).compactMap { _ in
            charset.randomElement()
        })
    }

    private func message(for error: Error) -> String {
        if let error = error as? ASAuthorizationError {
            switch error.code {
            case .canceled:
                return "Sign in with Apple was canceled."
            case .failed, .invalidResponse, .notHandled, .unknown:
                return "Sign in with Apple could not start. Verify the app uses the correct bundle identifier, that the Sign in with Apple capability is enabled for this target, and that the device or simulator is signed into an Apple ID."
            case .notInteractive:
                return "Sign in with Apple is not available in the current app state. Bring the app to the foreground and try again."
            case .matchedExcludedCredential:
                return "The selected Apple account cannot be used with this app."
            case .preferSignInWithApple:
                return "This account should use the standard Sign in with Apple flow. Try again with the Apple sign-in button."
            case .deviceNotConfiguredForPasskeyCreation:
                return "This device is not configured for passkeys. Sign in with Apple requires an Apple ID session and device security settings such as a passcode or biometrics."
            case .credentialImport:
                return "Imported credentials could not be used for this sign-in."
            case .credentialExport:
                return "Apple credentials could not be exported for this sign-in."
            default:
                return "Sign in with Apple failed. Verify the target capability, bundle identifier, and device Apple ID setup."
            }
        }

        let nsError = error as NSError
        if nsError.domain == "AKAuthenticationError" {
            return "AuthenticationServices rejected the request. Confirm the bundle identifier matches the signed app ID, Sign in with Apple is enabled in Signing & Capabilities, and the current device or simulator has an Apple ID session."
        }

        return error.localizedDescription
    }
}
