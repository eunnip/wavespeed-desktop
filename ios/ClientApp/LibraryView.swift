import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var session: AppSession
    @State private var selectedFilter: LibraryFilter = .all

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var filteredAssets: [LocalAsset] {
        session.localAssets.filter { selectedFilter.matches($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StudioBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        heroCard
                        filterRow
                        libraryGrid
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await session.loadLocalAssets()
            }
        }
    }

    private var heroCard: some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 18) {
                StudioSectionHeader(
                    eyebrow: "Library",
                    title: "Your saved generations live here",
                    detail: "Everything you save from PhotoG is stored locally on device so it is ready to share, revisit, and reuse."
                )

                HStack(spacing: 12) {
                    StudioSummaryCard(value: "\(session.localAssets.count)", label: "saved items")
                    StudioSummaryCard(value: "\(session.localAssets.filter { $0.isImage }.count)", label: "images")
                    StudioSummaryCard(value: LocalAssetStore.directoryURL.lastPathComponent, label: "folder")
                }
            }
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LibraryFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        StudioChoiceChip(title: filter.title, isSelected: selectedFilter == filter)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var libraryGrid: some View {
        if filteredAssets.isEmpty {
            StudioEmptyStateCard(
                title: "Nothing saved yet",
                detail: "Save an output from a completed run and it will appear here as part of your personal library.",
                systemImage: "photo.on.rectangle.angled"
            )
        } else {
            VStack(alignment: .leading, spacing: 14) {
                StudioSectionHeader(
                    eyebrow: "Gallery",
                    title: selectedFilter == .all ? "All saved outputs" : selectedFilter.title
                )

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filteredAssets) { asset in
                        LibraryAssetCard(asset: asset)
                    }
                }
            }
        }
    }
}

private enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case images
    case video
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .images:
            return "Images"
        case .video:
            return "Video"
        case .other:
            return "Other"
        }
    }

    func matches(_ asset: LocalAsset) -> Bool {
        switch self {
        case .all:
            return true
        case .images:
            return asset.isImage
        case .video:
            return asset.isVideo
        case .other:
            return !asset.isImage && !asset.isVideo
        }
    }
}

private struct LibraryAssetCard: View {
    let asset: LocalAsset

    var body: some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 14) {
                preview

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(asset.filename)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 8)

                        ShareLink(item: asset.fileURL) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color("AccentColor"))
                                .padding(10)
                                .background(Color.studioPanelStrong, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        Text(asset.kindLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(asset.kindTint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(asset.kindTint.opacity(0.12), in: Capsule())

                        Text(asset.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if asset.isImage, let image = UIImage(contentsOfFile: asset.fileURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: asset.previewGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 170)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: asset.symbolName)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(asset.kindTint)
                        Text(asset.kindLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
        }
    }
}

private extension LocalAsset {
    var isImage: Bool {
        mimeType?.hasPrefix("image/") ?? true
    }

    var isVideo: Bool {
        mimeType?.hasPrefix("video/") ?? false
    }

    var kindLabel: String {
        if isImage {
            return "Image"
        }
        if isVideo {
            return "Video"
        }
        return "File"
    }

    var kindTint: Color {
        if isImage {
            return Color(red: 0.18, green: 0.44, blue: 0.86)
        }
        if isVideo {
            return Color(red: 0.52, green: 0.33, blue: 0.82)
        }
        return Color(red: 0.49, green: 0.49, blue: 0.56)
    }

    var symbolName: String {
        if isImage {
            return "photo.fill"
        }
        if isVideo {
            return "video.fill"
        }
        return "doc.fill"
    }

    var previewGradient: [Color] {
        if isImage {
            return [Color(red: 0.07, green: 0.18, blue: 0.18), Color(red: 0.13, green: 0.23, blue: 0.22)]
        }
        if isVideo {
            return [Color(red: 0.11, green: 0.14, blue: 0.25), Color(red: 0.18, green: 0.15, blue: 0.28)]
        }
        return [Color(red: 0.10, green: 0.12, blue: 0.14), Color(red: 0.14, green: 0.15, blue: 0.18)]
    }
}
