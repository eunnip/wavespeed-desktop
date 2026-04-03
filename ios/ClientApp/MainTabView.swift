import SwiftUI

struct MainTabView: View {
    @State private var selection: MainTab = .home
    @State private var exploreKind: ExploreKind = .all

    var body: some View {
        TabView(selection: $selection) {
            CreateView(selectedTab: $selection, exploreKind: $exploreKind)
                .tag(MainTab.home)
                .tabItem {
                    Label("Home", systemImage: selection == .home ? "house.fill" : "house")
                }

            ActivityView(selectedKind: $exploreKind)
                .tag(MainTab.explore)
                .tabItem {
                    Label("Explore", systemImage: selection == .explore ? "safari.fill" : "safari")
                }

            LibraryView()
                .tag(MainTab.library)
                .tabItem {
                    Label("Library", systemImage: selection == .library ? "photo.stack.fill" : "photo.on.rectangle.angled")
                }

            AccountView()
                .tag(MainTab.profile)
                .tabItem {
                    Label("Profile", systemImage: selection == .profile ? "person.crop.circle.fill" : "person.crop.circle")
                }
        }
        .tint(Color("AccentColor"))
        .toolbarColorScheme(.dark, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.black.opacity(0.94), for: .tabBar)
    }
}

enum MainTab: Hashable {
    case home
    case explore
    case library
    case profile
}
