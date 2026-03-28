import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        NavigationStack {
            List(session.localAssets) { asset in
                VStack(alignment: .leading, spacing: 8) {
                    if let image = UIImage(contentsOfFile: asset.fileURL.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text(asset.filename)
                        .font(.headline)
                    Text(asset.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ShareLink(item: asset.fileURL) {
                        Text("Share")
                    }
                }
                .padding(.vertical, 8)
            }
            .overlay {
                if session.localAssets.isEmpty {
                    ContentUnavailableView(
                        "No saved outputs",
                        systemImage: "photo",
                        description: Text("Save an output from a completed job to keep it on device.")
                    )
                }
            }
            .navigationTitle("Library")
            .refreshable {
                await session.loadLocalAssets()
            }
        }
    }
}
