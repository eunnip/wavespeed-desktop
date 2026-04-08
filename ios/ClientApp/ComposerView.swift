import PhotosUI
import SwiftUI

enum ComposerIntent: String, CaseIterable, Hashable, Identifiable {
    case create
    case edit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .create:
            return "Create"
        case .edit:
            return "Edit"
        }
    }

    var detail: String {
        switch self {
        case .create:
            return "Start from a prompt and generate a fresh result."
        case .edit:
            return "Upload a picture and describe exactly how it should be changed."
        }
    }
}

struct ComposerDestination: Hashable {
    let model: CatalogModel
    let intent: ComposerIntent

    init(model: CatalogModel, intent: ComposerIntent? = nil) {
        self.model = model

        if let intent {
            self.intent = intent
            return
        }

        let normalizedKind = (model.kind ?? "").lowercased()
        if model.requiresImageInput || normalizedKind == "edit" {
            self.intent = .edit
        } else {
            self.intent = .create
        }
    }
}

private struct JobDestination: Hashable, Identifiable {
    let id: String
}

struct ComposerView: View {
    @EnvironmentObject private var session: AppSession

    let destination: ComposerDestination

    @State private var prompt = ""
    @State private var negativePrompt = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var composerIntent: ComposerIntent
    @State private var isSubmitting = false
    @State private var submittedJob: Job?
    @State private var activeJobDestination: JobDestination?

    init(model: CatalogModel) {
        let destination = ComposerDestination(model: model)
        self.destination = destination
        _composerIntent = State(initialValue: destination.intent)
    }

    init(destination: ComposerDestination) {
        self.destination = destination
        _composerIntent = State(initialValue: destination.intent)
    }

    private var model: CatalogModel {
        destination.model
    }

    private var isEditMode: Bool {
        composerIntent == .edit
    }

    private var supportsEditToggle: Bool {
        true
    }

    private var referenceInputRequired: Bool {
        model.requiresImageInput || isEditMode
    }

    private var shouldShowReferenceCard: Bool {
        referenceInputRequired || selectedImageData != nil
    }

    private var currentInputLabel: String {
        referenceInputRequired ? "Reference photo" : model.inputLabel
    }

    private var createModeLabel: String {
        switch (model.kind ?? "").lowercased() {
        case "video":
            return "Text to Video"
        default:
            return "Text to Image"
        }
    }

    private func modeLabel(_ intent: ComposerIntent) -> String {
        switch intent {
        case .create:
            return createModeLabel
        case .edit:
            return "Edit"
        }
    }

    private var starterPrompts: [String] {
        if isEditMode {
            return [
                "Keep the same composition, but refine the lighting and premium finish",
                "Change this image into a cleaner lifestyle campaign shot with softer tones",
                "Preserve the subject and structure, but restyle the scene with a more polished look"
            ]
        }

        switch (model.kind ?? "").lowercased() {
        case "video":
            return [
                "Cinematic motion with soft camera drift and elegant light",
                "Luxury product moment with crisp reflections and slow movement",
                "Editorial scene that feels premium, modern, and atmospheric"
            ]
        default:
            return [
                "A polished portrait with flattering natural light and premium styling",
                "A dreamy lifestyle image with warm highlights and calm composition",
                "A bold studio concept with clean shapes and premium color contrast"
            ]
        }
    }

    private var canSubmit: Bool {
        let hasPrompt = !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let satisfiesInput = !referenceInputRequired || selectedImageData != nil
        return hasPrompt && satisfiesInput && !isSubmitting
    }

