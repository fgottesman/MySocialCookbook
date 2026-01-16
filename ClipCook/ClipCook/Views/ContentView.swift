import SwiftUI
import Supabase
import Auth

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var isInitialLoading = true

    var body: some View {
        ZStack {
            // Background color that extends behind floating tab bar
            Color.clipCookBackground.ignoresSafeArea()

            Group {
                if isAuthenticated {
                    MainTabView()
                } else {
                    AuthView()
                }
            }
            .opacity(isInitialLoading ? 0 : 1)
            
            if isInitialLoading {
                SplashView()
                    .transition(.opacity)
            }
        }
        .task {
            // Give splash screen a moment to shine
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            // Check initial session and listen for changes
            for await _ in SupabaseManager.shared.client.auth.authStateChanges {
                let session = try? await SupabaseManager.shared.client.auth.session
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isAuthenticated = session != nil
                        isInitialLoading = false
                    }
                }
                
                if let session = session {
                    // SAVE USER ID to Shared Defaults for Share Extension
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.mysocialcookbook") {
                        sharedDefaults.set(session.user.id.uuidString, forKey: "shared_user_id")
                    }
                } else {
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

struct SplashView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.clipCookBackground.ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.roseGold)
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 0.3 : 0.6)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(LinearGradient.roseGold)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                }
                
                Text("ClipCook")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient.roseGold)
                    .floatingAnimation()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

extension View {
    func floatingAnimation() -> some View {
        self.modifier(FloatingModifier())
    }
}

struct FloatingModifier: ViewModifier {
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    offset = -10
                }
            }
    }
}
