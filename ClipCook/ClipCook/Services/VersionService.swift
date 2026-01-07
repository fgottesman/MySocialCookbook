import Foundation

/// Service for managing recipe version persistence
class VersionService {
    static let shared = VersionService()
    private init() {}
    
    private let backendBaseUrl = "https://mysocialcookbook-production.up.railway.app/api"
    
    /// Fetch all saved versions for a recipe
    func fetchVersions(for recipeId: UUID) async throws -> [SavedRecipeVersion] {
        guard let url = URL(string: "\(backendBaseUrl)/recipes/\(recipeId.uuidString)/versions") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(VersionsResponse.self, from: data)
        return result.versions
    }
    
    /// Save a new version for a recipe
    func saveVersion(for recipeId: UUID, version: RecipeVersion) async throws -> SavedRecipeVersion {
        guard let url = URL(string: "\(backendBaseUrl)/recipes/\(recipeId.uuidString)/versions") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = SaveVersionRequest(
            title: version.title,
            description: version.recipe.description,
            ingredients: version.recipe.ingredients,
            instructions: version.recipe.instructions,
            chefsNote: version.recipe.chefsNote,
            changedIngredients: Array(version.changedIngredients)
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(SaveVersionResponse.self, from: data)
        return result.version
    }
}

// MARK: - API Types

struct VersionsResponse: Codable {
    let success: Bool
    let versions: [SavedRecipeVersion]
}

struct SaveVersionRequest: Codable {
    let title: String
    let description: String?
    let ingredients: [Ingredient]?
    let instructions: [String]?
    let chefsNote: String?
    let changedIngredients: [String]
}

struct SaveVersionResponse: Codable {
    let success: Bool
    let version: SavedRecipeVersion
}

struct SavedRecipeVersion: Codable, Identifiable {
    let id: UUID
    let recipeId: UUID
    let versionNumber: Int
    let title: String
    let description: String?
    let ingredients: [Ingredient]?
    let instructions: [String]?
    let chefsNote: String?
    let changedIngredients: [String]?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case recipeId = "recipe_id"
        case versionNumber = "version_number"
        case title
        case description
        case ingredients
        case instructions
        case chefsNote = "chefs_note"
        case changedIngredients = "changed_ingredients"
        case createdAt = "created_at"
    }
}
