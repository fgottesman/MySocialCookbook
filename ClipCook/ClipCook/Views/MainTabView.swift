import SwiftUI

struct MainTabView: View {
    // Tab bar appearance is now configured in ClipCookApp.init()
    // to prevent color flashing on tab switches
    
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(Color(hex: "E8C4B8")) // Rose gold accent for selected state
    }
}

#Preview {
    MainTabView()
}

