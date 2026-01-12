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
    @Published var toastMessage: String?
    
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
    
    func fetchRecipes(isUserInitiated: Bool = false) async {
        isLoading = true
        // Don't clear recipes or errorMessage immediately to avoid flicker
        
        do {
            let client = SupabaseManager.shared.client
            let previousCount = recipes.count
            
            // Fetch recipes with profile join for creator attribution
            let newRecipes: [Recipe] = try await client
                .from("recipes")
                .select("*, profiles:user_id(id, username, full_name, avatar_url, created_at)")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            self.recipes = newRecipes
            
            // If we found new recipes, assume background processing is done
            if newRecipes.count > previousCount {
                RecipeService.shared.isProcessingRecipe = false
            } else if isUserInitiated {
                if RecipeService.shared.isProcessingRecipe {
                    toastMessage = "Your recipe is still cooking in the background..."
                } else {
                     toastMessage = "Nothing new right now."
                }
            }
            
            errorMessage = nil
            print("Fetched \(newRecipes.count) recipes")
        } catch {
            print("Error fetching recipes: \(error)")
            
            // Logic for user feedback on error/refresh
            if isUserInitiated {
                if RecipeService.shared.isProcessingRecipe {
                    toastMessage = "Your recipe is still cooking in the background..."
                } else {
                     toastMessage = "Nothing new right now."
                }
            }
            
            // Only show full screen error if we have no recipes to show
            if recipes.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
        
        isLoading = false
    }
}
