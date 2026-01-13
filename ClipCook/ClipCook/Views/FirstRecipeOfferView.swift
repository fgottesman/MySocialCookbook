/**
 * FirstRecipeOfferView
 * Time-limited 50% off offer shown after user saves their first recipe.
 */

import SwiftUI

struct FirstRecipeOfferView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var timeRemaining: TimeInterval
    @State private var timer: Timer?
    @State private var isLoading = false
    @State private var showFullPaywall = false
    
    init() {
        let duration = SubscriptionManager.shared.config.offers.firstRecipeOfferDurationSeconds
        _timeRemaining = State(initialValue: TimeInterval(duration))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Celebration emoji
            Text("🎉")
                .font(.system(size: 70))
                .padding(.top, 20)
            
            // Congrats message
            Text("Congrats on your first recipe!")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            
            Text("Unlock Pro in the next hour and get")
                .foregroundColor(.secondary)
            
            // Discount badge
            Text("\(subscriptionManager.config.offers.firstRecipeOfferDiscountPercent)% OFF")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .orange.opacity(0.4), radius: 10, y: 5)
            
            Text("your first year")
                .font(.headline)
            
            // Strikethrough pricing
            HStack(spacing: 10) {
                Text(subscriptionManager.config.pricing.annualPrice)
                    .strikethrough()
                    .foregroundColor(.secondary)
                
                Text("→")
                    .foregroundColor(.secondary)
                
                Text(discountedPrice)
                    .font(.title2.bold())
                    .foregroundColor(.green)
            }
            
            // Countdown timer
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                Text("Offer expires in: \(formatTime(timeRemaining))")
                    .font(.subheadline.monospacedDigit())
            }
            .foregroundColor(timeRemaining < 300 ? .red : .orange)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.1))
            )
            
            // CTA Button
            Button(action: claimDiscount) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Claim My Discount")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(isLoading)
            .padding(.horizontal)
            
            // Maybe later
            Button("Maybe later") {
                dismiss()
            }
            .foregroundColor(.secondary)
            .padding(.bottom, 20)
        }
        .padding()
        .onAppear {
            startTimer()
            Task {
                await subscriptionManager.markFirstRecipeOfferShown()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .sheet(isPresented: $showFullPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - Computed
    
    private var discountedPrice: String {
        // Parse the annual price and apply discount
        let price = subscriptionManager.config.pricing.annualPrice
        let discount = subscriptionManager.config.offers.firstRecipeOfferDiscountPercent
        
        // Simple string manipulation for display
        // In real implementation, use actual pricing from RevenueCat
        if let numericPrice = Double(price.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
            let discountedValue = numericPrice * (1 - Double(discount) / 100)
            return String(format: "$%.2f/year", discountedValue)
        }
        return "$10.99/year"
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
                dismiss()
            }
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    // MARK: - Actions
    
    private func claimDiscount() {
        isLoading = true
        
        Task {
            // TODO: Purchase introductory offer via RevenueCat
            // For now, show full paywall
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
            showFullPaywall = true
        }
    }
}

#Preview {
    FirstRecipeOfferView()
}
