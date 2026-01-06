
import SwiftUI

// MARK: - Colors
extension Color {
    static let clipCookBackground = Color(hex: "1D1D1D")
    static let clipCookSurface = Color(hex: "2C2C2E")
    static let clipCookTextPrimary = Color.white
    static let clipCookTextSecondary = Color(hex: "8E8E93")
    
    // The "Sizzle" Gradient Colors
    static let clipCookSizzleStart = Color(hex: "FF512F") // Sunset Orange
    static let clipCookSizzleEnd = Color(hex: "DD2476")   // Hot Pink
    
    // Utility Colors
    static let clipCookSuccess = Color(hex: "4CD964")
}

// MARK: - Gradients
extension LinearGradient {
    static let sizzle = LinearGradient(
        gradient: Gradient(colors: [.clipCookSizzleStart, .clipCookSizzleEnd]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let magicalSizzle = LinearGradient(
        gradient: Gradient(colors: [.clipCookSizzleStart, .clipCookSizzleEnd, .clipCookSizzleStart]),
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Animations
extension Animation {
    static let whimsySpring = Animation.spring(response: 0.35, dampingFraction: 0.6, blendDuration: 0)
    static let slowWhimsy = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
}

// MARK: - Typography Modifiers
struct UtilityHeadline: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(.clipCookTextPrimary)
    }
}

struct UtilitySubhead: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .medium, design: .default))
            .foregroundColor(.clipCookTextSecondary)
    }
}

// MARK: - Helper for Hex Colors
extension Color {
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
            (a, r, g, b) = (1, 1, 1, 0)
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
