//
//  DesignExtensions.swift
//  ShareRecipe
//
//  Design system for Share Extension (standalone, mirrors main app DesignTokens)
//  Note: Share extensions cannot import from main app, so colors are defined here
//  with matching values from DesignTokens.swift
//

import SwiftUI

// MARK: - Color Extensions
extension Color {
    // Core Colors (matching DesignTokens.Colors)
    static var clipCookBackground: Color { Color(hex: "0F1A2B") }      // Midnight Navy
    static var clipCookSurface: Color { Color(hex: "1A2A3D") }         // Deep Navy
    static var clipCookTextPrimary: Color { .white }
    static var clipCookTextSecondary: Color { Color(hex: "D4A5A5") }   // Dusty Rose
    static var clipCookPrimary: Color { Color(hex: "E8C4B8") }         // Rose Gold
    static var clipCookSecondary: Color { Color(hex: "D4A5A5") }       // Dusty Rose

    // Sizzle gradient colors (warm accent for cooking app)
    static var clipCookSizzleStart: Color { Color(hex: "FF6B4A") }     // Coral
    static var clipCookSizzleEnd: Color { Color(hex: "FF8E53") }       // Light Orange

    static var clipCookSuccess: Color { Color(hex: "4CAF50") }         // Green

    // Hex color initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Design Tokens (matching main app DesignTokens struct)
enum DesignTokens {
    enum Layout {
        // Spacing scale
        static let spacing8: CGFloat = 8
        static let spacing12: CGFloat = 12
        static let spacing16: CGFloat = 16
        static let spacing20: CGFloat = 20
        static let spacing24: CGFloat = 24

        // Corner radii hierarchy
        static let cornerRadiusSmall: CGFloat = 8     // badges, chips
        static let cornerRadiusMedium: CGFloat = 12   // inputs, thumbnails
        static let cornerRadius: CGFloat = 20         // cards (default)
        static let cornerRadiusLarge: CGFloat = 20    // alias for clarity
        static let cornerRadiusPill: CGFloat = 999    // pills, rounded buttons

        // Grid
        static let gridSpacing: CGFloat = 16
        static let cardPadding: CGFloat = 12
    }

    enum Effects {
        // Shadow hierarchy
        static let shadowSmallRadius: CGFloat = 4
        static let shadowSmallY: CGFloat = 2
        static let shadowMediumRadius: CGFloat = 10
        static let shadowMediumY: CGFloat = 4
        static let shadowLargeRadius: CGFloat = 20
        static let shadowLargeY: CGFloat = 8

        // Standardized shadow colors
        static let shadowColor = Color.black.opacity(0.15)
        static let shadowColorStrong = Color.black.opacity(0.3)
    }
}

// MARK: - LinearGradient Extensions
extension LinearGradient {
    /// Rose gold gradient - primary brand accent (matches app icon)
    /// Use for: navigation titles, toolbar icons, primary CTAs
    static var roseGold: LinearGradient {
        LinearGradient(
            colors: [.clipCookPrimary, .clipCookSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Sizzle gradient - warm coral/orange accent
    /// Use for: loading states, AI features, "cooking" animations, processing indicators
    static var sizzle: LinearGradient {
        LinearGradient(
            colors: [.clipCookSizzleStart, .clipCookSizzleEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
