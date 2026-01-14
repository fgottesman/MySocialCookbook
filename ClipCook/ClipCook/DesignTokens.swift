import SwiftUI

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
        static let spacing8: CGFloat = 8
        static let spacing16: CGFloat = 16
        static let spacing24: CGFloat = 24
        static let cornerRadius: CGFloat = 20
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
    
    // MARK: - Shadows
    struct Effects {
        static let softShadowRadius: CGFloat = 15
        static let softShadowColor = Color.black.opacity(0.3)
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
