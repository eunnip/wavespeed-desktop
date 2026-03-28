import SwiftUI

struct CreateView: View {
    @EnvironmentObject private var session: AppSession
    @State private var searchText = ""

    private var filteredModels: [CatalogModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return session.catalog }
        return session.catalog.filter {
            $0.name.lowercased().contains(query)
                || ($0.summary?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredModels) { model in
                NavigationLink(value: model) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.name)
                            .font(.headline)
                        if let summary = model.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        HStack {
                            Text(model.kind ?? "Generation")
                            if model.requiresImageInput {
                                Text("Image input")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .overlay {
                if session.catalog.isEmpty && !session.isBusy {
                    ContentUnavailableView(
                        "No models yet",
                        systemImage: "tray",
                        description: Text("Connect to your backend and expose `/v1/catalog/models` to populate this screen.")
                    )
                }
            }
            .refreshable {
                await session.refreshSessionData()
            }
            .searchable(text: $searchText)
            .navigationTitle("Create")
            .navigationDestination(for: CatalogModel.self) { model in
                ComposerView(model: model)
            }
        }
    }
}
