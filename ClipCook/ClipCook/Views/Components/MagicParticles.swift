
import SwiftUI

struct MagicParticlesView: View {
    let emojis = ["🧂", "✨", "🌿", "🍳", "🔥", "🥄"]
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var emoji: String
        var opacity: Double
        var scale: CGFloat
    }
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Text(particle.emoji)
                    .font(.system(size: 20))
                    .position(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
                    .scaleEffect(particle.scale)
            }
        }
        .onAppear {
            startTimer()
        }
    }
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            withAnimation(.whimsySpring) {
                if particles.count < 15 {
                    addParticle()
                }
            }
            
            // Cleanup and move existing particles
            for i in particles.indices {
                particles[i].y -= 20
                particles[i].opacity -= 0.1
            }
            particles.removeAll { $0.opacity <= 0 }
        }
    }
    
    private func addParticle() {
        let newParticle = Particle(
            x: CGFloat.random(in: 100...300),
            y: 400,
            emoji: emojis.randomElement() ?? "✨",
            opacity: 1.0,
            scale: CGFloat.random(in: 0.5...1.5)
        )
        particles.append(newParticle)
    }
}

// Helper modifier for shimmer effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + (geo.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func magicalShimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
    
    func withWhimsyBounce(trigger: Bool) -> some View {
        self.scaleEffect(trigger ? 1.0 : 0.95)
            .animation(.whimsySpring, value: trigger)
    }
}
