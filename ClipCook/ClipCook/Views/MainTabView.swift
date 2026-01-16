import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    init() {
        // Configure UIKit appearance immediately in init
        UIKitAppearance.configure()
    }

    var body: some View {
        ZStack {
            // Full-screen background that extends into safe areas
            Color.clipCookBackground
                .ignoresSafeArea()

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
        }
        .toolbarBackground(Color.clipCookBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

#Preview {
    MainTabView()
}

