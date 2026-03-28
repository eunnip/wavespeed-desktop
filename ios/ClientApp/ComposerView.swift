import PhotosUI
import SwiftUI

struct ComposerView: View {
    @EnvironmentObject private var session: AppSession
    let model: CatalogModel

    @State private var prompt = ""
    @State private var negativePrompt = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isSubmitting = false
    @State private var submittedJob: Job?

    var body: some View {
        Form {
            Section("Model") {
                Text(model.name)
                if let summary = model.summary {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Prompt") {
                TextField("Describe what to generate", text: $prompt, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                TextField("Negative prompt (optional)", text: $negativePrompt, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }

            Section("Input") {
                if model.requiresImageInput {
                    PhotosPicker("Pick input image", selection: $selectedPhoto, matching: .images)
                    if let selectedImageData, let image = UIImage(data: selectedImageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Text("This model does not require an image input.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Run job")
                    }
                }
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let submittedJob {
                Section("Latest job") {
                    NavigationLink {
                        JobDetailView(jobID: submittedJob.id)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(submittedJob.status.rawValue.capitalized)
                            Text(submittedJob.id)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPhoto) {
            guard let selectedPhoto else { return }
            selectedImageData = try? await selectedPhoto.loadTransferable(type: Data.self)
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            submittedJob = try await session.submitJob(
                model: model,
                prompt: prompt,
                negativePrompt: negativePrompt,
                selectedImageData: selectedImageData
            )
        } catch {
            session.errorText = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}
