import Foundation
import Supabase
import Auth
import SwiftUI
import Combine
import AuthenticationServices

@MainActor
class AuthViewModel: ObservableObject {
    static let shared = AuthViewModel()
    private let appleSignInManager = AppleSignInManager()

    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var session: Session?
    
    var userId: String? {
        session?.user.id.uuidString
    }
    
    init() {
        // Fetch initial session
        Task {
            do {
                self.session = try await SupabaseManager.shared.client.auth.session
            } catch {
                print("Error fetching initial session: \(error)")
            }
        }
        
        // Listen for auth state changes
        Task {
            for await (event, session) in SupabaseManager.shared.client.auth.authStateChanges {
                await MainActor.run {
                    self.session = session
                    print("Auth Event: \(event)")
                    
                    // Register device token for the new user if we have a session
                    if let user = session?.user, (event == .signedIn || event == .initialSession) {
                        MessagingManager.shared.registerCurrentDevice(userId: user.id.uuidString)
                    }
                }
            }
        }
    }
    
    func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await SupabaseManager.shared.client.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func signUp() async {
        isLoading = true
        errorMessage = nil
        do {
            try await SupabaseManager.shared.client.auth.signUp(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        do {
            // Supabase: Sign in with Google (OAuth)
            // The SDK handles the browser redirect flow automatically.
            _ = try await SupabaseManager.shared.client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "mysocialcookbook://login-callback")
            )
            // If we reach here without error, the OAuth flow initiated successfully.
            // The actual session is set when the app handles the callback URL.
            // In a real iOS app using supabase-swift, the SDK handles the ASWebAuthenticationSession automatically if using the helper,
            // or returns the URL for you to handle.
            // Current SDK implementation might handle it automatically if properly configured.
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func startAppleSignIn() {
        isLoading = true
        errorMessage = nil
        
        appleSignInManager.startSignInWithApple { [weak self] result in
            guard let self = self else { return }
            
            Task {
                switch result {
                case .success(let authorization):
                    if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                        guard let nonce = self.appleSignInManager.getUnhashedNonce(),
                              let appleIDToken = appleIDCredential.identityToken,
                              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                            self.errorMessage = "Unable to fetch identity token."
                            self.isLoading = false
                            return
                        }
                        
                        // Pass to Supabase
                        do {
                            try await SupabaseManager.shared.client.auth.signInWithIdToken(
                                credentials: .init(provider: .apple, idToken: idTokenString, nonce: nonce)
                            )
                        } catch {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                case .failure(let error):
                    if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                        self.errorMessage = error.localizedDescription
                    }
                }
                self.isLoading = false
            }
        }
    }
    
    func signOut() async {
        do { 
            try await SupabaseManager.shared.client.auth.signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}
