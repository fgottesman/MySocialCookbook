/**
 * PreviewTimerBadge
 * Countdown timer shown during voice companion preview for free users.
 */

import SwiftUI

struct PreviewTimerBadge: View {
    let secondsRemaining: Int
    
    var isWarning: Bool {
        secondsRemaining <= 15
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.caption)
            Text(formatTime(secondsRemaining))
                .font(.caption.monospacedDigit().bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isWarning ? Color.orange : Color.black.opacity(0.5))
        )
        .foregroundColor(.white)
        .animation(.easeInOut(duration: 0.3), value: isWarning)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

/**
 * VoiceUpgradeSheet
 * Shown after voice preview ends for free users.
 */
struct VoiceUpgradeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Friendly illustration
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Enjoy cooking with Chef?")
                .font(.title2.bold())
            
            Text("Unlock unlimited voice assistance with ClipCook Pro. Your AI sous chef is ready when you are.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button(action: { showPaywall = true }) {
                    Text("Unlock Pro")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button("Continue Without Voice") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 40)
        .presentationDetents([.medium])
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

/**
 * CreditsBanner
 * Shows remaining credits with upgrade prompt.
 */
struct CreditsBanner: View {
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    
    var shouldShow: Bool {
        guard subscriptionManager.isPaywallEnabled else { return false }
        guard !subscriptionManager.isPro else { return false }
        return subscriptionManager.recipeCreditsRemaining <= 3
    }
    
    var body: some View {
        if shouldShow, let message = subscriptionManager.creditsMessage {
            Button(action: { showPaywall = true }) {
                HStack {
                    Image(systemName: subscriptionManager.recipeCreditsRemaining == 0 ? "exclamationmark.circle.fill" : "sparkles")
                        .foregroundColor(subscriptionManager.recipeCreditsRemaining == 0 ? .red : .orange)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("Upgrade")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )
                .padding(.horizontal)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

#Preview("Timer Badge") {
    VStack(spacing: 20) {
        PreviewTimerBadge(secondsRemaining: 45)
        PreviewTimerBadge(secondsRemaining: 10)
    }
    .padding()
    .background(Color.gray)
}

#Preview("Credits Banner") {
    CreditsBanner()
}
