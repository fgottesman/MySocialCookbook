import SwiftUI
import Supabase
import Auth

struct ProfileView: View {
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Header Section
                Section {
                    HStack(spacing: 16) {
                        // Avatar
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Text(profile?.fullName?.prefix(1).uppercased() ?? "?")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile?.fullName ?? "Loading...")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            if let username = profile?.username {
                                Text("@\(username)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // My Recipes Section
                Section("My Recipes") {
                    NavigationLink {
                        Text("Coming Soon")
                            .foregroundColor(.secondary)
                    } label: {
                        Label("Saved Recipes", systemImage: "bookmark.fill")
                    }
                    
                    NavigationLink {
                        Text("Coming Soon")
                            .foregroundColor(.secondary)
                    } label: {
                        Label("My Uploads", systemImage: "square.and.arrow.up.fill")
                    }
                }
                
                // Account Section
                Section("Account") {
                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
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
                await fetchProfile()
            }
        }
    }
    
    private func fetchProfile() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id
            
            let fetchedProfile: Profile = try await SupabaseManager.shared.client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.profile = fetchedProfile
                self.isLoading = false
            }
        } catch {
            print("Error fetching profile: \(error)")
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

#Preview {
    ProfileView()
}
