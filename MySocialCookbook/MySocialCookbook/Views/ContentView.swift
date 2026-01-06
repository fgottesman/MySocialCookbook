import SwiftUI
import Supabase
import Auth

struct ContentView: View {
    @State private var session: Bool = false // Simple boolean for now, checking auth status
    
    // We will listen to Supabase auth events in a real app, 
    // but for now let's just use the AuthView logic which will sign us in.
    // Ideally we subscribe to SupabaseManager.shared.client.auth.authStateChanges
    
    @State private var isAuthenticated = false

    var body: some View {
        Group {
            if isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .task {
            // Check initial session and listen for changes
            for await _ in SupabaseManager.shared.client.auth.authStateChanges {
                if let session = try? await SupabaseManager.shared.client.auth.session {
                    isAuthenticated = true
                    
                    // SAVE USER ID to Shared Defaults for Share Extension
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.mysocialcookbook") {
                        sharedDefaults.set(session.user.id.uuidString, forKey: "shared_user_id")
                    }
                } else {
                    isAuthenticated = false
                    
                    // Clear User ID on logout
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.mysocialcookbook") {
                        sharedDefaults.removeObject(forKey: "shared_user_id")
                    }
                }
            }
        }
        .onAppear {
            MessagingManager.shared.requestPermission()
        }
    }
}
