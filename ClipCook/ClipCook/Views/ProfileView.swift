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
            VStack(spacing: 0) {
                // User Info Section
                VStack(spacing: 12) {
                    // Profile Icon
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    // Email
                    if let email = userEmail {
                        Text(email)
                            .font(.headline)
                            .foregroundColor(.primary)
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
                    MenuRow(
                        icon: "lock.shield",
                        title: "Data Privacy",
                        showComingSoon: true
                    )
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    // Terms of Service
                    MenuRow(
                        icon: "doc.text",
                        title: "Terms of Service",
                        showComingSoon: true
                    )
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
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
            .frame(maxWidth: .infinity)
            .navigationTitle("Profile")
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
                .foregroundColor(.primary)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            if showComingSoon {
                Text("Coming Soon")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView()
}
