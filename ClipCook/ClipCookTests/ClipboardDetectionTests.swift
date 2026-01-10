//
//  ClipboardDetectionTests.swift
//  ClipCookTests
//
//  Tests for clipboard URL detection logic
//

import Testing
import Foundation
import UIKit

struct ClipboardDetectionTests {
    
    // Helper function to simulate clipboard detection logic
    // This mirrors the logic in AddRecipeView.checkClipboardForURL()
    func shouldAutoFillURL(_ urlString: String?) -> Bool {
        guard let clipboardString = urlString else { return false }
        
        // Check if it's a valid URL
        guard let url = URL(string: clipboardString),
              url.scheme == "http" || url.scheme == "https" else {
            return false
        }
        
        // Check if it's from a supported platform
        let supportedDomains = ["tiktok.com", "instagram.com", "youtube.com", "youtu.be", "pinterest.com"]
        let host = url.host?.lowercased() ?? ""
        
        return supportedDomains.contains { domain in
            host.contains(domain)
        }
    }
    
    @Test func clipboardDetection_ValidTikTokURL() {
        let url = "https://www.tiktok.com/@chef/video/12345"
        let result = shouldAutoFillURL(url)
        #expect(result == true, "Should auto-fill valid TikTok URL")
    }
    
    @Test func clipboardDetection_ValidInstagramURL() {
        let url = "https://www.instagram.com/reel/ABC123/"
        let result = shouldAutoFillURL(url)
        #expect(result == true, "Should auto-fill valid Instagram URL")
    }
    
    @Test func clipboardDetection_ValidYouTubeURL() {
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        let result = shouldAutoFillURL(url)
        #expect(result == true, "Should auto-fill valid YouTube URL")
    }
    
    @Test func clipboardDetection_ValidYouTuBeShortURL() {
        let url = "https://youtu.be/dQw4w9WgXcQ"
        let result = shouldAutoFillURL(url)
        #expect(result == true, "Should auto-fill valid youtu.be short URL")
    }
    
    @Test func clipboardDetection_ValidPinterestURL() {
        let url = "https://www.pinterest.com/pin/123456789/"
        let result = shouldAutoFillURL(url)
        #expect(result == true, "Should auto-fill valid Pinterest URL")
    }
    
    @Test func clipboardDetection_InvalidURL() {
        let url = "not a valid url"
        let result = shouldAutoFillURL(url)
        #expect(result == false, "Should not auto-fill invalid URL")
    }
    
    @Test func clipboardDetection_UnsupportedDomain() {
        let url = "https://www.example.com/recipe"
        let result = shouldAutoFillURL(url)
        #expect(result == false, "Should not auto-fill unsupported domain")
    }
    
    @Test func clipboardDetection_NonHTTPScheme() {
        let url = "ftp://tiktok.com/video"
        let result = shouldAutoFillURL(url)
        #expect(result == false, "Should not auto-fill non-HTTP(S) URL")
    }
    
    @Test func clipboardDetection_EmptyString() {
        let url = ""
        let result = shouldAutoFillURL(url)
        #expect(result == false, "Should not auto-fill empty string")
    }
    
    @Test func clipboardDetection_NilString() {
        let result = shouldAutoFillURL(nil)
        #expect(result == false, "Should not crash on nil clipboard")
    }
    
    @Test func clipboardDetection_PlainText() {
        let url = "Check out this recipe!"
        let result = shouldAutoFillURL(url)
        #expect(result == false, "Should not auto-fill plain text")
    }
}
