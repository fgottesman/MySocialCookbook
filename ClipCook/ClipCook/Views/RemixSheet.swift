import SwiftUI

struct RemixSheet: View {
    @Binding var prompt: String
    @Binding var isRemixing: Bool
    var recipe: Recipe
    let onRemix: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Internal State
    @State private var chatHistory: [RemixService.ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var lastConsultation: RemixService.RemixConsultation?
    @FocusState private var isInputFocused: Bool
    
    // Rotating status messages
    private let statusMessages = [
        "Analyzing flavor profile...",
        "Checking ingredient compatibility...",
        "Consulting the flavor bible...",
        "Predicting cooking time...",
        "Reviewing techniques...",
        "Calculating difficulty..."
    ]
    @State private var currentStatusIndex = 0
    @State private var statusTimer: Timer?
    @State private var pulseAnimation = false
    
    // Suggestions with icons
    private let suggestions: [(text: String, icon: String)] = [
        ("Make it spicy", "flame.fill"),
        ("Make it vegetarian", "leaf.fill"),
        ("Gluten free", "allergens"),
        ("High protein", "bolt.fill"),
        ("Quick & Easy", "clock.fill"),
        ("Kid friendly", "face.smiling.fill")
    ]
    
    var body: some View {
        ZStack {
            // Background with subtle gradient overlay
            DesignTokens.Colors.background
                .ignoresSafeArea()
            
            // Subtle radial glow at top
            VStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [DesignTokens.Colors.primary.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(y: -150)
                    .blur(radius: 60)
                Spacer()
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                headerView
                
                // MARK: - Main Content
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 8)
                        
                        // Initial State: Suggestions
                        if chatHistory.isEmpty && !isLoading {
                            suggestionsView
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity
                                ))
                        }
                        
                        // Loading State
                        if isLoading {
                            loadingView
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        // Result Card
                        if let consult = lastConsultation, !isLoading {
                            resultView(consult: consult)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        
                        // Error State
                        if let lastMsg = chatHistory.last, lastMsg.role == "assistant", lastConsultation == nil, !isLoading {
                            errorView(message: lastMsg.content)
                        }
                        
                        Spacer(minLength: 120)
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isLoading)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: lastConsultation != nil)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isInputFocused = false
                }
                
