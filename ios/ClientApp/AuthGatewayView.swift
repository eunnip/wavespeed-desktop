import SwiftUI

struct AuthGatewayView: View {
    @EnvironmentObject private var session: AppSession
    @State private var showDeveloperOptions = false

    private let featureHighlights: [StudioFeature] = [
        StudioFeature(icon: "sparkles", title: "Styled looks"),
        StudioFeature(icon: "wand.and.stars", title: "Quick edits"),
        StudioFeature(icon: "photo.stack.fill", title: "Favorite shots")
    ]

    private var environmentMessage: String {
        if session.isMockEnvironment {
            return "Mock services are active. The app is using sample auth, models, entitlements, and jobs for local development."
        }
        if session.isDeveloperMode {
            return "Developer mode is enabled. Manual backend token sign-in is available while your production sign-in exchange is being finalized."
        }
        return "This build is connected and ready for sign-in."
    }

    private var showsInternalDiagnostics: Bool {
        session.isMockEnvironment || session.allowsDeveloperConnection
    }

    private var signInStatusMessage: String? {
        guard let failureReason = session.authFailureReason else {
            return nil
        }
        guard let errorText = session.errorText,
              !errorText.isEmpty,
              errorText != failureReason.guidance
        else {
            return failureReason.guidance
        }
        return "\(failureReason.guidance)\n\n\(errorText)"
    }

