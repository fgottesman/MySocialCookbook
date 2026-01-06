import Foundation

struct Recipe: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let title: String
    let description: String?
    let videoUrl: String?
    let thumbnailUrl: String? // Added for Feed Thumbnail
    let ingredients: [Ingredient]?
    let instructions: [String]?
    let createdAt: Date
    let chefsNote: String? // Added for Remix feature
    let profile: Profile?  // Optional - may not be present
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case videoUrl = "video_url"
        case thumbnailUrl = "thumbnail_url"
        case ingredients
        case instructions
        case createdAt = "created_at"
        case chefsNote = "chefs_note"
        case profile = "profiles"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        videoUrl = try container.decodeIfPresent(String.self, forKey: .videoUrl)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        ingredients = try container.decodeIfPresent([Ingredient].self, forKey: .ingredients)
        instructions = try container.decodeIfPresent([String].self, forKey: .instructions)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        chefsNote = try container.decodeIfPresent(String.self, forKey: .chefsNote)
        profile = try container.decodeIfPresent(Profile.self, forKey: .profile)
    }
}

struct Ingredient: Codable, Hashable {
    let name: String
    let amount: String
    let unit: String
}
