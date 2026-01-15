import SwiftUI

/// A frosted glass back button for consistent navigation across the Profile tab.
/// Uses ultraThinMaterial for the "liquid glass" effect.
struct LiquidGlassBackButton: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.clipCookTextPrimary)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .accessibilityLabel("Back")
    }
}

#Preview {
    ZStack {
        Color.clipCookBackground.ignoresSafeArea()
        LiquidGlassBackButton()
    }
}
