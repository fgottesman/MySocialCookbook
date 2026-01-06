import Foundation
import Supabase
import SwiftUI
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    
    var filteredRecipes: [Recipe] {
        if searchQuery.isEmpty {
            return recipes
        } else {
            let lowercaseQuery = searchQuery.lowercased()
            return recipes.filter { recipe in
                recipe.title.lowercased().contains(lowercaseQuery) ||
                (recipe.description?.lowercased().contains(lowercaseQuery) ?? false)
            }
        }
    }
    
    func fetchRecipes() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let client = SupabaseManager.shared.client
            
            // Fetch recipes without profile join for now
            // (Profile join fails if user_id doesn't exist in profiles table)
            let recipes: [Recipe] = try await client
                .from("recipes")
                .select("*")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            self.recipes = recipes
            print("Fetched \(recipes.count) recipes")
        } catch {
            print("Error fetching recipes: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
