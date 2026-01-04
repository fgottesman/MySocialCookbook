import Foundation

struct Recipe: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let title: String
    let description: String?
    let videoUrl: String?
    let ingredients: [Ingredient]?
    let instructions: [String]?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case videoUrl = "video_url"
        case ingredients
        case instructions
        case createdAt = "created_at"
    }
}

struct Ingredient: Codable, Hashable {
    let name: String
    let amount: String
    let unit: String
}
