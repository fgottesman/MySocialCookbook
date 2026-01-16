/**
 * ManageSubscriptionView
 * Displayed when a Pro subscriber taps "ClipCook Pro" in Profile.
 * Shows subscription status and links to App Store management.
 */

import SwiftUI

struct ManageSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        ZStack {
            Color.clipCookBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Success Header
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(LinearGradient.roseGold)
                        
                        Text("You're a Pro!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.clipCookTextPrimary)
                        
                        Text("Thank you for subscribing to ClipCook Pro")
                            .font(.body)
                            .foregroundColor(.clipCookTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Benefits Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Pro Benefits")
                            .font(.headline)
                            .foregroundColor(.clipCookTextPrimary)
                        
                        BenefitRow(icon: "infinity", text: "Unlimited recipe imports")
                        BenefitRow(icon: "phone.bubble.fill", text: "Unlimited calls to the chef")
                        BenefitRow(icon: "wand.and.stars", text: "Unlimited recipe remix")
                        BenefitRow(icon: "sparkles.tv", text: "Early access to beta features")
                    }
                    .padding(20)
                    .background(Color.clipCookSurface)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.clipCookPrimary.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Manage Subscription Button
                    Button(action: openSubscriptionManagement) {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("Manage Subscription")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.clipCookSurface)
                        .foregroundColor(.clipCookTextPrimary)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.clipCookPrimary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    
                    Text("Opens in Settings")
                        .font(.caption)
                        .foregroundColor(.clipCookTextSecondary.opacity(0.6))
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("ClipCook Pro")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                LiquidGlassBackButton()
            }
        }
    }
    
    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

private struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.clipCookPrimary)
                .frame(width: 24)
            
            Text(text)
                .foregroundColor(.clipCookTextPrimary)
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.clipCookSuccess)
        }
    }
}

#Preview {
    NavigationView {
        ManageSubscriptionView()
    }
}
