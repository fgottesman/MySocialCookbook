import SwiftUI
import UserNotifications

struct NUXView: View {
    @Binding var showingAddRecipe: Bool
    @State private var selection = 0
    
    var body: some View {
        ZStack {
            DesignTokens.Colors.background.ignoresSafeArea()
            
            TabView(selection: $selection) {
                // Step 1: Branding
                NUXCard(
                    title: "ClipCook",
                    subtitle: "Your AI-powered social cookbook. Turn any cooking video into a step-by-step recipe with magic! ✨",
                    imageName: "sparkles",
                    color: .clipCookSizzleStart
                ) {
                    Button(action: { withAnimation { selection = 1 } }) {
                        Text("Tell me more")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(LinearGradient.sizzle)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }
                .tag(0)
                
                // Step 2: How to Share
                NUXCard(
                    title: "Share to Clip",
                    subtitle: "When you find a delicious recipe on TikTok, IG, or YouTube, tap Share and select ClipCook.",
                    imageName: "square.and.arrow.up.fill",
                    color: .clipCookSizzleEnd
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        NUXStepRow(number: "1", text: "Tap the Share icon")
                        NUXStepRow(number: "2", text: "Tap 'More...' or 'Apps'")
                        NUXStepRow(number: "3", text: "Select ClipCook!")
                    }
                    .padding(.horizontal, 40)
                    
                    Button(action: { withAnimation { selection = 2 } }) {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.clipCookTextSecondary)
                    }
                    .padding(.top, 10)
                }
                .tag(1)
                
                // Step 3: Push Permissions
                NUXCard(
                    title: "Stay in the Loop",
                    subtitle: "AI cooking takes a minute! We'll notify you the second your recipe is ready to cook. 🍳",
                    imageName: "bell.badge.fill",
                    color: .clipCookSizzleStart
                ) {
                    Button(action: requestNotifications) {
                        Text("Enable Notifications")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(LinearGradient.sizzle)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }
                .tag(2)
                
                // Step 4: Pro Tip: Favorite us
                NUXCard(
                    title: "Pro Tip: Pin Us!",
                    subtitle: "Add ClipCook to your Favorites in the Share Sheet so it's always at the top for instant clipping.",
                    imageName: "pin.fill",
                    color: .clipCookSuccess
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        NUXStepRow(number: "1", text: "Tap Share → More (...)")
                        NUXStepRow(number: "2", text: "Tap Edit in the corner")
                        NUXStepRow(number: "3", text: "Tap (+) next to ClipCook")
                    }
                    .padding(.horizontal, 40)
                    
                    Button(action: { withAnimation { selection = 4 } }) {
                        Text("Got it!")
                            .font(.headline)
                            .foregroundColor(.clipCookTextSecondary)
                    }
                    .padding(.top, 10)
                }
                .tag(3)
                
                // Step 5: Create Your First Recipe
                NUXCard(
                    title: "Let's Get Cooking",
                    subtitle: "Find a recipe you love or describe what you want to make.",
                    imageName: "flame.fill",
                    color: .clipCookSizzleStart
                ) {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            AppIconButton(image: "tiktok_logo", name: "tiktok") { openApp(scheme: "snssdk1233://", fallback: "https://tiktok.com/search?q=recipes") }
                            AppIconButton(image: "instagram_logo", name: "instagram") { openApp(scheme: "instagram://", fallback: "https://instagram.com/explore/tags/recipes/") }
                            AppIconButton(image: "youtube_logo", name: "youtube") { openApp(scheme: "youtube://", fallback: "https://youtube.com/search?q=cooking+recipes") }
                        }
                        
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.vertical, 4)
                        
                        Button(action: { showingAddRecipe = true }) {
                            Text("Paste Link or Describe")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(DesignTokens.Colors.surface)
                                .cornerRadius(DesignTokens.Layout.cornerRadius / 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadius / 2)
                                        .stroke(LinearGradient.sizzle, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
    
    // MARK: - Actions
    
    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            DispatchQueue.main.async {
                withAnimation {
                    selection = 3
                }
            }
        }
    }
    
    private func openApp(scheme: String, fallback: String) {
        if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            UIApplication.shared.open(URL(string: fallback)!)
        }
    }
}

// MARK: - Subviews

struct AppIconButton: View {
    let image: String
    let name: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.clipCookSurface)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: systemIcon(for: name))
                        .font(.title)
                        .foregroundColor(.white)
                }
                Text(name.capitalized)
                    .font(.caption2)
                    .foregroundColor(.clipCookTextSecondary)
            }
        }
    }
    
    private func systemIcon(for name: String) -> String {
        switch name {
        case "tiktok": return "music.note"
        case "instagram": return "camera.fill"
        case "youtube": return "play.rectangle.fill"
        default: return "app.fill"
        }
    }
}

struct NUXCard<Content: View>: View {
    let title: String
    let subtitle: String
    let imageName: String
    let color: Color
    let content: Content
    
    init(title: String, subtitle: String, imageName: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon Circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: imageName)
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(color)
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(DesignTokens.Typography.headerFont(size: 32))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .premiumText()
                
                Text(subtitle)
                    .font(DesignTokens.Typography.bodyFont(size: 18))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .premiumText()
            }
            
            content
            
            Spacer()
            Spacer()
        }
        .padding()
        .frame(maxWidth: 500)
    }
}

struct NUXStepRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text(number)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(LinearGradient.sizzle))
            
            Text(text)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(.clipCookTextPrimary)
        }
    }
}
struct NUXView_Previews: PreviewProvider {
    static var previews: some View {
        NUXView(showingAddRecipe: .constant(false))
    }
}
