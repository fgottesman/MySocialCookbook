
import Foundation

struct ChatCompanionRequest: Codable {
    let recipe: Recipe
    let currentStepIndex: Int
    let chatHistory: [ChatMessage]
    let userMessage: String
}

struct ChatMessage: Codable {
    let role: String // "user" or "ai"
    let content: String
}

struct ChatCompanionResponse: Codable {
    let success: Bool
    let reply: String
}

class VoiceCompanionService {
    static let shared = VoiceCompanionService()
    
    private let backendUrl = "https://mysocialcookbook-production.up.railway.app/api/chat-companion"
    
    func chat(recipe: Recipe, currentStepIndex: Int, history: [ChatMessage], message: String) async throws -> String {
        guard let url = URL(string: backendUrl) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ChatCompanionRequest(
            recipe: recipe,
            currentStepIndex: currentStepIndex,
            chatHistory: history,
            userMessage: message
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(ChatCompanionResponse.self, from: data)
        return decodedResponse.reply
    }
}
