/**
 * PaywallView
 * Main upgrade screen for ClipCook Pro subscription.
 */

import SwiftUI
import RevenueCat


struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedPlan: Plan = .annual
    @State private var showSuccess = false
    
    enum Plan {
        case monthly, annual
    }
    
    var body: some View {
        ZStack {
            // Midnight Rose Theme Gradient
            Color.clipCookBackground.ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    Color.clipCookSizzleStart.opacity(0.15),
                    Color.clipCookBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            
            ScrollView {
                VStack(spacing: 24) {
                    // Hero section
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 70))
                            .foregroundStyle(LinearGradient.sizzle)
                        
                        Text("ClipCook Pro")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Your AI Sous Chef, Unlimited")
                            .font(.title3)
                            .foregroundColor(.clipCookSizzleStart)
                    }
                    .padding(.top, 20)

                    
                    // Features list
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "infinity", text: "Unlimited recipe imports", highlight: true)
                        FeatureRow(icon: "phone.bubble.fill", text: "Unlimited calls to the chef", highlight: true)
                        FeatureRow(icon: "wand.and.stars", text: "Unlimited recipe remix", highlight: true)
                        FeatureRow(icon: "sparkles.tv", text: "Early access to beta features", highlight: false)
                    }
                    .padding(20)
                    .background(Color.clipCookSurface.opacity(0.8))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.clipCookSizzleStart.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    
                    // Plan selection - always show correct pricing
                    VStack(spacing: 12) {
                        // Annual plan
                        PlanButton(
                            title: "Annual",
                            price: subscriptionManager.offerings?.current?.annual?.localizedPriceString ?? "$21.99",
                            subtitle: "Save 54% — best value!",
                            isSelected: selectedPlan == .annual,
                            isRecommended: true
                        ) {
                            selectedPlan = .annual
                        }
                        
                        // Monthly plan
                        PlanButton(
                            title: "Monthly",
                            price: subscriptionManager.offerings?.current?.monthly?.localizedPriceString ?? "$3.99",
                            subtitle: "Flexible monthly billing",
                            isSelected: selectedPlan == .monthly,
                            isRecommended: false
                        ) {
                            selectedPlan = .monthly
                        }
                    }
                    .padding(.horizontal)

                    
                    // Subscribe button
                    Button(action: subscribe) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.orange)
                            } else {
                                Text("Subscribe Now")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient.sizzle)
                        .foregroundColor(.clipCookBackground)
                        .cornerRadius(14)
                        .shadow(color: Color.clipCookSizzleStart.opacity(0.2), radius: 10, y: 5)

                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                    }
                    
                    // Restore & Terms
                    VStack(spacing: 8) {
                        Button("Restore Purchases") {
                            restorePurchases()
                        }
                        .font(.footnote.bold())
                        .foregroundColor(.white.opacity(0.9))
                        
                        HStack(spacing: 16) {
                            Link("Terms", destination: URL(string: "https://clipcookapp.com/terms")!)
                            Link("Privacy", destination: URL(string: "https://clipcookapp.com/privacy")!)
                        }
                        .font(.caption2)
                        .foregroundColor(.clipCookTextSecondary.opacity(0.6))

                    }
                    .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                }
            }
            
            // Success Overlay
            if showSuccess {
                Color.clipCookBackground.opacity(0.95)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.clipCookSizzleStart)
                        .scaleEffect(showSuccess ? 1 : 0)
                        .animation(.spring(.bouncy), value: showSuccess)
                    
                    Text("Welcome to ClipCook Pro!")
                        .font(.title2.bold())
                        .foregroundColor(.clipCookTextPrimary)
                    
                    Text("You now have unlimited access")
                        .font(.body)
                        .foregroundColor(.clipCookTextSecondary)
                }
                .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                LiquidGlassBackButton()
            }
        }
    }
    
    // MARK: - Actions
    
    private func subscribe() {
        guard let currentOfferings = subscriptionManager.offerings?.current else { 
            errorMessage = "Pricing not available. Please check your connection."
            return 
        }
        
        let package = selectedPlan == .annual ? currentOfferings.annual : currentOfferings.monthly
        
        guard let packageToPurchase = package else {
            errorMessage = "Selected plan is currently unavailable."
            return
        }

        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await Purchases.shared.purchase(package: packageToPurchase)
                if !result.userCancelled {
                    await subscriptionManager.loadSubscriptionStatus()
                    
                    // Show success animation
                    withAnimation {
                        showSuccess = true
                    }
                    
                    // Dismiss after 1.5 seconds
                    try? await Task.sleep(for: .seconds(1.5))
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    
    private func restorePurchases() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let customerInfo = try await Purchases.shared.restorePurchases()
                await subscriptionManager.loadSubscriptionStatus()
                
                if subscriptionManager.isPro || customerInfo.entitlements["ClipCook Pro"]?.isActive == true {
                    dismiss()
                } else {
                    errorMessage = "No active purchases found to restore."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let text: String
    let highlight: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(highlight ? .clipCookSizzleStart : .clipCookTextSecondary.opacity(0.5))
                .frame(width: 30)

            
            Text(text)
                .foregroundColor(.white)

            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

struct PlanButton: View {
    let title: String
    let price: String
    let subtitle: String
    let isSelected: Bool
    let isRecommended: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        
                        if isRecommended {
                            Text("BEST VALUE")
                                .font(.caption2.bold())
                                .foregroundColor(.clipCookBackground)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.clipCookSizzleStart)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.clipCookTextSecondary.opacity(0.7))
                }
                
                Spacer()
                
                Text(price)
                    .font(.title3.bold())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.clipCookSurface : Color.clipCookSurface.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clipCookSizzleStart : Color.clear, lineWidth: 2)
            )

        }
        .foregroundColor(isSelected ? .white : .clipCookTextSecondary)

    }
}

#Preview {
    PaywallView()
}