    var body: some View {
        ZStack {
            StudioBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroCard
                    promptCard

                    if shouldShowReferenceCard {
                        referenceCard
                    }

                    refinementCard

                    if let submittedJob {
                        latestJobCard(job: submittedJob)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $activeJobDestination) { destination in
            JobDetailView(jobID: destination.id)
        }
        .safeAreaInset(edge: .bottom) {
            runBar
        }
        .task(id: selectedPhoto) {
            guard let selectedPhoto else { return }
            selectedImageData = try? await selectedPhoto.loadTransferable(type: Data.self)
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: model.featuredGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        StudioStatusBadge(
                            icon: model.symbolName,
                            title: model.displayKind,
                            tint: .white
                        )

                        Text(model.name)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(model.summary ?? "A polished creation tool for fresh Photo G concepts.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: model.symbolName)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 66, height: 66)
                        .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                HStack(spacing: 12) {
                    ComposerHeroPill(title: modeLabel(composerIntent))
                    ComposerHeroPill(title: currentInputLabel)
                    ComposerHeroPill(title: model.displayKind)
                }
            }
            .padding(24)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2))
        )
        .shadow(color: model.featuredGradient.last?.opacity(0.22) ?? .clear, radius: 24, y: 14)
    }

    private var promptCard: some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 16) {
                StudioSectionHeader(
                    eyebrow: "Prompt",
                    title: "Shape the result",
                    detail: isEditMode
                        ? "Tell PhotoG what should change in the uploaded image while keeping the right parts intact."
                        : "Write the core scene first, then tap a starter to quickly steer tone, mood, or output style."
                )

                if supportsEditToggle {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MODE")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("Mode", selection: $composerIntent) {
                            ForEach(ComposerIntent.allCases) { intent in
                                Text(modeLabel(intent)).tag(intent)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                TextField(
                    isEditMode
                        ? "Describe how the uploaded picture should be changed"
                        : "Describe the image or clip you want to create",
                    text: $prompt,
                    axis: .vertical
                )
                    .font(.body)
                    .lineLimit(6, reservesSpace: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(starterPrompts, id: \.self) { starter in
                            Button {
                                prompt = starter
                            } label: {
                                ComposerSuggestionChip(text: starter)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var referenceCard: some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 16) {
                StudioSectionHeader(
                    eyebrow: "Reference",
                    title: "Add a source image",
                    detail: isEditMode
                        ? "Upload the picture you want to transform, then describe the changes above."
                        : "This reference is optional here, but you can keep it attached or remove it before running."
                )

                if let imageData = selectedImageData, let image = UIImage(data: imageData) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                        Button {
                            selectedPhoto = nil
                            selectedImageData = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.62), in: Circle())
                        }
                        .padding(14)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.studioPanelStrong, Color("AccentColor").opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 220)
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Color("AccentColor"))
                                Text("Choose a reference image")
                                    .font(.headline)
                                Text("Portraits, products, and scenes all work well here.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack {
                        Spacer()
                        Label(selectedImageData == nil ? "Pick image" : "Replace image", systemImage: "photo.on.rectangle")
                            .font(.headline.weight(.semibold))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color("AccentColor"), Color(red: 0.98, green: 0.71, blue: 0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var refinementCard: some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 16) {
                StudioSectionHeader(
                    eyebrow: "Refine",
                    title: "Optional direction",
                    detail: "Use this field to steer away from unwanted details or aesthetics."
                )

                TextField("Negative prompt or constraints", text: $negativePrompt, axis: .vertical)
                    .font(.body)
                    .lineLimit(4, reservesSpace: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                HStack(spacing: 12) {
                    StudioSummaryCard(value: model.displayKind, label: "Output mode")
                    StudioSummaryCard(value: referenceInputRequired ? "Required" : "Optional", label: "Reference input")
                }
            }
        }
    }

    private func latestJobCard(job: Job) -> some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 16) {
                StudioSectionHeader(
                    eyebrow: "Latest",
                    title: "Your newest run is underway"
                )

                NavigationLink {
                    JobDetailView(jobID: job.id)
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: model.softGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 62, height: 62)
                            .overlay {
                                Image(systemName: job.status.symbolName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(job.status.tintColor)
                            }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(job.status.label)
                                    .font(.headline)
                                Text(job.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Text(job.prompt ?? prompt)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 10)

                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var runBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(height: 0)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        canSubmit
                            ? (isEditMode ? "Ready to edit" : "Ready to create")
                            : "Add prompt\(referenceInputRequired && selectedImageData == nil ? " and image" : "")"
                    )
                        .font(.subheadline.weight(.semibold))
                    Text(model.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 10) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                        Text(isSubmitting ? "Running..." : "Run")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color("AccentColor"), Color(red: 0.98, green: 0.71, blue: 0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 18)
            .background(Color.studioSurface.opacity(0.96))
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let job = try await session.submitJob(
                model: model,
                prompt: prompt,
                negativePrompt: negativePrompt,
                selectedImageData: referenceInputRequired ? selectedImageData : nil
            )
            submittedJob = job
            activeJobDestination = JobDestination(id: job.id)
        } catch {
            session.errorText = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}

private struct ComposerHeroPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.14), in: Capsule())
    }
}

private struct ComposerSuggestionChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
