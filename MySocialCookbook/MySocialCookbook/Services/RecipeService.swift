import Foundation
import Supabase

class RecipeService {
    static let shared = RecipeService()
    private init() {}
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    // Toggle favorite
    func toggleFavorite(recipeId: UUID, isFavorite: Bool) async throws {
        struct UpdatePayload: Encodable {
            let is_favorite: Bool
        }
        
        try await client
            .from("recipes")
            .update(UpdatePayload(is_favorite: isFavorite))
            .eq("id", value: recipeId.uuidString)
            .execute()
    }
    
    // Fetch all recipes
    func fetchRecipes() async throws -> [Recipe] {
        try await client
            .from("recipes")
            .select("*")
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    // Fetch favorites
    func fetchFavorites() async throws -> [Recipe] {
        try await client
            .from("recipes")
            .select("*")
            .eq("is_favorite", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    // Search recipes (client-side for now, can be server-side later)
    func searchRecipes(query: String) async throws -> [Recipe] {
        let allRecipes = try await fetchRecipes()
        let lowercaseQuery = query.lowercased()
        return allRecipes.filter { recipe in
            recipe.title.lowercased().contains(lowercaseQuery) ||
            (recipe.description?.lowercased().contains(lowercaseQuery) ?? false)
        }
    }
    
    // Delete recipe
    func deleteRecipe(recipeId: UUID) async throws {
        try await client
            .from("recipes")
            .delete()
            .eq("id", value: recipeId.uuidString)
            .execute()
    }
}

