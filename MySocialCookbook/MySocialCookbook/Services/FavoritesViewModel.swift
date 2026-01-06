import Foundation
import Combine

@MainActor
class FavoritesViewModel: ObservableObject {
    @Published var favorites: [Recipe] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchFavorites() async {
        isLoading = true
        errorMessage = nil
        
        do {
            favorites = try await RecipeService.shared.fetchFavorites()
            print("Fetched \(favorites.count) favorite recipes")
        } catch {
            print("Error fetching favorites: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func toggleFavorite(recipe: Recipe) async {
        do {
            try await RecipeService.shared.toggleFavorite(
                recipeId: recipe.id,
                isFavorite: false
            )
            // Refresh the list after unfavoriting
            await fetchFavorites()
        } catch {
            print("Error toggling favorite: \(error)")
            errorMessage = "Failed to remove from favorites"
        }
    }
}
