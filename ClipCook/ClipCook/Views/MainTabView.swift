import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var hasConfiguredAppearance = false

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .toolbarBackground(.hidden, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            FavoritesView()
                .toolbarBackground(.hidden, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
                .tabItem { Label("Favorites", systemImage: "star.fill") }
                .tag(1)
            ProfileView()
                .toolbarBackground(.hidden, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(2)
        }
        .tint(DesignTokens.Colors.primary)
        .onAppear {
            if !hasConfiguredAppearance {
                UIKitAppearance.configure()
                hasConfiguredAppearance = true
            }
        }
    }
}

#Preview {
    MainTabView()
}
