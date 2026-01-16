import SwiftUI
import UIKit

struct DesignTokens {
    // MARK: - Colors
    struct Colors {
        static let primary = Color(hex: "E8C4B8")             // Rose Gold
        static let secondary = Color(hex: "D4A5A5")           // Dusty Rose
        static let background = Color(hex: "0F1A2B")          // Midnight Navy
        static let surface = Color(hex: "1A2A3D")             // Deep Navy
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "D4A5A5")       // Dusty Rose
        
        static let gradientStart = Color(hex: "0F1A2B")       // Midnight Navy
        static let gradientEnd = Color(hex: "0A1220")         // Deeper Navy
    }

    
    // MARK: - Spacing & Grid
    struct Layout {
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
    
    // MARK: - Typography (Premium Vibes)
    struct Typography {
        static func headerFont(size: CGFloat = 24) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
        
        static func bodyFont(size: CGFloat = 16) -> Font {
            .system(size: size, weight: .medium, design: .default)
        }
        
        static func captionFont(size: CGFloat = 14) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }
    }
    
    // MARK: - Shadows & Effects
    struct Effects {
        // Shadow hierarchy
        static let shadowSmallRadius: CGFloat = 4
        static let shadowSmallY: CGFloat = 2
        static let shadowMediumRadius: CGFloat = 10
        static let shadowMediumY: CGFloat = 4
        static let shadowLargeRadius: CGFloat = 20
        static let shadowLargeY: CGFloat = 8

        // Legacy (keeping for backward compatibility)
        static let softShadowRadius: CGFloat = 15
        static let softShadowColor = Color.black.opacity(0.3)

        // Standardized shadow colors
        static let shadowColor = Color.black.opacity(0.15)
        static let shadowColorStrong = Color.black.opacity(0.3)
    }
}

// MARK: - View Extensions for "Zero Orphans"
extension View {
    func premiumText() -> some View {
        self.lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    func cardStyle() -> some View {
        self.padding(DesignTokens.Layout.cardPadding)
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.Layout.cornerRadius)
            .shadow(color: DesignTokens.Effects.softShadowColor, radius: DesignTokens.Effects.softShadowRadius)
    }
}

// MARK: - Premium Button Style
struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
            }
    }
}

// MARK: - Color Extensions (Convenience accessors wrapping DesignTokens)
extension Color {
    static var clipCookBackground: Color { DesignTokens.Colors.background }
    static var clipCookSurface: Color { DesignTokens.Colors.surface }
    static var clipCookTextPrimary: Color { DesignTokens.Colors.textPrimary }
    static var clipCookTextSecondary: Color { DesignTokens.Colors.textSecondary }
    static var clipCookPrimary: Color { DesignTokens.Colors.primary }
    static var clipCookSecondary: Color { DesignTokens.Colors.secondary }

    // Sizzle gradient colors (warm accent for cooking app)
    static var clipCookSizzleStart: Color { Color(hex: "FF6B4A") }  // Coral
    static var clipCookSizzleEnd: Color { Color(hex: "FF8E53") }    // Light Orange

    static var clipCookSuccess: Color { Color(hex: "4CAF50") }      // Green

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

// MARK: - Animation Extensions
extension Animation {
    static var whimsySpring: Animation {
        .spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.25)
    }
}

// MARK: - Text Style Modifiers
struct UtilityHeadline: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignTokens.Typography.headerFont(size: 20))
            .foregroundColor(DesignTokens.Colors.textPrimary)
    }
}

struct UtilitySubhead: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignTokens.Typography.bodyFont())
            .foregroundColor(DesignTokens.Colors.textSecondary)
    }
}
