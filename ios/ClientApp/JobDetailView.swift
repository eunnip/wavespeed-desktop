import SwiftUI

struct JobDetailView: View {
    @EnvironmentObject private var session: AppSession
    let jobID: String

    private var job: Job? {
        session.jobs.first(where: { $0.id == jobID })
    }

    var body: some View {
        ZStack {
            StudioBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let job {
                        heroCard(job: job)

                        if let prompt = job.prompt, !prompt.isEmpty {
                            promptCard(prompt: prompt)
                        }

                        outputsSection(job: job)

                        if !job.status.isTerminal {
                            controlsCard(job: job)
                        }
                    } else {
                        StudioEmptyStateCard(
                            title: "Job unavailable",
                            detail: "This run is no longer available in the local activity feed.",
                            systemImage: "exclamationmark.triangle"
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Job")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: jobID) {
            guard let job, !job.status.isTerminal else { return }
            await session.pollJobIfNeeded(jobID: jobID)
        }
    }

    private func heroCard(job: Job) -> some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: heroGradient(for: job.status),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 84, height: 104)
                        .overlay {
                            Image(systemName: job.status.symbolName)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(job.status.tintColor)
                        }

                    VStack(alignment: .leading, spacing: 10) {
                        StudioStatusBadge(
                            icon: job.status.symbolName,
                            title: job.status.label,
                            tint: job.status.tintColor
                        )

                        Text(job.modelName ?? job.modelId)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(job.formattedTimestamp)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(job.id)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                }

                if !job.status.isTerminal {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(Color("AccentColor"))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Generating your result")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Stay on this screen while PhotoG polls for the finished output.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                if let errorMessage = job.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private func promptCard(prompt: String) -> some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 12) {
                StudioSectionHeader(
                    eyebrow: "Prompt",
                    title: "What this run was asked to create"
                )

                Text(prompt)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func outputsSection(job: Job) -> some View {
        if job.outputs.isEmpty {
            StudioSurface {
                VStack(alignment: .leading, spacing: 16) {
                    StudioSectionHeader(
                        eyebrow: "Outputs",
                        title: job.status.isTerminal ? "No outputs yet" : "Still generating"
                    )

                    if job.status.isTerminal {
                        Text("This run finished without any saved output files.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(Color("AccentColor"))
                                Text("PhotoG is checking for the finished asset.")
                                    .font(.subheadline.weight(.medium))
                            }

                            Text("The result page will update here as soon as the backend returns the generated image or video.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                StudioSectionHeader(
                    eyebrow: "Outputs",
                    title: "Generated results"
                )

                ForEach(job.outputs) { output in
                    JobOutputCard(job: job, output: output)
                }
            }
        }
    }

    private func controlsCard(job: Job) -> some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 14) {
                StudioSectionHeader(
                    eyebrow: "Controls",
                    title: "Manage this run"
                )

                Button {
                    Task { await session.pollJobIfNeeded(jobID: jobID) }
                } label: {
                    HStack {
                        Spacer()
                        Label("Refresh status", systemImage: "arrow.clockwise")
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

                Button(role: .destructive) {
                    Task { await session.cancel(job: job) }
                } label: {
                    HStack {
                        Spacer()
                        Label("Cancel run", systemImage: "xmark.circle")
                            .font(.headline.weight(.semibold))
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func heroGradient(for status: JobStatus) -> [Color] {
        switch status {
        case .queued, .running:
            return [Color(red: 0.90, green: 0.95, blue: 1.0), Color(red: 0.97, green: 0.90, blue: 0.98)]
        case .completed:
            return [Color(red: 0.92, green: 0.98, blue: 0.95), Color(red: 0.95, green: 0.93, blue: 1.0)]
        case .failed, .canceled:
            return [Color(red: 1.0, green: 0.94, blue: 0.92), Color(red: 0.99, green: 0.95, blue: 0.91)]
        }
    }
}

private struct JobOutputCard: View {
    @EnvironmentObject private var session: AppSession

    let job: Job
    let output: JobOutput

    var body: some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 16) {
                if output.isImageOutput {
                    AsyncImage(url: output.url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.studioPanel)
                            .overlay(ProgressView())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                            VStack(spacing: 10) {
                                Image(systemName: "doc.richtext.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Color("AccentColor"))
                                Text("Open the output to view it externally.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }

                HStack(spacing: 12) {
                    Link(destination: output.url) {
                        HStack {
                            Spacer()
                            Label("Open output", systemImage: "arrow.up.right.square")
                                .font(.headline.weight(.semibold))
                            Spacer()
                        }
                        .foregroundStyle(Color("AccentColor"))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Button {
                        Task {
                            await session.saveOutput(output, for: job)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Save locally", systemImage: "square.and.arrow.down")
                                .font(.headline.weight(.semibold))
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
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
    }
}
