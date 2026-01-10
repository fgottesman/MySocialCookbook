
import Foundation

// MARK: - Chat Companion Models
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

// MARK: - Step Preparation Models
struct PrepareStepRequest: Codable {
    let recipe: Recipe
    let stepIndex: Int
    let stepLabel: String
}

struct PrepareStepResponse: Codable {
    let success: Bool
    let preparation: StepPreparation
}

struct StepPreparation: Codable {
    let introduction: String
    let subSteps: [SubStep]?
    let conversions: [MeasurementConversion]?
}

struct SubStep: Codable, Identifiable {
    let label: String
    let text: String
    
    var id: String { label }
}

struct MeasurementConversion: Codable, Identifiable {
    let original: String
    let metric: String
    let imperial: String
    let spoken: String
    
    var id: String { original }
}

// MARK: - User Preferences Models
struct UserPreferences: Codable {
    let userId: String?
    var unitSystem: String // "metric" or "imperial"
    var prepStyle: String // "just_in_time" or "prep_first"
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case unitSystem = "unit_system"
        case prepStyle = "prep_style"
    }
    
    static let `default` = UserPreferences(userId: nil, unitSystem: "imperial", prepStyle: "just_in_time")
}

struct UserPreferencesResponse: Codable {
    let success: Bool
    let preferences: UserPreferences
}

// MARK: - Voice Companion Service
class VoiceCompanionService {
    static let shared = VoiceCompanionService()
    
    private let baseUrl = AppConfig.apiEndpoint
    
    // MARK: - Chat Companion
    func chat(recipe: Recipe, currentStepIndex: Int, history: [ChatMessage], message: String) async throws -> String {
        guard let url = URL(string: "\(baseUrl)/ai/chat-companion") else {
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
    
    // MARK: - Prepare Step (new)
    func prepareStep(recipe: Recipe, stepIndex: Int, stepLabel: String) async throws -> StepPreparation {
        guard let url = URL(string: "\(baseUrl)/ai/prepare-step") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = PrepareStepRequest(
            recipe: recipe,
            stepIndex: stepIndex,
            stepLabel: stepLabel
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(PrepareStepResponse.self, from: data)
        return decodedResponse.preparation
    }
    
    // MARK: - User Preferences
    func getPreferences(userId: String) async throws -> UserPreferences {
        guard let url = URL(string: "\(baseUrl)/users/preferences/\(userId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return UserPreferences.default
        }
        
        let decodedResponse = try JSONDecoder().decode(UserPreferencesResponse.self, from: data)
        return decodedResponse.preferences
    }
    
    func updatePreferences(userId: String, preferences: UserPreferences) async throws -> UserPreferences {
        guard let url = URL(string: "\(baseUrl)/users/preferences/\(userId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONEncoder().encode(preferences)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(UserPreferencesResponse.self, from: data)
        return decodedResponse.preferences
    }
}
