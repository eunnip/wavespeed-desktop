import AuthenticationServices
import SwiftUI

struct SignInWithAppleButtonView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
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
                        authorizationCode: authorizationCode
                    )
                }
            case .failure(let error):
                session.errorText = error.localizedDescription
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
    }
}
