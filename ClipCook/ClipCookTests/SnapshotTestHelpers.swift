//
//  SnapshotTestHelpers.swift
//  ClipCookTests
//
//  Helpers for snapshot testing with swift-snapshot-testing
//

import XCTest
import SwiftUI
@testable import ClipCook

// MARK: - Mock Data for Snapshot Tests

enum MockData {
    /// Creates a mock Recipe for snapshot testing
    static func mockRecipe(
        title: String = "Spicy Garlic Butter Pasta",
        description: String? = "A quick and delicious pasta dish with a kick of spice and rich garlic butter sauce.",
        thumbnailUrl: String? = nil,
        isFavorite: Bool = false,
        difficulty: String? = "Easy",
        cookingTime: String? = "25 mins",
        chefsNote: String? = nil
    ) -> Recipe {
        Recipe(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: title,
            description: description,
            videoUrl: "https://example.com/video.mp4",
            thumbnailUrl: thumbnailUrl,
            ingredients: [
                Ingredient(name: "Pasta", amount: "400", unit: "g"),
                Ingredient(name: "Garlic", amount: "4", unit: "cloves"),
                Ingredient(name: "Butter", amount: "100", unit: "g"),
                Ingredient(name: "Red Pepper Flakes", amount: "1", unit: "tsp"),
                Ingredient(name: "Parmesan", amount: "50", unit: "g"),
                Ingredient(name: "Fresh Parsley", amount: "2", unit: "tbsp")
            ],
            instructions: [
                "Boil pasta according to package directions until al dente.",
                "Mince garlic finely and set aside.",
                "Melt butter in a large pan over medium heat.",
                "Add garlic and red pepper flakes, cook for 1-2 minutes until fragrant.",
                "Drain pasta, reserving 1/2 cup pasta water.",
                "Toss pasta with garlic butter, adding pasta water as needed.",
                "Top with grated parmesan and fresh parsley.",
                "Serve immediately while hot."
            ],
            createdAt: Date(timeIntervalSince1970: 1704067200), // Jan 1, 2024
            chefsNote: chefsNote,
            profile: nil,
            isFavorite: isFavorite,
            parentRecipeId: nil,
            sourcePrompt: nil,
            stepPreparations: nil,
            step0Summary: nil,
            step0AudioUrl: nil,
            difficulty: difficulty,
            cookingTime: cookingTime
        )
    }
    
    /// Creates a mock AI-generated Recipe (no video)
    static func mockAIRecipe() -> Recipe {
        Recipe(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Homemade Chocolate Lava Cake",
            description: "Decadent chocolate cake with a molten center that oozes when you cut into it.",
            videoUrl: nil, // AI recipe - no video
            thumbnailUrl: nil,
            ingredients: [
                Ingredient(name: "Dark Chocolate", amount: "200", unit: "g"),
                Ingredient(name: "Butter", amount: "100", unit: "g"),
                Ingredient(name: "Eggs", amount: "3", unit: ""),
                Ingredient(name: "Sugar", amount: "80", unit: "g"),
                Ingredient(name: "Flour", amount: "30", unit: "g")
            ],
            instructions: [
                "Preheat oven to 425°F (220°C).",
                "Melt chocolate and butter together.",
                "Whisk eggs and sugar until fluffy.",
                "Fold chocolate mixture into eggs.",
                "Add flour and mix gently.",
                "Pour into greased ramekins.",
                "Bake for 12-14 minutes.",
                "Invert onto plates and serve immediately."
            ],
            createdAt: Date(timeIntervalSince1970: 1704153600),
            chefsNote: nil,
            profile: nil,
            isFavorite: true,
            parentRecipeId: nil,
            sourcePrompt: "Make me a chocolate lava cake recipe",
            stepPreparations: nil,
            step0Summary: nil,
            step0AudioUrl: nil,
            difficulty: "Medium",
            cookingTime: "30 mins"
        )
    }
    
    /// Creates multiple recipes for feed testing
    static func mockRecipeList() -> [Recipe] {
        [
            mockRecipe(title: "Spicy Garlic Butter Pasta", difficulty: "Easy", cookingTime: "25 mins"),
            mockAIRecipe(),
            mockRecipe(title: "Crispy Honey Garlic Chicken", isFavorite: true, difficulty: "Medium", cookingTime: "45 mins"),
            mockRecipe(title: "Fresh Avocado Toast", difficulty: "Easy", cookingTime: "10 mins"),
            mockRecipe(title: "Thai Basil Fried Rice", difficulty: "Medium", cookingTime: "20 mins"),
            mockRecipe(title: "Classic Beef Tacos", difficulty: "Easy", cookingTime: "30 mins")
        ]
    }
}

// MARK: - View Snapshot Helpers

extension View {
    /// Wraps a view for snapshot testing with consistent styling
    func snapshotContainer() -> some View {
        self
            .preferredColorScheme(.dark) // ClipCook uses dark mode
    }
}
