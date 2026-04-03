import SwiftUI

enum ExploreKind: String, CaseIterable, Identifiable {
    case all
    case image
    case video
    case edit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .image:
            return "AI Image"
        case .video:
            return "AI Video"
        case .edit:
            return "Edit"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "square.grid.2x2.fill"
        case .image:
            return "photo.fill"
        case .video:
            return "video.fill"
        case .edit:
            return "slider.horizontal.3"
        }
    }

    func matches(_ model: CatalogModel) -> Bool {
        let normalizedKind = (model.kind ?? "").lowercased()
        switch self {
        case .all:
            return true
        case .image:
            return normalizedKind.isEmpty || normalizedKind == "image"
        case .video:
            return normalizedKind == "video"
        case .edit:
            return normalizedKind == "edit" || model.requiresImageInput
        }
    }
}

struct ActivityView: View {
    @EnvironmentObject private var session: AppSession
    @Binding private var selectedKind: ExploreKind
    @State private var searchText = ""

    init(selectedKind: Binding<ExploreKind>) {
        _selectedKind = selectedKind
    }

    private var availableKinds: [ExploreKind] {
        ExploreKind.allCases.filter { kind in
            kind == .all || session.catalog.contains(where: { kind.matches($0) })
        }
    }

    private var spotlightModels: [CatalogModel] {
        let featured = session.appConfig.featuredModelIds.compactMap { featuredID in
            session.catalog.first(where: { $0.id == featuredID })
        }
        return featured.isEmpty ? Array(session.catalog.prefix(5)) : featured
    }

    private var filteredModels: [CatalogModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return session.catalog.filter { model in
            guard selectedKind.matches(model) else { return false }
            guard !query.isEmpty else { return true }
            return model.name.lowercased().contains(query)
                || (model.summary?.lowercased().contains(query) ?? false)
                || model.displayKind.lowercased().contains(query)
                || model.id.lowercased().contains(query)
        }
    }

    private var imageCount: Int {
        session.catalog.filter { ExploreKind.image.matches($0) }.count
    }

    private var videoCount: Int {
        session.catalog.filter { ExploreKind.video.matches($0) }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StudioBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        heroCard
                        filterRow

                        if selectedKind == .all, !spotlightModels.isEmpty {
                            spotlightSection
                        }

                        modelsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationDestination(for: CatalogModel.self) { model in
                ComposerView(model: model)
            }
            .refreshable {
                await session.refreshSessionData()
            }
            .searchable(text: $searchText, prompt: "Search WaveSpeed models")
            .onChange(of: availableKinds) { _, kinds in
                if !kinds.contains(selectedKind) {
                    selectedKind = .all
                }
            }
        }
    }

    private var heroCard: some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        StudioStatusBadge(
                            icon: "safari.fill",
                            title: "WaveSpeed catalog",
                            tint: Color("AccentColor")
                        )

                        Text("Explore every model PhotoG offers")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("This tab reflects the model catalog your backend exposes to the app. Open any model to create an image, a video, or a guided edit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.studioPanel)
                            .frame(width: 88, height: 88)

                        Image(systemName: "waveform.path.ecg.rectangle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color("AccentColor"))
                    }
                }

                HStack(spacing: 12) {
                    StudioSummaryCard(value: "\(session.catalog.count)", label: "models")
                    StudioSummaryCard(value: "\(imageCount)", label: "image")
                    StudioSummaryCard(value: "\(videoCount)", label: "video")
                }
            }
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(availableKinds) { kind in
                    Button {
                        selectedKind = kind
                    } label: {
                        ExploreFilterChip(kind: kind, isSelected: selectedKind == kind)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var spotlightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            StudioSectionHeader(
                eyebrow: "Spotlight",
                title: "Featured models"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(spotlightModels) { model in
                        NavigationLink(value: model) {
                            ExploreSpotlightCard(model: model)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var modelsSection: some View {
        if filteredModels.isEmpty {
            StudioEmptyStateCard(
                title: "No matching models",
                detail: "Try a broader search or switch to another creative mode.",
                systemImage: "magnifyingglass"
            )
        } else {
            VStack(alignment: .leading, spacing: 14) {
                StudioSectionHeader(
                    eyebrow: "Models",
                    title: searchText.isEmpty ? "Available now" : "Search results",
                    detail: "\(filteredModels.count) model\(filteredModels.count == 1 ? "" : "s")"
                )

                LazyVStack(spacing: 14) {
                    ForEach(filteredModels) { model in
                        NavigationLink(value: model) {
                            ExploreModelRow(model: model)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct ExploreSpotlightCard: View {
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
                        placeholder
                    }
                } else {
                    placeholder
                }
            }

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                StudioStatusBadge(icon: model.symbolName, title: model.displayKind, tint: .white)

                Text(model.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(model.summary ?? "Open this model in the composer.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(2)
            }
            .padding(18)
        }
        .frame(width: 288, height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
    }

    private var placeholder: some View {
        LinearGradient(
            colors: model.featuredGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ExploreFilterChip: View {
    let kind: ExploreKind
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: kind.systemImage)
                .font(.caption.weight(.semibold))
            Text(kind.title)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            isSelected ? Color("AccentColor") : Color.studioPanel,
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(isSelected ? 0 : 0.06))
        )
    }
}

private struct ExploreModelRow: View {
    let model: CatalogModel

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            preview

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(model.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(model.displayKind)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("AccentColor"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color("AccentColor").opacity(0.16), in: Capsule())
                }

                Text(model.summary ?? "Open this model to start creating in PhotoG.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    ExploreDetailPill(
                        title: model.requiresImageInput ? "Needs image" : "Prompt first",
                        systemImage: model.requiresImageInput ? "photo.badge.plus" : "text.bubble"
                    )
                    ExploreDetailPill(title: model.id, systemImage: "number")
                }
            }

            Spacer(minLength: 10)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
        .padding(16)
        .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06))
        )
    }

    @ViewBuilder
    private var preview: some View {
        if let thumbnailURL = model.thumbnailURL {
            AsyncImage(url: thumbnailURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholder
            }
            .frame(width: 90, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            placeholder
                .frame(width: 90, height: 112)
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: model.softGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: model.symbolName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(model.symbolTint)
            }
    }
}

private struct ExploreDetailPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.studioPanelStrong, in: Capsule())
    }
}

extension JobStatus {
    var label: String {
        switch self {
        case .queued:
            return "Queued"
        case .running:
            return "Running"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .canceled:
            return "Canceled"
        }
    }

    var symbolName: String {
        switch self {
        case .queued:
            return "clock.badge"
        case .running:
            return "sparkles"
        case .completed:
            return "checkmark.seal.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .canceled:
            return "slash.circle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .queued:
            return Color(red: 0.39, green: 0.54, blue: 0.88)
        case .running:
            return Color(red: 0.22, green: 0.57, blue: 0.89)
        case .completed:
            return Color(red: 0.16, green: 0.58, blue: 0.42)
        case .failed:
            return Color(red: 0.83, green: 0.36, blue: 0.29)
        case .canceled:
            return Color(red: 0.56, green: 0.56, blue: 0.60)
        }
    }
}

extension Job {
    var formattedTimestamp: String {
        if let createdAt, let date = Self.iso8601Formatter.date(from: createdAt) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        if let updatedAt, let date = Self.iso8601Formatter.date(from: updatedAt) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return "Just now"
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension JobOutput {
    var isImageOutput: Bool {
        mimeType?.hasPrefix("image/") ?? true
    }
}
