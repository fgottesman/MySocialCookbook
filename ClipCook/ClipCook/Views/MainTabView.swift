import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var hasConfiguredAppearance = false

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
        // Use DesignTokens instead of hardcoded hex values
        .tint(DesignTokens.Colors.primary)
        // Ensure consistent background color
        .background(DesignTokens.Colors.background)
        // Force UIKit appearance configuration on appear
        // This prevents any potential color flashing
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

