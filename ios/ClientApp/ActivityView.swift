import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        NavigationStack {
            List(session.jobs) { job in
                NavigationLink {
                    JobDetailView(jobID: job.id)
                } label: {
                    JobRow(job: job)
                }
            }
            .overlay {
                if session.jobs.isEmpty && !session.isBusy {
                    ContentUnavailableView(
                        "No jobs yet",
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        description: Text("Run a generation to see job history here.")
                    )
                }
            }
            .navigationTitle("Activity")
            .refreshable {
                await session.refreshJobs()
            }
        }
    }
}

struct JobRow: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(job.modelName ?? job.modelId)
                .font(.headline)
            if let prompt = job.prompt, !prompt.isEmpty {
                Text(prompt)
                    .lineLimit(2)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(job.status.rawValue.capitalized)
                if let createdAt = job.createdAt {
                    Text(createdAt)
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
