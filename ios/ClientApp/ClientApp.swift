import SwiftUI

@main
struct ClientApp: App {
    @StateObject private var session = AppSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .task {
                    await session.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active, session.isAuthenticated else { return }
                    Task {
                        await session.refreshAccessTokenIfNeeded()
                        await session.refreshEntitlement()
                    }
                }
        }
    }
}
