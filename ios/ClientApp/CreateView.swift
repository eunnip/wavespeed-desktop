import SwiftUI

struct CreateView: View {
    @EnvironmentObject private var session: AppSession

    @Binding private var selectedTab: MainTab
    @Binding private var exploreKind: ExploreKind

    private let recentColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    init(selectedTab: Binding<MainTab>, exploreKind: Binding<ExploreKind>) {
        _selectedTab = selectedTab
        _exploreKind = exploreKind
    }

    private var featuredModels: [CatalogModel] {
        let featured = session.appConfig.featuredModelIds.compactMap { featuredID in
            session.catalog.first(where: { $0.id == featuredID })
        }
        return featured.isEmpty ? Array(session.catalog.prefix(6)) : featured
    }

    private var heroModel: CatalogModel? {
        featuredModels.first ?? session.catalog.first
    }

    private var trendModels: [CatalogModel] {
        Array(featuredModels.prefix(6))
    }

    private var recentJobs: [Job] {
        Array(session.jobs.prefix(4))
    }

    private var recommendedModels: [CatalogModel] {
        let featuredIDs = Set(featuredModels.map(\.id))
        let remaining = session.catalog.filter { !featuredIDs.contains($0.id) }
        return Array((remaining.isEmpty ? session.catalog : remaining).prefix(4))
    }

    private var imageModelCount: Int {
        session.catalog.filter { ExploreKind.image.matches($0) }.count
    }

    private var videoModelCount: Int {
        session.catalog.filter { ExploreKind.video.matches($0) }.count
    }

    private var currentPlanTitle: String {
        session.entitlement?.tierName ?? "Standard Plan"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StudioBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        topBar

                        if let heroModel {
                            heroSection(model: heroModel)
                        }

                        shortcutsSection
                        trendsSection
                        forYouSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationDestination(for: ComposerDestination.self) { destination in
                ComposerView(destination: destination)
            }
            .refreshable {
                await session.refreshSessionData()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.studioPanelStrong)
                        .frame(width: 48, height: 48)

                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color("AccentColor"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("PhotoG")
                        .font(.headline.weight(.semibold))
                    Text("Creative home")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: showExploreAll) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Color.studioPanel, in: Circle())
            }
            .buttonStyle(.plain)

            Button(action: showProfile) {
                Text(currentPlanTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.studioPanel, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func heroSection(model: CatalogModel) -> some View {
        ZStack(alignment: .bottomLeading) {
            heroArtwork(model: model)

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.18), Color.black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 14) {
                StudioStatusBadge(
                    icon: "bolt.fill",
                    title: "WaveSpeed spotlight",
                    tint: .white
                )

                Text(model.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(model.summary ?? "Move from an idea to a polished visual with PhotoG’s latest image and video models.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(3)

                HStack(spacing: 10) {
                    HomeHeroPill(title: model.displayKind)
                    HomeHeroPill(title: model.inputLabel)
                }

                HStack(spacing: 6) {
                    ForEach(Array(trendModels.prefix(5).indices), id: \.self) { index in
                        Capsule()
                            .fill(index == 0 ? Color.white : Color.white.opacity(0.28))
                            .frame(width: index == 0 ? 22 : 6, height: 6)
                    }
                }
            }
            .padding(24)
        }
        .frame(height: 258)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .shadow(color: Color.black.opacity(0.32), radius: 24, x: 0, y: 18)
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            StudioSectionHeader(
                eyebrow: "Launch",
                title: "Choose your creative mode",
                detail: "Jump straight into AI image or AI video, or browse the full model catalog."
            )

            HStack(spacing: 12) {
                HomeShortcutCard(
                    title: "AI Image",
                    subtitle: "\(imageModelCount) models",
                    systemImage: "photo.fill",
                    gradient: [
                        Color(red: 0.15, green: 0.33, blue: 0.25),
                        Color(red: 0.20, green: 0.53, blue: 0.37)
                    ],
                    action: showImageModels
                )

                HomeShortcutCard(
                    title: "AI Video",
                    subtitle: "\(videoModelCount) models",
                    systemImage: "video.fill",
                    gradient: [
                        Color(red: 0.17, green: 0.22, blue: 0.44),
                        Color(red: 0.30, green: 0.36, blue: 0.74)
                    ],
                    action: showVideoModels
                )

                HomeShortcutCard(
                    title: "Explore",
                    subtitle: "\(session.catalog.count) total",
                    systemImage: "square.grid.2x2.fill",
                    gradient: [
                        Color(red: 0.31, green: 0.25, blue: 0.10),
                        Color(red: 0.55, green: 0.39, blue: 0.13)
                    ],
                    action: showExploreAll
                )
            }
        }
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                StudioSectionHeader(
                    eyebrow: "Trends",
                    title: "What’s hot right now"
                )

                Spacer()

                Button("More", action: showExploreAll)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if trendModels.isEmpty {
                StudioEmptyStateCard(
                    title: "No models yet",
                    detail: "Once your backend catalog is available, featured models will appear here.",
                    systemImage: "sparkles"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(trendModels) { model in
                            NavigationLink(value: ComposerDestination(model: model)) {
                                HomeTrendCard(model: model)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var forYouSection: some View {
        if recentJobs.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                StudioSectionHeader(
                    eyebrow: "For you",
                    title: "Start with these models",
                    detail: "PhotoG will personalize this area with your recent generations after your first runs."
                )

                ForEach(recommendedModels) { model in
                    NavigationLink(value: ComposerDestination(model: model)) {
                        HomeRecommendationRow(model: model)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                StudioSectionHeader(
                    eyebrow: "For you",
                    title: "Recent generations",
                    detail: "Re-open your latest results or jump back into a model you were using."
                )

                LazyVGrid(columns: recentColumns, spacing: 14) {
                    ForEach(recentJobs) { job in
                        NavigationLink {
                            JobDetailView(jobID: job.id)
                        } label: {
                            HomeRecentJobCard(job: job)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func showExploreAll() {
        exploreKind = .all
        selectedTab = .explore
    }

    private func showImageModels() {
        exploreKind = .image
        selectedTab = .explore
    }

    private func showVideoModels() {
        exploreKind = .video
        selectedTab = .explore
    }

    private func showProfile() {
        selectedTab = .profile
    }

    @ViewBuilder
    private func heroArtwork(model: CatalogModel) -> some View {
        Group {
            if let thumbnailURL = model.thumbnailURL {
                AsyncImage(url: thumbnailURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    HomeHeroPlaceholder(model: model)
                }
            } else {
                HomeHeroPlaceholder(model: model)
            }
        }
    }
}

private struct HomeHeroPlaceholder: View {
    let model: CatalogModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: model.featuredGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 150, height: 150)
                .blur(radius: 8)
                .offset(x: 95, y: -50)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.14))
                .frame(width: 150, height: 90)
                .rotationEffect(.degrees(-12))
                .offset(x: 70, y: 20)

            Image(systemName: model.symbolName)
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .offset(x: 92, y: -16)
        }
    }
}

private struct HomeHeroPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12), in: Capsule())
    }
}

private struct HomeShortcutCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Color.white.opacity(0.14), in: Circle())

                Spacer(minLength: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.76))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .padding(16)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HomeTrendCard: View {
    let model: CatalogModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let thumbnailURL = model.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        trendPlaceholder
                    }
                } else {
                    trendPlaceholder
                }
            }

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.76)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(model.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(model.displayKind)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
            }
            .padding(16)
        }
        .frame(width: 168, height: 214)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
    }

    private var trendPlaceholder: some View {
        LinearGradient(
            colors: model.featuredGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct HomeRecentJobCard: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            preview

            VStack(alignment: .leading, spacing: 6) {
                Text(job.modelName ?? job.modelId)
                    .font(.headline)
                    .lineLimit(1)

                Text(job.prompt ?? "Open this run to view the generated result.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(job.status.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(job.status.tintColor)
                    Text(job.formattedTimestamp)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06))
        )
    }

    @ViewBuilder
    private var preview: some View {
        if let output = job.outputs.first, output.isImageOutput {
            AsyncImage(url: output.url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholder
            }
            .frame(height: 156)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            placeholder
                .frame(height: 156)
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        job.status.tintColor.opacity(0.30),
                        Color.studioPanelStrong
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: job.status.symbolName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(job.status.tintColor)
            }
    }
}

