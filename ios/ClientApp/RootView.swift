import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            if session.isBootstrapping {
                ProgressView("Loading")
            } else if !session.isAuthenticated {
                AuthGatewayView()
            } else {
                MainTabView()
            }
        }
        .sheet(isPresented: $session.presentPaywall) {
            PaywallView()
                .environmentObject(session)
        }
        .alert("Error", isPresented: Binding(
            get: { session.errorText != nil },
            set: { newValue in
                if !newValue {
                    session.errorText = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                session.errorText = nil
            }
        } message: {
            Text(session.errorText ?? "")
        }
    }
}
