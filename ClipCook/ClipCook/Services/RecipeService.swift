import Foundation
import Supabase

class RecipeService {
    static let shared = RecipeService()
    private init() {}
    
    private let backendBaseUrl = "https://mysocialcookbook-production.up.railway.app/api"
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    // Toggle favorite
    var isProcessingRecipe: Bool {
        get {
            UserDefaults.standard.bool(forKey: "isProcessingRecipe")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "isProcessingRecipe")
        }
    }
    
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
    
    // Process recipe from URL
    func processRecipe(url: String, userId: String) async throws {
        isProcessingRecipe = true
        guard let endpoint = URL(string: "\(backendBaseUrl)/process-recipe") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["url": url, "userId": userId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    // Create recipe from prompt
    func createRecipeFromPrompt(prompt: String, userId: String) async throws -> Recipe {
        guard let endpoint = URL(string: "\(backendBaseUrl)/generate-recipe-from-prompt") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["prompt": prompt, "userId": userId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        struct BackendResponse: Codable {
            let success: Bool
            let recipe: Recipe
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedResponse = try decoder.decode(BackendResponse.self, from: data)
        return decodedResponse.recipe
    }

    // Save Remixed Recipe
    func saveRemixedRecipe(_ recipe: Recipe, originalId: UUID) async throws -> Recipe {
        let newId = UUID()
        
        struct RecipeInsert: Encodable {
            let id: UUID
            let user_id: UUID
            let title: String
            let description: String?
            let video_url: String?
            let thumbnail_url: String?
            let ingredients: [Ingredient]?
            let instructions: [String]?
            let chefs_note: String?
            let is_favorite: Bool
            let parent_recipe_id: UUID?
            let step0_summary: String?
            let step0_audio_url: String?
        }
        
        let insertPayload = RecipeInsert(
            id: newId,
            user_id: recipe.userId,
            title: recipe.title,
            description: recipe.description,
            video_url: recipe.videoUrl,
            thumbnail_url: recipe.thumbnailUrl,
            ingredients: recipe.ingredients,
            instructions: recipe.instructions,
            chefs_note: recipe.chefsNote,
            is_favorite: false, // Reset favorite for new recipe
            parent_recipe_id: originalId,
            step0_summary: recipe.step0Summary,
            step0_audio_url: recipe.step0AudioUrl
        )
        
        try await client
            .from("recipes")
            .insert(insertPayload)
            .execute()
            
        // Return the new recipe with correct ID and parent attribution
        return Recipe(
            id: newId,
            userId: recipe.userId,
            title: recipe.title,
            description: recipe.description,
            videoUrl: recipe.videoUrl,
            thumbnailUrl: recipe.thumbnailUrl,
            ingredients: recipe.ingredients,
            instructions: recipe.instructions,
            createdAt: Date(), // Will be set by DB default mostly, but useful for local return
            chefsNote: recipe.chefsNote,
            profile: recipe.profile,
            isFavorite: false,
            parentRecipeId: originalId,
            step0Summary: recipe.step0Summary,
            step0AudioUrl: recipe.step0AudioUrl
        )
    }
}

