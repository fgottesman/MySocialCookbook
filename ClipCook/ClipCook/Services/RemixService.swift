
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
    let difficulty: String?
    let cookingTime: String?
}

struct RemixResponse: Codable {
    let success: Bool
    let recipe: RemixedRecipe
}

class RemixService {
    static let shared = RemixService()
    
    private let backendUrl = "\(AppConfig.apiEndpoint)/ai/remix"
    
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
    
    // MARK: - Consultation Chat
    
    struct RemixConsultation: Codable {
        let reply: String
        let difficultyImpact: String
        let difficultyExplanation: String
        let qualityImpact: String
        let qualityExplanation: String
        let canProceed: Bool
    }
    
    struct RemixConsultResponse: Codable {
        let success: Bool
        let consultation: RemixConsultation
    }
    
    struct ChatMessage: Codable {
        let role: String // "user" or "assistant"
        let content: String
    }
    
    struct RemixChatRequest: Codable {
        let originalRecipe: Recipe
        let chatHistory: [ChatMessage]
        let userPrompt: String
    }
    
    func remixConsult(originalRecipe: Recipe, chatHistory: [ChatMessage], prompt: String) async throws -> RemixConsultation {
        guard let url = URL(string: "\(AppConfig.apiEndpoint)/ai/remix-chat") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = RemixChatRequest(originalRecipe: originalRecipe, chatHistory: chatHistory, userPrompt: prompt)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(RemixConsultResponse.self, from: data)
        return decodedResponse.consultation
    }
}
