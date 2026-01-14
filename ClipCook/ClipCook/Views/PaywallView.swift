/**
 * PaywallView
 * Main upgrade screen for ClipCook Pro subscription.
 */

import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedPackageId: String?
    
    // Derived from available packages
    private var annualPackage: SubscriptionPackage? {
        subscriptionManager.availablePackages.first(where: { $0.period == "Yearly" })
    }
    
    private var monthlyPackage: SubscriptionPackage? {
        subscriptionManager.availablePackages.first(where: { $0.period == "Monthly" })
    }
    
    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [Color.orange.opacity(0.9), Color.red.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Close button
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Hero section
                    VStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .yellow],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Text("ClipCook Pro")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Your AI Sous Chef, Unlimited")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.top, 20)
                    
                    // Features list
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "infinity", text: "Unlimited Recipe Imports", highlight: true)
                        FeatureRow(icon: "waveform", text: "AI Voice Companion", highlight: true)
                        FeatureRow(icon: "sparkles", text: "Smart Recipe Remixing", highlight: false)
                        FeatureRow(icon: "photo.fill", text: "AI Food Photography", highlight: false)
                        FeatureRow(icon: "heart.fill", text: "Support Indie Development", highlight: false)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Plan selection
                    if !subscriptionManager.availablePackages.isEmpty {
                        VStack(spacing: 12) {
                            // Annual plan (recommended)
                            if let annual = annualPackage {
                                PlanButton(
                                    title: "Annual",
                                    price: annual.priceString,
                                    subtitle: subscriptionManager.config.pricing.annualSavings, // Can update to use actual savings calc if needed
                                    isSelected: selectedPackageId == annual.id,
                                    isRecommended: true
                                ) {
                                    selectedPackageId = annual.id
                                }
                            }
                            
                            // Monthly plan
                            if let monthly = monthlyPackage {
                                PlanButton(
                                    title: "Monthly",
                                    price: monthly.priceString,
                                    subtitle: "Cancel anytime",
                                    isSelected: selectedPackageId == monthly.id,
                                    isRecommended: false
                                ) {
                                    selectedPackageId = monthly.id
                                }
                            }
                        }
                        .padding(.horizontal)
                        .onAppear {
                            // Default to annual if not set
                            if selectedPackageId == nil {
                                selectedPackageId = annualPackage?.id
                            }
                        }
                    } else {
                        // Loading state for packages
                        ProgressView()
                            .padding()
                    }
                    
                    // Subscribe button
                    Button(action: subscribe) {
                        HStack {
                            if subscriptionManager.isLoading {
                                ProgressView()
                                    .tint(.orange)
                            } else {
                                Text("Subscribe Now")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .foregroundColor(.orange)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    }
                    .disabled(subscriptionManager.isLoading || selectedPackageId == nil)
                    .opacity(subscriptionManager.isLoading ? 0.7 : 1.0)
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
                            Link("Terms", destination: URL(string: "https://ghplabs.io/terms")!)
                            Link("Privacy", destination: URL(string: "https://ghplabs.io/privacy")!)
                        }
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    // MARK: - Actions
    
    private func subscribe() {
        guard let packageId = selectedPackageId,
              let package = subscriptionManager.availablePackages.first(where: { $0.id == packageId }) else {
            return
        }
        
        errorMessage = nil
        
        Task {
            await subscriptionManager.purchase(package: package)
            
            if let error = subscriptionManager.error {
                 errorMessage = error
            } else if subscriptionManager.isPro {
                 dismiss()
            }
        }
    }
    
    private func restorePurchases() {
        errorMessage = nil
        
        Task {
            await subscriptionManager.restorePurchases()
            
            if let error = subscriptionManager.error {
                errorMessage = error
            } else if subscriptionManager.isPro {
                dismiss()
            } else {
                errorMessage = "No active subscription found to restore."
            }
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
                .foregroundColor(highlight ? .orange : .gray)
                .frame(width: 30)
            
            Text(text)
                .foregroundColor(.primary)
            
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
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(price)
                    .font(.title3.bold())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 3)
            )
        }
        .foregroundColor(isSelected ? .primary : .white)
    }
}

#Preview {
    PaywallView()
}
