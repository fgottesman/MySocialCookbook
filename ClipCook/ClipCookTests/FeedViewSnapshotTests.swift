//
//  FeedViewSnapshotTests.swift
//  ClipCookTests
//
//  Snapshot tests for the Feed view and its various states
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import ClipCook

/// Tests for FeedView visual appearance and states
///
/// Covers:
/// - Empty state (NUX view)
/// - Loading state
/// - Populated feed with recipes
final class FeedViewSnapshotTests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        // Uncomment to record new snapshots when intentionally changing UI
        // isRecording = true
    }
    
    // MARK: - Feed Grid
    
    /// Test feed grid with multiple recipes on iPhone
    func testFeedGrid_iPhone() throws {
        let recipes = MockData.mockRecipeList()
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        
        let view = ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(recipes) { recipe in
                    RecipeCard(recipe: recipe)
                }
            }
            .padding()
        }
        .background(DesignTokens.Colors.background)
        .preferredColorScheme(.dark)
        
        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: .iPhone13))
        )
    }
    
    /// Test feed grid on iPad (3 columns)
    func testFeedGrid_iPad() throws {
        let recipes = MockData.mockRecipeList()
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        
        let view = ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(recipes) { recipe in
                    RecipeCard(recipe: recipe)
                }
            }
            .padding()
        }
        .background(DesignTokens.Colors.background)
        .preferredColorScheme(.dark)
        
        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: .iPadPro12_9))
        )
    }
    
    // MARK: - Loading State
    
    /// Test loading indicator
    func testLoadingState() throws {
        let view = VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.primary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.background)
        .preferredColorScheme(.dark)
        
        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: .iPhone13))
        )
    }
}
