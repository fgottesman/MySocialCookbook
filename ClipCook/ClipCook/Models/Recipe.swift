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
    let isFavorite: Bool?  // Added for Favorites feature
    
    let parentRecipeId: UUID? // Added for Remix attribution
    let sourcePrompt: String? // Added for AI recipe attribution
    let stepPreparations: [StepPreparation]? // Pre-computed step preparations for cooking mode
    
    let step0Summary: String? // Step 0 Summary text
    let step0AudioUrl: String? // URL to Step 0 Audio
    var localStep0AudioUrl: URL? // Local path to downloaded audio (transient)
    
    let cookingTime: String? // Added for AI metrics
    
    // Transient property to track which version this recipe represents
    var versionId: UUID? = nil
    
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
        case isFavorite = "is_favorite"
        case parentRecipeId = "parent_recipe_id"
        case sourcePrompt = "source_prompt"
        case stepPreparations = "step_preparations"
        case step0Summary = "step0_summary"
        case step0AudioUrl = "step0_audio_url"
        case difficulty
        case cookingTime = "cooking_time"
    }
    
    init(id: UUID, userId: UUID, title: String, description: String?, videoUrl: String?, thumbnailUrl: String?, ingredients: [Ingredient]?, instructions: [String]?, createdAt: Date, chefsNote: String?, profile: Profile?, isFavorite: Bool?, parentRecipeId: UUID? = nil, sourcePrompt: String? = nil, stepPreparations: [StepPreparation]? = nil, step0Summary: String? = nil, step0AudioUrl: String? = nil, difficulty: String? = nil, cookingTime: String? = nil, versionId: UUID? = nil) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.ingredients = ingredients
        self.instructions = instructions
        self.createdAt = createdAt
        self.chefsNote = chefsNote
        self.profile = profile
        self.isFavorite = isFavorite
        self.parentRecipeId = parentRecipeId
        self.sourcePrompt = sourcePrompt
        self.stepPreparations = stepPreparations
        self.step0Summary = step0Summary
        self.step0AudioUrl = step0AudioUrl
        self.difficulty = difficulty
        self.cookingTime = cookingTime
        self.versionId = versionId
    }
}

extension Recipe {
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
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite)
        parentRecipeId = try container.decodeIfPresent(UUID.self, forKey: .parentRecipeId)
        sourcePrompt = try container.decodeIfPresent(String.self, forKey: .sourcePrompt)
        stepPreparations = try container.decodeIfPresent([StepPreparation].self, forKey: .stepPreparations)
        step0Summary = try container.decodeIfPresent(String.self, forKey: .step0Summary)
        step0AudioUrl = try container.decodeIfPresent(String.self, forKey: .step0AudioUrl)
        difficulty = try container.decodeIfPresent(String.self, forKey: .difficulty)
        cookingTime = try container.decodeIfPresent(String.self, forKey: .cookingTime)
    }
    
    // Manual encoder to support updates/remixes if needed
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(videoUrl, forKey: .videoUrl)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encodeIfPresent(ingredients, forKey: .ingredients)
        try container.encodeIfPresent(instructions, forKey: .instructions)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(chefsNote, forKey: .chefsNote)
        try container.encodeIfPresent(profile, forKey: .profile)
        try container.encodeIfPresent(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(parentRecipeId, forKey: .parentRecipeId)
        try container.encodeIfPresent(sourcePrompt, forKey: .sourcePrompt)
        try container.encodeIfPresent(stepPreparations, forKey: .stepPreparations)
        try container.encodeIfPresent(step0Summary, forKey: .step0Summary)
        try container.encodeIfPresent(step0AudioUrl, forKey: .step0AudioUrl)
        try container.encodeIfPresent(difficulty, forKey: .difficulty)
        try container.encodeIfPresent(cookingTime, forKey: .cookingTime)
    }
}

struct Ingredient: Codable, Hashable {
    let name: String
    let amount: String
    let unit: String
}

extension Recipe {
    var isAIRecipe: Bool {
        videoUrl == nil
    }

    var sourcePlatform: String {
        guard let videoUrl = videoUrl?.lowercased() else { return "ClipCook" }
        if videoUrl.contains("tiktok") { return "TikTok" }
        if videoUrl.contains("instagram") { return "Instagram" }
        if videoUrl.contains("youtube") || videoUrl.contains("youtu.be") { return "YouTube" }
        if videoUrl.contains("pinterest") { return "Pinterest" }
        return "Video"
    }
}
