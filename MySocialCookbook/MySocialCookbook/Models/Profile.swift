import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    let username: String?
    let fullName: String?
    let avatarUrl: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}
