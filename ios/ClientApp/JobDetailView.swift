import SwiftUI

struct JobDetailView: View {
    @EnvironmentObject private var session: AppSession
    let jobID: String

    private var job: Job? {
        session.jobs.first(where: { $0.id == jobID })
    }

    var body: some View {
        List {
            if let job {
                Section("Status") {
                    LabeledContent("Model", value: job.modelName ?? job.modelId)
                    LabeledContent("State", value: job.status.rawValue.capitalized)
                    if let createdAt = job.createdAt {
                        LabeledContent("Created", value: createdAt)
                    }
                    if let updatedAt = job.updatedAt {
                        LabeledContent("Updated", value: updatedAt)
                    }
                    if let errorMessage = job.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if let prompt = job.prompt, !prompt.isEmpty {
                    Section("Prompt") {
                        Text(prompt)
                    }
                }

                if !job.outputs.isEmpty {
                    Section("Outputs") {
                        ForEach(job.outputs) { output in
                            VStack(alignment: .leading, spacing: 12) {
                                AsyncImage(url: output.url) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.secondary.opacity(0.12))
                                        .frame(height: 180)
                                        .overlay(ProgressView())
                                }
                                .frame(maxHeight: 240)

                                HStack {
                                    Link("Open", destination: output.url)
                                    Spacer()
                                    Button("Save locally") {
                                        Task {
                                            await session.saveOutput(output, for: job)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }

                if !job.status.isTerminal {
                    Section {
                        Button("Refresh status") {
                            Task { await session.pollJobIfNeeded(jobID: jobID) }
                        }
                        Button("Cancel job", role: .destructive) {
                            Task { await session.cancel(job: job) }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Job unavailable", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Job")
        .navigationBarTitleDisplayMode(.inline)
    }
}
