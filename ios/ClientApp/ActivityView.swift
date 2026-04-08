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
            return normalizedKind == "edit" || normalizedKind == "image" || normalizedKind == "video" || model.kind == nil
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

    private var familyGroups: [ExploreFamilyGroup] {
        ExploreFamilyGroup.build(
            from: session.catalog.filter { selectedKind.matches($0) }
        )
    }

    private var providerSections: [ExploreProviderSection] {
        let filtered = filteredFamilies
        let grouped = Dictionary(grouping: filtered, by: \.provider.name)

        return grouped.values.compactMap { families in
            guard let leadFamily = families.max(by: { $0.providerLeadScore < $1.providerLeadScore }) else {
                return nil
            }

            let additional = families
                .filter { $0.id != leadFamily.id }
                .sorted(by: ExploreFamilyGroup.sortDescending)

            return ExploreProviderSection(
                provider: leadFamily.provider,
                leadFamily: leadFamily,
                additionalFamilies: additional
            )
        }
        .sorted { lhs, rhs in
            if lhs.provider.order != rhs.provider.order {
                return lhs.provider.order < rhs.provider.order
            }
            return lhs.provider.name < rhs.provider.name
        }
    }

    private var filteredFamilies: [ExploreFamilyGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return familyGroups.sorted(by: ExploreFamilyGroup.sortDescending)
        }

        return familyGroups
            .filter { family in
                family.searchTerms.contains { $0.contains(query) }
            }
            .sorted(by: ExploreFamilyGroup.sortDescending)
    }

    private var availableKinds: [ExploreKind] {
        ExploreKind.allCases.filter { kind in
            kind == .all || session.catalog.contains(where: { kind.matches($0) })
        }
    }

    private var imageCount: Int {
        session.catalog.filter { ExploreKind.image.matches($0) }.count
    }

    private var videoCount: Int {
        session.catalog.filter { ExploreKind.video.matches($0) }.count
    }

    private var providerCount: Int {
        Set(familyGroups.map(\.provider.name)).count
    }

    private var showingSearchResults: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StudioBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        heroCard
                        filterRow

                        if showingSearchResults {
                            searchResultsSection
                        } else {
                            providerSectionsView
                        }
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
            .searchable(text: $searchText, prompt: "Search providers, families, or versions")
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
                            title: "Curated model browser",
                            tint: Color("AccentColor")
                        )

                        Text("Browse leading models by company, not endless variants")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Each provider now leads with one recommended family. Use the version and mode dropdowns inside each card to switch between variants like normal, edit, or sequential.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.studioPanel)
                            .frame(width: 88, height: 88)

                        Image(systemName: "building.2.crop.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color("AccentColor"))
                    }
                }

                HStack(spacing: 12) {
                    StudioSummaryCard(value: "\(providerCount)", label: "providers")
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

    @ViewBuilder
    private var providerSectionsView: some View {
        if providerSections.isEmpty {
            StudioEmptyStateCard(
                title: "No provider groups yet",
                detail: "Once the backend catalog is available, PhotoG will group families here by company and model line.",
                systemImage: "sparkles"
            )
        } else {
            VStack(alignment: .leading, spacing: 18) {
                StudioSectionHeader(
                    eyebrow: "Providers",
                    title: "Leading families by company",
                    detail: "Curated picks stay visible first. Older or secondary families are tucked under each provider."
                )

                ForEach(providerSections) { section in
                    ExploreProviderSectionCard(
                        section: section,
                        preferredMode: selectedKind == .edit ? .edit : nil
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if filteredFamilies.isEmpty {
            StudioEmptyStateCard(
                title: "No matching model families",
                detail: "Try a broader search by provider, family name, or version.",
                systemImage: "magnifyingglass"
            )
        } else {
            VStack(alignment: .leading, spacing: 14) {
                StudioSectionHeader(
                    eyebrow: "Results",
                    title: "Matching model families",
                    detail: "\(filteredFamilies.count) family\(filteredFamilies.count == 1 ? "" : "ies")"
                )

                ForEach(filteredFamilies) { family in
                    ExploreFamilyResultCard(
                        family: family,
                        preferredMode: selectedKind == .edit ? .edit : nil
                    )
                }
            }
        }
    }
}

private struct ExploreProviderSectionCard: View {
    let section: ExploreProviderSection
    let preferredMode: ExploreVariantMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.provider.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(section.providerTagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(section.provider.leadingLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("AccentColor"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color("AccentColor").opacity(0.16), in: Capsule())
            }

            ExploreLeadFamilyCard(family: section.leadFamily, preferredMode: preferredMode)

            if !section.additionalFamilies.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("More from \(section.provider.name)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(section.additionalFamilies) { family in
                                NavigationLink(
                                    value: ComposerDestination(
                                        model: family.preferredVariant.model,
                                        intent: preferredMode?.composerIntent
                                    )
                                ) {
                                    ExploreFamilyChip(family: family)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}

private struct ExploreLeadFamilyCard: View {
    let family: ExploreFamilyGroup
    let preferredMode: ExploreVariantMode?

    @State private var selectedVersion: String
    @State private var selectedMode: ExploreVariantMode

    init(family: ExploreFamilyGroup, preferredMode: ExploreVariantMode? = nil) {
        self.family = family
        self.preferredMode = preferredMode
        _selectedVersion = State(initialValue: family.preferredVariant.versionLabel)
        _selectedMode = State(initialValue: preferredMode ?? family.preferredVariant.mode)
    }

    private var selectedVariant: ExploreModelVariant {
        family.variant(version: selectedVersion, mode: selectedMode) ?? family.preferredVariant
    }

    private var composerDestination: ComposerDestination {
        ComposerDestination(model: selectedVariant.model, intent: selectedMode.composerIntent)
    }

    private var availableModes: [ExploreVariantMode] {
        family.availableModes(for: selectedVersion)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            preview

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.16), Color.black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        StudioStatusBadge(
                            icon: selectedVariant.model.symbolName,
                            title: family.provider.name,
                            tint: .white
                        )

                        Text(family.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text(selectedVariant.model.summary ?? family.summary)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(3)
                    }

                    Spacer(minLength: 10)
                }

                HStack(spacing: 10) {
                    ExploreSelectionMenu(
                        title: "Version",
                        selectionLabel: selectedVersion,
                        options: family.availableVersions
                    ) { option in
                        selectedVersion = option
                    }

                    ExploreSelectionMenu(
                        title: "Mode",
                        selectionLabel: selectedMode.label,
                        options: availableModes.map(\.label)
                    ) { option in
                        if let mode = ExploreVariantMode(label: option) {
                            selectedMode = mode
                        }
                    }
                }

                HStack(spacing: 10) {
                    ExploreMetaPill(title: selectedVariant.model.displayKind, systemImage: selectedVariant.model.symbolName)
                    ExploreMetaPill(title: selectedVariant.mode.label, systemImage: selectedVariant.mode.systemImage)
                    ExploreMetaPill(title: selectedVariant.variantLabel, systemImage: "number")
                }

                NavigationLink(value: composerDestination) {
                    HStack {
                        Text("Open \(family.name)")
                            .font(.headline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(22)
        }
        .frame(height: 284)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .onChange(of: selectedVersion) { _, newVersion in
            let modes = family.availableModes(for: newVersion)
            if !modes.contains(selectedMode), let firstMode = modes.first {
                selectedMode = firstMode
            }
        }
        .onChange(of: family.id) { _, _ in
            selectedVersion = family.preferredVariant.versionLabel
            selectedMode = preferredMode ?? family.preferredVariant.mode
        }
        .onChange(of: preferredMode) { _, newMode in
            selectedMode = newMode ?? family.preferredVariant.mode
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let thumbnailURL = selectedVariant.model.thumbnailURL {
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

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: selectedVariant.model.featuredGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 180, height: 180)
                .offset(x: 120, y: -40)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .frame(width: 170, height: 100)
                .rotationEffect(.degrees(-12))
                .offset(x: 108, y: 22)

            Image(systemName: selectedVariant.model.symbolName)
                .font(.system(size: 62, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .offset(x: 120, y: -8)
        }
    }
}

private struct ExploreFamilyResultCard: View {
    let family: ExploreFamilyGroup
    let preferredMode: ExploreVariantMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(family.provider.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("AccentColor"))
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(family.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            ExploreLeadFamilyCard(family: family, preferredMode: preferredMode)
        }
    }
}

private struct ExploreFamilyChip: View {
    let family: ExploreFamilyGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(family.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("\(family.variants.count) variant\(family.variants.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06))
        )
    }
}

private struct ExploreSelectionMenu: View {
    let title: String
    let selectionLabel: String
    let options: [String]
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    onSelect(option)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))

                HStack(spacing: 8) {
                    Text(selectionLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct ExploreMetaPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.12), in: Capsule())
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

private struct ExploreProviderSection: Identifiable {
    let provider: ExploreProvider
    let leadFamily: ExploreFamilyGroup
    let additionalFamilies: [ExploreFamilyGroup]

    var id: String { provider.name }

    var providerTagline: String {
        switch provider.name {
        case "ByteDance":
            return "Seedream should lead here instead of exposing every variant first."
        case "Google":
            return "Nano Banana variants stay front and center."
        case "OpenAI":
            return "GPT Image leads while deprecated families stay secondary."
        default:
            return "Recommended family first, with secondary options tucked underneath."
        }
    }
}

private struct ExploreProvider: Hashable {
    let name: String
    let order: Int
    let leadingLabel: String
}

private struct ExploreFamilyGroup: Identifiable {
    let provider: ExploreProvider
    let key: String
    let name: String
    let summary: String
    let variants: [ExploreModelVariant]
    let isDeprecated: Bool

    var id: String { "\(provider.name)-\(key)" }

    private var displayVariants: [ExploreModelVariant] {
        let filtered = variants.filter { !$0.isUtilityVariant }
        return filtered.isEmpty ? variants : filtered
    }

    var isUtilityFamily: Bool {
        variants.allSatisfy(\.isUtilityVariant)
    }

    var preferredVariant: ExploreModelVariant {
        displayVariants.max(by: { $0.selectionScore < $1.selectionScore }) ?? displayVariants[0]
    }

    var highestVersion: Double {
        displayVariants.map(\.versionSort).max() ?? 0
    }

    var providerLeadScore: Int {
        let versionScore = Int(highestVersion * 100)
        let familyPriority = Self.providerFamilyPriority(provider.name, familyKey: key)
        let deprecationPenalty = isDeprecated ? 500 : 0
        return familyPriority + versionScore - deprecationPenalty
    }

    var availableVersions: [String] {
        let versions = Dictionary(grouping: displayVariants, by: \.versionLabel)
        return versions.keys.sorted { lhs, rhs in
            let lhsScore = versions[lhs]?.map(\.versionSort).max() ?? 0
            let rhsScore = versions[rhs]?.map(\.versionSort).max() ?? 0
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs < rhs
        }
    }

    var searchTerms: [String] {
        let providerTerm = provider.name.lowercased()
        let familyTerm = name.lowercased()
        let variantTerms = displayVariants.flatMap { variant in
            [
                variant.model.id.lowercased(),
                variant.model.name.lowercased(),
                variant.mode.label.lowercased(),
                variant.versionLabel.lowercased(),
            ]
        }
        return [providerTerm, familyTerm, summary.lowercased()] + variantTerms
    }

    func availableModes(for version: String) -> [ExploreVariantMode] {
        (displayVariants
            .filter { $0.versionLabel == version }
            .map(\.mode)
            + [.edit])
            .uniqued()
            .sorted(by: { $0.order < $1.order })
    }

    func variant(version: String, mode: ExploreVariantMode) -> ExploreModelVariant? {
        let sameVersion = displayVariants.filter { $0.versionLabel == version }
        guard !sameVersion.isEmpty else { return preferredVariant }

        switch mode {
        case .standard, .edit:
            if let standard = sameVersion.first(where: { $0.mode == .standard }) {
                return standard
            }
            if let nonSequential = sameVersion.first(where: { $0.mode != .sequential }) {
                return nonSequential
            }
            return sameVersion.max(by: { $0.selectionScore < $1.selectionScore }) ?? preferredVariant
        case .sequential:
            if let sequential = sameVersion.first(where: { $0.mode == .sequential }) {
                return sequential
            }
            if let standard = sameVersion.first(where: { $0.mode == .standard }) {
                return standard
            }
            return sameVersion.max(by: { $0.selectionScore < $1.selectionScore }) ?? preferredVariant
        }
    }

    static func sortDescending(lhs: ExploreFamilyGroup, rhs: ExploreFamilyGroup) -> Bool {
        if lhs.provider.order != rhs.provider.order {
            return lhs.provider.order < rhs.provider.order
        }
        if lhs.providerLeadScore != rhs.providerLeadScore {
            return lhs.providerLeadScore > rhs.providerLeadScore
        }
        return lhs.name < rhs.name
    }

    static func build(from models: [CatalogModel]) -> [ExploreFamilyGroup] {
        let variants = models.map(ExploreModelVariant.init(model:))
        let grouped = Dictionary(grouping: variants) { variant in
            "\(variant.provider.name)|\(variant.familyKey)"
        }

        return grouped.values.compactMap { familyVariants in
            guard let first = familyVariants.first else { return nil }
            let preferred = familyVariants.max(by: { $0.selectionScore < $1.selectionScore }) ?? first
            let summary = preferred.model.summary ?? "Open this family to choose a version and mode."
            return ExploreFamilyGroup(
                provider: first.provider,
                key: first.familyKey,
                name: first.familyName,
                summary: summary,
                variants: familyVariants.sorted(by: { $0.selectionScore > $1.selectionScore }),
                isDeprecated: first.familyKey.contains("dall-e")
            )
        }
        .filter { !$0.isUtilityFamily }
        .sorted(by: sortDescending)
    }

    private static func providerFamilyPriority(_ providerName: String, familyKey: String) -> Int {
        switch providerName {
        case "ByteDance":
            return familyKey.contains("seedream") ? 900 : 400
        case "Google":
            return familyKey.contains("nano-banana") ? 920 : 420
        case "OpenAI":
            if familyKey.contains("gpt-image") {
                return 950
            }
            if familyKey.contains("dall-e") {
                return 120
            }
            return 430
        case "Black Forest Labs":
            return familyKey.contains("flux") ? 860 : 420
        case "Kuaishou":
            return familyKey.contains("kling") ? 860 : 420
        case "MiniMax":
            return familyKey.contains("hailuo") || familyKey.contains("minimax") ? 840 : 420
        default:
            return 500
        }
    }
}

private struct ExploreModelVariant: Identifiable, Hashable {
    let model: CatalogModel
    let provider: ExploreProvider
    let familyKey: String
    let familyName: String
    let versionLabel: String
    let versionSort: Double
    let mode: ExploreVariantMode
    let isUtilityVariant: Bool

    init(model: CatalogModel) {
        self.model = model

        let normalized = Self.normalizedText(for: model)
        self.isUtilityVariant = Self.isUtilityVariant(normalized)
        self.provider = Self.inferProvider(from: normalized)

        let family = Self.inferFamily(from: normalized, model: model)
        self.familyKey = family.key
        self.familyName = family.name

        let version = Self.inferVersion(from: normalized, familyKey: family.key)
        self.versionLabel = version.label
        self.versionSort = version.sort

        self.mode = ExploreVariantMode.infer(from: normalized, model: model)
    }

    var id: String { model.id }

    var selectionScore: Int {
        let modeBias: Int
        switch mode {
        case .standard:
            modeBias = 30
        case .edit:
            modeBias = 20
        case .sequential:
            modeBias = 10
        }
        return Int(versionSort * 100) + modeBias
    }

    var variantLabel: String {
        versionLabel
    }

    private static func normalizedText(for model: CatalogModel) -> String {
        "\(model.id) \(model.name) \(model.summary ?? "")"
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
    }

    private static func isUtilityVariant(_ normalized: String) -> Bool {
        let utilityTokens = ["controlnet", "control-net", "chrono", "shand"]
        return utilityTokens.contains { normalized.contains($0) }
    }

    private static func inferProvider(from normalized: String) -> ExploreProvider {
        let name: String
        switch normalized {
        case let value where value.contains("seedream") || value.contains("bytedance") || value.contains("doubao"):
            name = "ByteDance"
        case let value where value.contains("banana") || value.contains("imagen") || value.contains("veo") || value.contains("google"):
            name = "Google"
        case let value where value.contains("gpt-image") || value.contains("dall-e") || value.contains("dalle") || value.contains("openai"):
            name = "OpenAI"
        case let value where value.contains("flux") || value.contains("black-forest"):
            name = "Black Forest Labs"
        case let value where value.contains("kling") || value.contains("kuaishou"):
            name = "Kuaishou"
        case let value where value.contains("hailuo") || value.contains("minimax"):
            name = "MiniMax"
        case let value where value.contains("runway"):
            name = "Runway"
        default:
            name = "Other"
        }

        return ExploreProvider(
            name: name,
            order: providerOrder(for: name),
            leadingLabel: leadingLabel(for: name)
        )
    }

    private static func inferFamily(from normalized: String, model: CatalogModel) -> (key: String, name: String) {
        switch normalized {
        case let value where value.contains("seedream"):
            return ("seedream", "Seedream")
        case let value where value.contains("nano-banana") || value.contains("banana"):
            return ("nano-banana", "Nano Banana")
        case let value where value.contains("gpt-image"):
            return ("gpt-image", "GPT Image")
        case let value where value.contains("dall-e") || value.contains("dalle"):
            return ("dall-e", "DALL-E")
        case let value where value.contains("flux-kontext"):
            return ("flux-kontext", "Flux Kontext")
        case let value where value.contains("flux"):
            return ("flux", "Flux")
        case let value where value.contains("kling"):
            return ("kling", "Kling")
        case let value where value.contains("hailuo"):
            return ("hailuo", "Hailuo")
        case let value where value.contains("runway"):
            return ("runway", "Runway")
        default:
            let fallback = model.name
                .replacingOccurrences(
                    of: #"(?i)\b(v?\d+(?:\.\d+)?)\b|\b(edit|sequential|normal|standard|pro|max)\b"#,
                    with: "",
                    options: .regularExpression
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (fallback.lowercased().replacingOccurrences(of: " ", with: "-"), fallback.isEmpty ? model.name : fallback)
        }
    }

    private static func inferVersion(from normalized: String, familyKey: String) -> (label: String, sort: Double) {
        let patterns: [String]
        switch familyKey {
        case "gpt-image":
            patterns = [#"gpt-image[- ]?(?:v)?(\d+(?:\.\d+)?)"#]
        case "seedream":
            patterns = [#"seedream[- ]?(?:v)?(\d+(?:\.\d+)?)"#]
        case "nano-banana":
            patterns = [#"(?:nano-banana|banana)[- ]?(?:v)?(\d+(?:\.\d+)?)"#]
        case "kling":
            patterns = [#"kling[- ]?(?:v)?(\d+(?:\.\d+)?)"#]
        default:
            patterns = [#"(?:^|[- ])v?(\d+(?:\.\d+)?)(?:$|[- ])"#]
        }

        for pattern in patterns {
            if let match = firstMatch(in: normalized, pattern: pattern),
               let value = Double(match)
            {
                let label = match.contains(".") ? match : "v\(match)"
                return (label, value)
            }
        }

        if normalized.contains("pro") {
            return ("Pro", 90)
        }
        if normalized.contains("max") {
            return ("Max", 95)
        }

        return ("Latest", 80)
    }

    private static func providerOrder(for name: String) -> Int {
        switch name {
        case "ByteDance":
            return 0
        case "Google":
            return 1
        case "OpenAI":
            return 2
        case "Black Forest Labs":
            return 3
        case "Kuaishou":
            return 4
        case "MiniMax":
            return 5
        case "Runway":
            return 6
        default:
            return 20
        }
    }

    private static func leadingLabel(for name: String) -> String {
        switch name {
        case "ByteDance":
            return "Seedream first"
        case "Google":
            return "Nano Banana first"
        case "OpenAI":
            return "GPT Image first"
        default:
            return "Top family"
        }
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[captureRange])
    }
}

private enum ExploreVariantMode: Hashable {
    case standard
    case edit
    case sequential

    var label: String {
        switch self {
        case .standard:
            return "Normal"
        case .edit:
            return "Edit"
        case .sequential:
            return "Sequential"
        }
    }

    var order: Int {
        switch self {
        case .standard:
            return 0
        case .edit:
            return 1
        case .sequential:
            return 2
        }
    }

    var systemImage: String {
        switch self {
        case .standard:
            return "sparkles"
        case .edit:
            return "slider.horizontal.3"
        case .sequential:
            return "square.3.stack.3d"
        }
    }

    var composerIntent: ComposerIntent {
        switch self {
        case .edit:
            return .edit
        case .standard, .sequential:
            return .create
        }
    }

    init?(label: String) {
        switch label.lowercased() {
        case "normal":
            self = .standard
        case "edit":
            self = .edit
        case "sequential":
            self = .sequential
        default:
            return nil
        }
    }

    static func infer(from normalized: String, model: CatalogModel) -> ExploreVariantMode {
        if normalized.contains("sequential") || normalized.contains("sequence") {
            return .sequential
        }
        if normalized.contains("edit") || model.requiresImageInput || (model.kind ?? "").lowercased() == "edit" {
            return .edit
        }
        return .standard
    }
}

extension Array where Element: Hashable {
    fileprivate func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
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
