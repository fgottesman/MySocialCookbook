import SwiftUI

struct ContentView: View {
    @State private var session: Bool = false // Simple boolean for now, checking auth status
    
    // We will listen to Supabase auth events in a real app, 
    // but for now let's just use the AuthView logic which will sign us in.
    // Ideally we subscribe to SupabaseManager.shared.client.auth.authStateChanges
    
    @State private var isAuthenticated = false

    var body: some View {
        Group {
            if isAuthenticated {
                FeedView()
            } else {
                AuthView()
            }
        }
        .task {
            // Check initial session
            for await _ in SupabaseManager.shared.client.auth.authStateChanges {
                if let _ = try? await SupabaseManager.shared.client.auth.session {
                    isAuthenticated = true
                } else {
                    isAuthenticated = false
                }
            }
        }
    }
}
