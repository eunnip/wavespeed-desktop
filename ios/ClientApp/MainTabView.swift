import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            CreateView()
                .tabItem {
                    Label("Create", systemImage: "sparkles")
                }

            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "clock")
                }

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "photo.on.rectangle")
                }

            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
        }
    }
}
