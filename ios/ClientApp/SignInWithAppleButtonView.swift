import AuthenticationServices
import CryptoKit
import SwiftUI

struct SignInWithAppleButtonView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
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
                session.errorText = error.localizedDescription
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
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
}
