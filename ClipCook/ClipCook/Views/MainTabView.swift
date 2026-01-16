import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    init() {
        // Configure UIKit appearance for tab bar and nav bar
        UIKitAppearance.configure()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(2)
        }
        .tint(DesignTokens.Colors.primary)
        .tabViewStyle(.tabBarOnly)
    }
}

#Preview {
    MainTabView()
}

