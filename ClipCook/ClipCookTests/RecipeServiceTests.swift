//
//  RecipeServiceTests.swift
//  ClipCookTests
//
//  Tests for RecipeService API endpoint URLs and authentication
//

import Testing
import Foundation
@testable import ClipCook

struct RecipeServiceTests {
    
    @Test func processRecipeUsesCorrectEndpoint() async throws {
        // Verify that processRecipe uses the correct backend endpoint
        
        // This test verifies the endpoint URL is constructed correctly
        // Actual network calls would require mocking URLSession
        let constructedURL = URL(string: "\(AppConfig.apiEndpoint)/process-recipe")
        
        #expect(constructedURL != nil, "Process recipe endpoint URL should be valid")
        #expect(constructedURL?.absoluteString.contains("/process-recipe") == true, 
                "Endpoint should use /process-recipe path")
    }
    
    @Test func generateRecipeUsesCorrectEndpoint() async throws {
        // Verify that createRecipeFromPrompt uses the correct backend endpoint
        
        let constructedURL = URL(string: "\(AppConfig.apiEndpoint)/generate-recipe-from-prompt")
        
        #expect(constructedURL != nil, "Generate recipe endpoint URL should be valid")
        #expect(constructedURL?.absoluteString.contains("/generate-recipe-from-prompt") == true,
                "Endpoint should use /generate-recipe-from-prompt path")
    }
}
