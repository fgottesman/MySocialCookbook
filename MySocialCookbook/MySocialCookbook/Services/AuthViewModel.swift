import Foundation
import Supabase
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
    
    func signOut() async {
        do {
            try await SupabaseManager.shared.client.auth.signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}
