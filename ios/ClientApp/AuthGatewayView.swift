import AVFoundation
import SwiftUI

struct AuthGatewayView: View {
    @EnvironmentObject private var session: AppSession
    @State private var showDeveloperOptions = false

    private let featureHighlights: [StudioFeature] = [
        StudioFeature(icon: "photo.artframe", title: "AI Image"),
        StudioFeature(icon: "video.fill", title: "AI Video"),
        StudioFeature(icon: "square.stack.fill", title: "Library")
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
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            StudioHeroMediaView()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top, spacing: 14) {
                    HStack(spacing: 12) {
                        StudioMarkView(size: 54)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("PhotoG")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("AI Studio")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                    }

                    Spacer()

                    Text("Experience Now")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.28))
                        )
                }

                Spacer(minLength: 120)

                VStack(alignment: .leading, spacing: 14) {
                    StudioStatusBadge(
                        icon: "sparkles",
                        title: "Welcome",
                        tint: .white
                    )

                    Text("Welcome to PhotoG")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .italic()
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("your all in one AI Studio")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Sign in once and move between AI image, AI video, edits, and your saved work from one premium creative home.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SignInWithAppleButtonView(
                        label: .signIn,
                        style: .white,
                        height: 58
                    )

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            SignInWithAppleButtonView(
                                label: .signUp,
                                style: .whiteOutline,
                                height: 50
                            )

                            SignInWithAppleButtonView(
                                label: .continue,
                                style: .whiteOutline,
                                height: 50
                            )
                        }

                        VStack(spacing: 12) {
                            SignInWithAppleButtonView(
                                label: .signUp,
                                style: .whiteOutline,
                                height: 50
                            )

                            SignInWithAppleButtonView(
                                label: .continue,
                                style: .whiteOutline,
                                height: 50
                            )
                        }
                    }

                    Text("Create an account or get started instantly with Apple.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.80))
                }
            }
            .padding(24)
        }
        .frame(minHeight: 620)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14))
        )
        .shadow(color: Color.black.opacity(0.36), radius: 30, y: 22)
    }

    private var signInCard: some View {
        StudioSurface {
            StudioSectionHeader(
                eyebrow: "Launch",
                title: "Everything you need is behind one sign-in",
                detail: "PhotoG keeps the entry simple, then hands off to curated models, creation modes, and your saved outputs."
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(featureHighlights) { feature in
                    StudioFeaturePill(feature: feature)
                }
            }

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

private struct StudioHeroMediaView: View {
    private let videoName = "photog-auth-hero"
    private let videoExtension = "mp4"

    var body: some View {
        ZStack {
            if let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) {
                StudioLoopingVideoView(url: url)
                    .allowsHitTesting(false)
            } else {
                fallbackArtwork
            }
        }
    }

    private var fallbackArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.17, green: 0.41, blue: 0.46),
                    Color(red: 0.25, green: 0.54, blue: 0.61),
                    Color(red: 0.08, green: 0.15, blue: 0.21)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Ellipse()
                .fill(Color.white.opacity(0.18))
                .frame(width: 560, height: 220)
                .blur(radius: 50)
                .offset(x: 0, y: -220)

            RoundedRectangle(cornerRadius: 52, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .frame(width: 250, height: 180)
                .overlay(
                    RoundedRectangle(cornerRadius: 52, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                )
                .offset(x: 0, y: 170)

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 12, height: 12)
                .offset(x: 0, y: 228)
        }
    }
}

private struct StudioLoopingVideoView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIView(context: Context) -> StudioPlayerContainerView {
        let view = StudioPlayerContainerView()
        view.playerLayer.player = context.coordinator.player
        context.coordinator.player.play()
        return view
    }

    func updateUIView(_ uiView: StudioPlayerContainerView, context: Context) {
        if uiView.playerLayer.player !== context.coordinator.player {
            uiView.playerLayer.player = context.coordinator.player
        }
        if context.coordinator.player.timeControlStatus != .playing {
            context.coordinator.player.play()
        }
    }

    static func dismantleUIView(_ uiView: StudioPlayerContainerView, coordinator: Coordinator) {
        coordinator.player.pause()
        uiView.playerLayer.player = nil
    }

    final class Coordinator {
        let player: AVQueuePlayer
        let looper: AVPlayerLooper

        init(url: URL) {
            let item = AVPlayerItem(url: url)
            let player = AVQueuePlayer()
            player.isMuted = true
            player.actionAtItemEnd = .none
            player.preventsDisplaySleepDuringVideoPlayback = false
            self.player = player
            self.looper = AVPlayerLooper(player: player, templateItem: item)
        }
    }
}

private final class StudioPlayerContainerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