    var body: some View {
        ZStack {
            StudioBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    signInCard

                    if showsInternalDiagnostics {
                        environmentCard
                    } else {
                        productionReadyCard
                    }

                    if session.allowsDeveloperConnection {
                        developerCard
                    }

                    if let signInStatusMessage {
                        statusCard(
                            title: "Sign-in needs attention",
                            icon: "exclamationmark.triangle.fill",
                            tint: .red,
                            body: signInStatusMessage
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                StudioStatusBadge(
                    icon: "hand.wave.fill",
                    title: "Welcome",
                    tint: Color("AccentColor")
                )

                Text("Make photo ideas\nfeel effortless.")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Photo G is a friendly place to explore polished edits, fresh styles, and early creative concepts in just a few taps.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            StudioMarkView(size: 88)
                .padding(.top, 8)
        }
    }

    private var signInCard: some View {
        StudioSurface {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Start with Photo G")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Use Apple to get into the app quickly, keep your setup secure, and open your creative space.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                StudioOrbView()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(featureHighlights) { feature in
                    StudioFeaturePill(feature: feature)
                }
            }

            SignInWithAppleButtonView()

            if session.allowsSimulatorMockSignIn && !session.allowsDeveloperConnection {
                Button(action: continueInSimulator) {
                    HStack {
                        Spacer()
                        Label("Continue in simulator", systemImage: "sparkles.rectangle.stack.fill")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color("AccentColor"))
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    Color("AccentColor").opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

                Text("Simulator-only shortcut. It loads a local mock account so you can verify the rest of the app without waiting on Apple auth or backend exchange fixes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label("Secure Apple sign-in keeps your Photo G account simple and private.", systemImage: "lock.shield.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var environmentCard: some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Environment")
                        .font(.title3.weight(.semibold))

                    Spacer()

                    StudioStatusBadge(
                        icon: session.isMockEnvironment ? "hammer.fill" : "server.rack",
                        title: session.environmentName.capitalized,
                        tint: session.isMockEnvironment ? .purple : Color("AccentColor")
                    )
                }

                StudioMetricRow(
                    title: "Backend",
                    value: session.backendURLString,
                    monospaced: true
                )

                StudioMetricRow(
                    title: "Mode",
                    value: session.isMockEnvironment ? "Mock" : "Developer"
                )

                Text(environmentMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var productionReadyCard: some View {
        StudioSurface {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color("AccentColor"))
                    .frame(width: 40, height: 40)
                    .background(
                        Color("AccentColor").opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready when you are")
                        .font(.headline)
                    Text("Sign in to open Photo G and explore the first version of the experience. There is nothing else to configure on this screen in production.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var developerCard: some View {
        StudioSurface {
            DisclosureGroup(isExpanded: $showDeveloperOptions) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Use the developer connection only until your production auth endpoint and Sign in with Apple exchange flow are live.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    SignInView(showsNavigationChrome: false)
                }
                .padding(.top, 12)
            } label: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color("AccentColor"))
                        .frame(width: 44, height: 44)
                        .background(Color("AccentColor").opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Developer connection")
                            .font(.headline)
                        Text("Manual backend token sign-in for internal builds.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(Color("AccentColor"))
        }
    }

    private func statusCard(title: String, icon: String, tint: Color, body: String) -> some View {
        StudioSurface {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func continueInSimulator() {
        Task {
            await session.signInWithMockSession()
        }
    }
}

extension Color {
    static let studioCanvasTop = Color(red: 0.02, green: 0.08, blue: 0.06)
    static let studioCanvasMid = Color(red: 0.03, green: 0.13, blue: 0.10)
    static let studioCanvasBottom = Color(red: 0.01, green: 0.03, blue: 0.02)
    static let studioSurface = Color(red: 0.06, green: 0.11, blue: 0.09)
    static let studioPanel = Color.white.opacity(0.08)
    static let studioPanelStrong = Color.white.opacity(0.12)
}

struct StudioBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .studioCanvasTop,
                    .studioCanvasMid,
                    .studioCanvasBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color("AccentColor").opacity(0.24))
                .frame(width: 320, height: 320)
                .blur(radius: 26)
                .offset(x: 170, y: -240)

            Circle()
                .fill(Color(red: 0.06, green: 0.32, blue: 0.22).opacity(0.46))
                .frame(width: 260, height: 260)
                .blur(radius: 36)
                .offset(x: -150, y: 290)

            Circle()
                .fill(Color(red: 0.95, green: 0.70, blue: 0.42).opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 30)
                .offset(x: 130, y: 250)
        }
        .ignoresSafeArea()
    }
}

struct StudioSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [.studioSurface, Color(red: 0.04, green: 0.08, blue: 0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.34), radius: 28, x: 0, y: 18)
    }
}

struct StudioFeature: Identifiable {
    let icon: String
    let title: String

    var id: String { title }
}

struct StudioFeaturePill: View {
    let feature: StudioFeature

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: feature.icon)
                .foregroundStyle(Color("AccentColor"))
            Text(feature.title)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct StudioStatusBadge: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.18), in: Capsule())
    }
}

struct StudioMetricRow: View {
    let title: String
    let value: String
    var monospaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(monospaced ? .subheadline.monospaced() : .body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

struct StudioMarkView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: size, height: size)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color("AccentColor"), Color(red: 0.98, green: 0.71, blue: 0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.78, height: size * 0.78)

            Image(systemName: "sparkles")
                .font(.system(size: size * 0.28, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: Color("AccentColor").opacity(0.32), radius: 28, x: 0, y: 16)
    }
}

private struct StudioOrbView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color("AccentColor").opacity(0.96),
                            Color(red: 0.98, green: 0.71, blue: 0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)

            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                .frame(width: 72, height: 72)

            Image(systemName: "wand.and.stars")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
        }
        .shadow(color: Color("AccentColor").opacity(0.22), radius: 18, x: 0, y: 10)
    }
}

struct StudioSectionHeader: View {
    let eyebrow: String
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("AccentColor"))
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct StudioSummaryCard: View {
    let value: String
    let label: String
    var tint: Color = Color("AccentColor")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.studioPanel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.10))
        )
    }
}

struct StudioChoiceChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color("AccentColor") : Color.studioPanel,
                in: Capsule()
            )
    }
}

struct StudioEmptyStateCard: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        StudioSurface {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text(detail)
            )
        }
    }
}