private struct HomeRecommendationRow: View {
    let model: CatalogModel

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: model.softGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: model.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(model.symbolTint)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(model.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(model.displayKind)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("AccentColor"))
                }

                Text(model.summary ?? "Open this model to start a fresh creation.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06))
        )
    }
}

extension CatalogModel {
    var displayKind: String {
        guard let kind, !kind.isEmpty else {
            return "Image"
        }
        return kind
            .split(separator: "-", omittingEmptySubsequences: true)
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    var inputLabel: String {
        requiresImageInput ? "Reference photo" : "Prompt first"
    }

    var symbolName: String {
        switch (kind ?? "").lowercased() {
        case "video":
            return "video.fill"
        case "edit":
            return "slider.horizontal.3"
        default:
            return requiresImageInput ? "photo.on.rectangle.angled" : "sparkles"
        }
    }

    var symbolTint: Color {
        switch (kind ?? "").lowercased() {
        case "video":
            return Color(red: 0.21, green: 0.38, blue: 0.79)
        case "edit":
            return Color(red: 0.53, green: 0.31, blue: 0.74)
        default:
            return Color(red: 0.18, green: 0.44, blue: 0.86)
        }
    }

    var featuredGradient: [Color] {
        switch (kind ?? "").lowercased() {
        case "video":
            return [
                Color(red: 0.15, green: 0.22, blue: 0.46),
                Color(red: 0.29, green: 0.36, blue: 0.74),
                Color(red: 0.80, green: 0.61, blue: 0.32)
            ]
        case "edit":
            return [
                Color(red: 0.11, green: 0.28, blue: 0.34),
                Color(red: 0.24, green: 0.51, blue: 0.46),
                Color(red: 0.78, green: 0.54, blue: 0.31)
            ]
        default:
            return [
                Color(red: 0.07, green: 0.24, blue: 0.20),
                Color(red: 0.16, green: 0.44, blue: 0.34),
                Color(red: 0.79, green: 0.62, blue: 0.34)
            ]
        }
    }

    var softGradient: [Color] {
        switch (kind ?? "").lowercased() {
        case "video":
            return [
                Color(red: 0.15, green: 0.20, blue: 0.33),
                Color(red: 0.21, green: 0.27, blue: 0.42)
            ]
        case "edit":
            return [
                Color(red: 0.18, green: 0.17, blue: 0.30),
                Color(red: 0.23, green: 0.18, blue: 0.33)
            ]
        default:
            return [
                Color(red: 0.10, green: 0.18, blue: 0.19),
                Color(red: 0.15, green: 0.20, blue: 0.21)
            ]
        }
    }
}
