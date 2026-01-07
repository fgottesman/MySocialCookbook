
import Foundation

struct RemixRequest: Codable {
    let originalRecipe: Recipe
    let userPrompt: String
}

struct RemixedRecipe: Codable {
    let title: String?
    let description: String?
    let ingredients: [Ingredient]?
    let instructions: [String]?
    let chefsNote: String?
    let changedIngredients: [String]? // Names of changed/added ingredients
}

struct RemixResponse: Codable {
    let success: Bool
    let recipe: RemixedRecipe
}

class RemixService {
    static let shared = RemixService()
    
    private let backendUrl = "https://mysocialcookbook-production.up.railway.app/api/remix-recipe"
    
    func remixRecipe(originalRecipe: Recipe, prompt: String) async throws -> RemixedRecipe {
        guard let url = URL(string: backendUrl) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = RemixRequest(originalRecipe: originalRecipe, userPrompt: prompt)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(RemixResponse.self, from: data)
        return decodedResponse.recipe
    }
}
