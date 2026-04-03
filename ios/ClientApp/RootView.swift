import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            if session.isBootstrapping {
                bootView
            } else if !session.isAuthenticated {
                AuthGatewayView()
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(.dark)
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

    private var bootView: some View {
        ZStack {
            StudioBackgroundView()

            VStack(spacing: 24) {
                Spacer()

                StudioMarkView(size: 96)

                VStack(spacing: 10) {
                    Text("Photo G")
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text("Opening your creative studio")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                StudioSurface {
                    HStack(alignment: .center, spacing: 14) {
                        ProgressView()
                            .tint(Color("AccentColor"))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Loading Photo G")
                                .font(.headline)
                            Text("Getting your workspace, tools, and placeholders ready.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: 360)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }
}
