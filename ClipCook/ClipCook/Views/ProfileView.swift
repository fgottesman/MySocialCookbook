import SwiftUI
import Supabase
import Auth

struct ProfileView: View {
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                if let profile = profile {
                    VStack(spacing: 8) {
                        Text(profile.fullName ?? "User")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if let username = profile.username {
                            Text("@\(username)")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                } else if isLoading {
                    ProgressView()
                } else {
                    Text("Could not load profile")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
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
