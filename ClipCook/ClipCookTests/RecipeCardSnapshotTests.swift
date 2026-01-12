//
//  RecipeCardSnapshotTests.swift
//  ClipCookTests
//
//  Snapshot tests for the RecipeCard component
//  These tests catch visual regressions in the feed card appearance
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import ClipCook

/// Tests for RecipeCard visual appearance
/// 
/// Run tests once with `isRecording = true` to generate baseline snapshots.
/// Subsequent runs will compare against baselines.
final class RecipeCardSnapshotTests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        // Uncomment to record new snapshots when intentionally changing UI
        // isRecording = true
    }
    
    // MARK: - iPhone Snapshots
    
    /// Test RecipeCard appearance on iPhone
    func testRecipeCard_iPhone() throws {
        let recipe = MockData.mockRecipe()
        let view = RecipeCard(recipe: recipe)
            .frame(width: 180)
            .snapshotContainer()
        
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 180, height: 280))
        )
    }
    
    /// Test RecipeCard with favorite badge
    func testRecipeCard_Favorite() throws {
        let recipe = MockData.mockRecipe(isFavorite: true)
        let view = RecipeCard(recipe: recipe)
            .frame(width: 180)
            .snapshotContainer()
        
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 180, height: 280))
        )
    }
    
    /// Test AI-generated recipe card (no video thumbnail)
    func testRecipeCard_AIRecipe() throws {
        let recipe = MockData.mockAIRecipe()
        let view = RecipeCard(recipe: recipe)
            .frame(width: 180)
            .snapshotContainer()
        
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 180, height: 280))
        )
    }
    
    /// Test RecipeCard with long title (text truncation)
    func testRecipeCard_LongTitle() throws {
        let recipe = MockData.mockRecipe(
            title: "Super Delicious Homemade Chocolate Chip Cookies with Extra Marshmallows"
        )
        let view = RecipeCard(recipe: recipe)
            .frame(width: 180)
            .snapshotContainer()
        
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 180, height: 280))
        )
    }
    
    // MARK: - iPad Snapshots
    
    /// Test RecipeCard appearance on iPad (larger cards)
    func testRecipeCard_iPad() throws {
        let recipe = MockData.mockRecipe()
        let view = RecipeCard(recipe: recipe)
            .frame(width: 250)
            .snapshotContainer()
        
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 250, height: 380))
        )
    }
}