                // MARK: - Input Area
                inputView
            }
        }
        .onAppear {
            isInputFocused = false
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack(alignment: .center) {
            // Chef Icon
            Image(systemName: "chef.hat.fill")
                .font(.title2)
                .foregroundStyle(LinearGradient.sizzle)
            
            Text("Remix Chef")
                .font(DesignTokens.Typography.headerFont(size: 20))
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            Spacer()
            
            Button(action: {
                stopStatusRotation()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.clipCookTextSecondary)
                    .padding(10)
                    .background(DesignTokens.Colors.surface)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            DesignTokens.Colors.background
                .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
        )
    }
    
    // MARK: - Suggestions View
    private var suggestionsView: some View {
        VStack(spacing: 24) {
            // Header text
            VStack(spacing: 8) {
                Text("How would you like to tweak this recipe?")
                    .font(DesignTokens.Typography.headerFont(size: 22))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .premiumText()

                Text("Pick a suggestion or type your own")
                    .font(DesignTokens.Typography.bodyFont())
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .premiumText()
            }
            .padding(.top, 8)

            // Suggestions grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(suggestions, id: \.text) { suggestion in
                    SuggestionCard(
                        text: suggestion.text,
                        icon: suggestion.icon
                    ) {
                        inputText = suggestion.text
                        submitConsultation()
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                // Outer ring pulse
                Circle()
                    .stroke(LinearGradient.sizzle.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0 : 0.8)
                    .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: pulseAnimation)
                
                // Inner circle
                Circle()
                    .fill(Color.clipCookSurface)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.clipCookSizzleStart.opacity(0.3), radius: 20)
                
                // Chef icon
                Image(systemName: "chef.hat.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(LinearGradient.sizzle)
            }
            .onAppear { pulseAnimation = true }
            .onDisappear { pulseAnimation = false }
            
            VStack(spacing: 12) {
                Text(statusMessages[currentStatusIndex])
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .animation(.easeInOut(duration: 0.3), value: currentStatusIndex)
                    .id(currentStatusIndex) // Force view refresh for animation
                
                // Animated dots
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.clipCookSizzleStart)
                            .frame(width: 8, height: 8)
                            .scaleEffect(pulseAnimation ? 1.0 : 0.6)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(i) * 0.2),
                                value: pulseAnimation
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: - Result View
    private func resultView(consult: RemixService.RemixConsultation) -> some View {
        VStack(spacing: 16) {
            // User query context
            if let search = chatHistory.filter({ $0.role == "user" }).last {
                HStack {
                    Image(systemName: "quote.opening")
                        .font(.caption)
                        .foregroundColor(.clipCookTextSecondary)
                    Text(search.content)
                        .font(.subheadline)
                        .italic()
                        .foregroundColor(.clipCookTextSecondary)
                    Image(systemName: "quote.closing")
                        .font(.caption)
                        .foregroundColor(.clipCookTextSecondary)
                }
                .padding(.horizontal)
            }
            
            // The consultation card
            ConsultationCard(consult: consult, onConfirm: confirmRemix)
        }
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.clipCookTextPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Input View
    private var inputView: some View {
        VStack(spacing: 0) {
            // Subtle top shadow
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.2), Color.clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(height: 20)
            
            HStack(spacing: 12) {
                // Text field with pill shape
                HStack {
                    TextField("Ask anything...", text: $inputText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            submitConsultation()
                        }
                    
                    if !inputText.isEmpty {
                        Button(action: { inputText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.clipCookTextSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(DesignTokens.Colors.surface)
                .cornerRadius(DesignTokens.Layout.cornerRadius)
                
                // Send button
                Button(action: submitConsultation) {
                    ZStack {
                        Group {
                            if inputText.isEmpty {
                                Circle().fill(Color.clipCookSurface)
                            } else {
                                Circle().fill(LinearGradient.sizzle)
                            }
                        }
                        .frame(width: 48, height: 48)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(inputText.isEmpty ? .clipCookTextSecondary : .white)
                    }
                }
                .disabled(inputText.isEmpty || isLoading)
                .animation(.spring(response: 0.3), value: inputText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DesignTokens.Colors.background)
        }
    }
    
    // MARK: - Logic
    
    private func submitConsultation() {
        guard !inputText.isEmpty else { return }
        
        let userMsg = RemixService.ChatMessage(role: "user", content: inputText)
        chatHistory.append(userMsg)
        
        let currentInput = inputText
        inputText = ""
        isLoading = true
        lastConsultation = nil
        startStatusRotation()
        isInputFocused = false
        
        Task {
            do {
                let consultation = try await RemixService.shared.remixConsult(
                    originalRecipe: recipe,
                    chatHistory: chatHistory,
                    prompt: currentInput
                )
                
                await MainActor.run {
                    stopStatusRotation()
                    isLoading = false
                    lastConsultation = consultation
                    
                    let aiMsg = RemixService.ChatMessage(role: "assistant", content: consultation.reply)
                    chatHistory.append(aiMsg)
                }
            } catch {
                print("Consultation error: \(error)")
                await MainActor.run {
                    stopStatusRotation()
                    isLoading = false
                    chatHistory.append(RemixService.ChatMessage(role: "assistant", content: "I'm having a bit of trouble connecting to the kitchen. Can you try again?"))
                }
            }
        }
    }
    
    private func confirmRemix() {
        let conversationLog = chatHistory.map { "\($0.role.uppercased()): \($0.content)" }.joined(separator: "\n")
        let finalPrompt = "Apply the changes discussed in this conversation:\n\n\(conversationLog)"
        
        prompt = finalPrompt
        onRemix()
    }
    
    private func startStatusRotation() {
        currentStatusIndex = 0
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            withAnimation {
                currentStatusIndex = (currentStatusIndex + 1) % statusMessages.count
            }
        }
    }
    
    private func stopStatusRotation() {
        statusTimer?.invalidate()
        statusTimer = nil
    }
}

// MARK: - Suggestion Chip Component
struct SuggestionChip: View {
    let text: String
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(LinearGradient.sizzle)
                
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.clipCookSurface)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient.sizzle.opacity(isPressed ? 0.8 : 0.2),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}

// MARK: - Suggestion Card Component (Grid Layout)
struct SuggestionCard: View {
    let text: String
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.clipCookBackground)
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(LinearGradient.sizzle)
                }

                Text(text)
                    .font(DesignTokens.Typography.bodyFont(size: 18))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .premiumText()
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient.sizzle.opacity(isPressed ? 0.8 : 0.15),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Consultation Card Component
struct ConsultationCard: View {
    let consult: RemixService.RemixConsultation
    let onConfirm: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Chef's Reply
            Text(consult.reply)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .lineSpacing(4)
            
            // Metrics Row
            HStack(spacing: 0) {
                MetricBadge(
                    title: "Difficulty",
                    value: consult.difficultyImpact,
                    color: difficultyColor(consult.difficultyImpact),
                    icon: "chart.bar.fill"
                )
                
                Spacer()
                
                Rectangle()
                    .fill(Color.clipCookTextSecondary.opacity(0.2))
                    .frame(width: 1, height: 40)
                
                Spacer()
                
                MetricBadge(
                    title: "Quality",
                    value: consult.qualityImpact,
                    color: qualityColor(consult.qualityImpact),
                    icon: "star.fill"
                )
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.black.opacity(0.2))
            .cornerRadius(12)
            
            // Explanations
            if !consult.difficultyExplanation.isEmpty || !consult.qualityExplanation.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if !consult.difficultyExplanation.isEmpty {
                        ExplanationRow(icon: "info.circle.fill", text: consult.difficultyExplanation)
                    }
                    if !consult.qualityExplanation.isEmpty {
                        ExplanationRow(icon: "sparkles", text: consult.qualityExplanation)
                    }
                }
            }
            
            // Action Button
            Button(action: onConfirm) {
                HStack(spacing: 8) {
                    Text("Let's Make It")
                        .font(.system(size: 16, weight: .bold))
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient.sizzle)
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: Color.clipCookSizzleStart.opacity(0.4), radius: 12, y: 4)
            }
        }
        .padding(20)
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.Layout.cornerRadius)
        .shadow(color: Color.black.opacity(0.3), radius: DesignTokens.Effects.softShadowRadius, y: 8)
        .padding(.horizontal, 20)
    }
    
    private func difficultyColor(_ impact: String) -> Color {
        switch impact.lowercased() {
        case "easier": return .green
        case "harder": return .orange
        case "same": return .blue
        default: return .clipCookTextSecondary
        }
    }
    
    private func qualityColor(_ impact: String) -> Color {
        switch impact.lowercased() {
        case "better": return .green
        case "worse": return .red
        case "different": return .purple
        default: return .clipCookTextSecondary
        }
    }
}

// MARK: - Metric Badge Component
struct MetricBadge: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.clipCookTextSecondary)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.clipCookTextSecondary)
                    .tracking(0.5)
            }
            
            Text(value.uppercased())
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
        }
        .frame(minWidth: 80)
    }
}

// MARK: - Explanation Row Component
struct ExplanationRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(LinearGradient.sizzle)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.clipCookTextSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        if rows.isEmpty { return .zero }
        let height = rows.last!.maxY
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        for row in rows {
            for element in row.elements {
                element.subview.place(at: CGPoint(x: bounds.minX + element.x, y: bounds.minY + element.y), proposal: .unspecified)
            }
        }
    }
    
    struct Row {
        var elements: [(subview: LayoutSubview, x: CGFloat, y: CGFloat)] = []
        var maxY: CGFloat = 0
    }
    
    func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth {
                currentX = 0
                currentY = currentRow.maxY + spacing
                rows.append(currentRow)
                currentRow = Row()
            }
            
            currentRow.elements.append((subview, currentX, currentY))
            currentRow.maxY = max(currentRow.maxY, currentY + size.height)
            currentX += size.width + spacing
        }
        
        if !currentRow.elements.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
}
