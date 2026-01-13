import SwiftUI
import Combine

struct ProcessingSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Animation States
    @State private var isAnimating = false
    @State private var pulseRate: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var showParticles = false
    
    // Text Cycling
    @State private var currentStepIndex = 0
    let steps = [
        "Analyzing video frames...",
        "Identifying ingredients...",
        "Constructing culinary logic...",
        "Finalizing recipe..."
    ]
    
    let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.clipCookBackground.ignoresSafeArea()
            
            // Background ambient glow
            Circle()
                .fill(Color.clipCookSizzleStart.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isAnimating)
            
            VStack(spacing: 40) {
                Spacer()
                
                // MARK: - AI Visualization
                ZStack {
                    // Outer rings
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.clipCookSizzleStart.opacity(0.5), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 150 + CGFloat(i * 40), height: 150 + CGFloat(i * 40))
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .animation(
                                .linear(duration: Double(10 + i * 5)).repeatForever(autoreverses: false),
                                value: isAnimating
                            )
                    }
                    
                    // Central Core
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.clipCookSizzleStart, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .opacity(isAnimating ? 1 : 0.5)
                                .scaleEffect(isAnimating ? 1.1 : 0.9)
                        )
                        .shadow(color: .clipCookSizzleStart.opacity(0.5), radius: 20, x: 0, y: 0)
                        .scaleEffect(isAnimating ? 1.05 : 0.90)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                }
                .padding(.top, 40)
                
                // MARK: - Status Text
                VStack(spacing: 16) {
                    Text(steps[currentStepIndex])
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .scale))
                        .id("step-\(currentStepIndex)") // Force transition on change
                    
                    Text("The AI Chef is reviewing the video to understand the ingredients and techniques used to generate a perfect recipe.")
                        .font(.body)
                        .foregroundColor(.clipCookTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .lineSpacing(4)
                }
                
                Spacer()
                
                // MARK: - Footer Actions
                VStack(spacing: 16) {
                    Text("We'll notify you when it's ready. You can close this view now.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: { dismiss() }) {
                        Text("Keep Swiping")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.clipCookSurface)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentStepIndex = (currentStepIndex + 1) % steps.count
            }
        }
    }
}

// Preview Provider
#Preview {
    ProcessingSuccessView()
}
