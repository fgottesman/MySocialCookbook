
import Foundation
import Supabase
import Auth

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
    
    // Add missing step0 properties
    let step0Summary: String?
    let step0AudioUrl: String?
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
        
        // Add Auth
        if let session = try? await SupabaseManager.shared.client.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        
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
        
        // Add Auth
        if let session = try? await SupabaseManager.shared.client.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        print("🧑‍🍳 [RemixService] Sending consult request to: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🧑‍🍳 [RemixService] ❌ Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            print("🧑‍🍳 [RemixService] Response Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
                print("🧑‍🍳 [RemixService] ❌ Server Error Body: \(errorBody)")
                throw URLError(.badServerResponse)
            }
            
            let decodedResponse = try JSONDecoder().decode(RemixConsultResponse.self, from: data)
            return decodedResponse.consultation
        } catch {
            print("🧑‍🍳 [RemixService] ❌ Network/Decoding Error: \(error)")
            throw error
        }
    }
}
