import SwiftUI
import Supabase
import Auth

struct ProfileView: View {
    @State private var userEmail: String?
    @State private var isLoading = true
    @State private var showingSignOutAlert = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.clipCookBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                // User Info Section
                VStack(spacing: 12) {
                    // Profile Icon
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.clipCookTextSecondary.opacity(0.5))
                    
                    // Email
                    if let email = userEmail {
                        Text(email)
                            .font(.headline)
                            .foregroundColor(.clipCookTextPrimary)
                    } else if isLoading {
                        ProgressView()
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
                
                // Menu Items
                VStack(spacing: 0) {
                    // Settings
                    NavigationLink(destination: UserPreferencesView()) {
                        MenuRow(
                            icon: "gearshape",
                            title: "Settings"
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    // Data Privacy
                    NavigationLink(destination: LegalDocumentView(
                        title: "Data Privacy",
                        content: ProfileView.privacyPolicyContent
                    )) {
                        MenuRow(
                            icon: "lock.shield",
                            title: "Data Privacy"
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    // Terms of Service
                    NavigationLink(destination: LegalDocumentView(
                        title: "Terms of Service",
                        content: ProfileView.termsOfServiceContent
                    )) {
                        MenuRow(
                            icon: "doc.text",
                            title: "Terms of Service"
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    // ClipCook Pro
                    NavigationLink(destination: PaywallView()) {
                        MenuRow(
                            icon: "crown",
                            title: "ClipCook Pro"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .background(Color.clipCookSurface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.clipCookSizzleStart.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
                
                Spacer()
                
                // Sign Out Button
                Button(role: .destructive) {
                    showingSignOutAlert = true
                } label: {
                    Text("Sign Out")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                }
                .frame(maxWidth: horizontalSizeClass == .regular ? 600 : .infinity)
            }
            .navigationTitle("Profile")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .task {
                await fetchUserEmail()
            }
        }
    }
    
    private func fetchUserEmail() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            
            await MainActor.run {
                self.userEmail = session.user.email
                self.isLoading = false
            }
        } catch {
            print("Error fetching user email: \(error)")
            isLoading = false
        }
    }
    
    private func signOut() {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.signOut()
            } catch {
                print("Error signing out: \(error)")
            }
        }
    }
}

// MARK: - Menu Row Component
struct MenuRow: View {
    let icon: String
    let title: String
    var showComingSoon: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.clipCookTextPrimary)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundColor(.clipCookTextPrimary)
            
            Spacer()
            
            if showComingSoon {
                Text("Coming Soon")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.clipCookTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.clipCookSurface)
                    .cornerRadius(12)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.clipCookTextSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView()
}

// MARK: - Legal Content
extension ProfileView {
    static let privacyPolicyContent = """
    # Privacy Policy
    
    Last Updated: January 1, 2026
    
    ## 1. Introduction
    ClipCook ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how your personal information is collected, used, and disclosed by ClipCook.
    
    ## 2. Information We Collect
    We collect information you provide directly to us, such as when you create an account, save recipes, or contact us for support. This includes your email address and any recipe data you generate.
    
    ## 3. How We Use Your Information
    We use the information we collect to operate, maintain, and improve our services, including generating recipes and providing personalized recommendations.
    
    ## 4. Contact Us
    If you have any questions about this Privacy Policy, please contact us at support@clipcook.com.
    """
    
    static let termsOfServiceContent = """
    # Terms of Service
    
    Last Updated: January 1, 2026
    
    ## 1. Acceptance of Terms
    By accessing or using our application, you agree to be bound by these Terms of Service.
    
    ## 2. Use of Service
    You agree to use ClipCook only for lawful purposes and in accordance with these Terms.
    
    ## 3. User Accounts
    You are responsible for safeguarding the password that you use to access the service and for any activities or actions under your password.
    
    ## 4. Changes to Terms
    We reserve the right to modify or replace these Terms at any time.
    """
}
