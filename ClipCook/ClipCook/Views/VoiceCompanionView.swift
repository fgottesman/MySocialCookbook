
import SwiftUI
import AVFoundation
import AVFAudio

struct VoiceCompanionView: View {
    let recipe: Recipe
    
    // Step navigation - now tracks both main steps and sub-steps
    @State private var currentStepIndex: Int = 0
    @State private var currentSubStepIndex: Int = 0
    
    // Pre-loaded step preparations (cached for all steps)
    @State private var stepPreparationCache: [Int: StepPreparation] = [:]
    @State private var isPreloading = false
    
    // Current step's preparation (from cache)
    private var stepPreparation: StepPreparation? {
        stepPreparationCache[currentStepIndex]
    }
    
    // Chat and voice state
    @StateObject private var speechManager = SpeechManager.shared
    @State private var chatHistory: [ChatMessage] = []
    @State private var isProcessing = false
    @State private var showingAIResponse = false
    
    // User preferences
    @State private var userPreferences: UserPreferences = .default
    @State private var showingConversionPopover = false
    
    @Environment(\.presentationMode) var presentationMode
    
    // Computed properties for navigation
    private var totalSteps: Int {
        recipe.instructions?.count ?? 0
    }
    
    private var hasSubSteps: Bool {
        (stepPreparation?.subSteps?.count ?? 0) > 1
    }
    
    private var totalSubSteps: Int {
        stepPreparation?.subSteps?.count ?? 1
    }
    
    private var currentDisplayText: String {
        if hasSubSteps, let subSteps = stepPreparation?.subSteps, currentSubStepIndex < subSteps.count {
            return subSteps[currentSubStepIndex].text
        }
        return recipe.instructions?[currentStepIndex] ?? ""
    }
    
    private var currentStepLabel: String {
        if hasSubSteps, let subSteps = stepPreparation?.subSteps, currentSubStepIndex < subSteps.count {
            return "STEP \(subSteps[currentSubStepIndex].label)"
        }
        return "STEP \(currentStepIndex + 1)"
    }
    
    private var canGoBack: Bool {
        if hasSubSteps && currentSubStepIndex > 0 {
            return true
        }
        return currentStepIndex > 0
    }
    
    private var canGoForward: Bool {
        if hasSubSteps && currentSubStepIndex < totalSubSteps - 1 {
            return true
        }
        return currentStepIndex < totalSteps - 1
    }
    
    var body: some View {
        ZStack {
            Color.clipCookBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with mute button
                headerView
                
                Spacer()
                
                // Main Step Content
                if !recipe.instructions.isEmptyOrNil {
                    stepContentView
                }
                
                // Conversion badges (if any)
                if let conversions = stepPreparation?.conversions, !conversions.isEmpty {
                    conversionBadgesView(conversions: conversions)
                }
                
                Spacer()
                
                // AI Response / Transcription Overlay
                responseOverlayView
                
                // Microphone Controls
                microphoneControlsView
            }
            
        }
        .onAppear {
            speechManager.requestPermissions()
            preloadAllSteps()
            loadUserPreferences()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sous Chef Mode")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(LinearGradient.sizzle)
                Text(recipe.title)
                    .font(.caption)
                    .foregroundColor(.clipCookTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            
            // Mute Button
            Button(action: { 
                speechManager.isMuted.toggle()
                if speechManager.isMuted {
                    speechManager.stopSpeaking()
                }
            }) {
                Image(systemName: speechManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundColor(speechManager.isMuted ? .clipCookSizzleStart : .clipCookTextSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.clipCookSurface)
                    .cornerRadius(12)
            }
            
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.clipCookTextSecondary)
            }
        }
        .padding()
    }
    
    // MARK: - Step Content View
    private var stepContentView: some View {
        HStack(spacing: 20) {
            // Back Arrow
            Button(action: navigateBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(canGoBack ? .white : .white.opacity(0.1))
            }
            .disabled(!canGoBack)
            
            // Step Text
            VStack(spacing: 24) {
                Text(currentStepLabel)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.clipCookSizzleStart)
                    .tracking(2)
                
                // Sub-step indicator dots (if applicable)
                if hasSubSteps {
                    HStack(spacing: 6) {
                        ForEach(0..<totalSubSteps, id: \.self) { index in
                            Circle()
                                .fill(index == currentSubStepIndex ? Color.clipCookSizzleStart : Color.clipCookSurface)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                
                ScrollView {
                    Text(currentDisplayText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .padding(.horizontal)
                }
                .frame(maxHeight: 250)
            }
            .frame(maxWidth: .infinity)
            
            // Forward Arrow
            Button(action: navigateForward) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(canGoForward ? .white : .white.opacity(0.1))
            }
            .disabled(!canGoForward)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Conversion Badges View
    private func conversionBadgesView(conversions: [MeasurementConversion]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(conversions) { conversion in
                    Button(action: {
                        // Speak the conversion when tapped
                        speechManager.speak(conversion.spoken)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.caption2)
                            Text(userPreferences.unitSystem == "metric" ? conversion.metric : conversion.imperial)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.clipCookSurface)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                }
                
                // Unit preference toggle
                Button(action: toggleUnitPreference) {
                    Image(systemName: "gearshape.fill")
                        .font(.caption)
                        .foregroundColor(.clipCookTextSecondary)
                        .padding(8)
                        .background(Color.clipCookSurface.opacity(0.5))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Response Overlay View
    @ViewBuilder
    private var responseOverlayView: some View {
        if !speechManager.transcript.isEmpty && (speechManager.isRecording || speechManager.isTranscribing) {
            Text(speechManager.transcript)
                .font(.headline)
                .foregroundColor(.clipCookTextSecondary)
                .italic()
                .padding()
                .background(Color.clipCookSurface.opacity(0.8))
                .cornerRadius(12)
                .magicalShimmer()
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if showingAIResponse, let lastMessage = chatHistory.last, lastMessage.role == "ai" {
            Text(lastMessage.content)
                .font(.body)
                .foregroundColor(.white)
                .padding()
                .background(Color.clipCookSizzleStart.opacity(0.2))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.clipCookSizzleStart, lineWidth: 1)
                )
                .padding()
                .withWhimsyBounce(trigger: showingAIResponse)
                .transition(.scale.combined(with: .opacity))
        }
    }
    
    // MARK: - Microphone Controls View
    private var microphoneControlsView: some View {
        VStack(spacing: 16) {
            if isProcessing {
                VStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(LinearGradient.sizzle)
                        .scaleEffect(isProcessing ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isProcessing)
                    
                    Text("Stirring the logic... 🥄")
                        .font(.caption)
                        .foregroundColor(.clipCookTextSecondary)
                        .italic()
                }
            } else {
                VStack(spacing: 12) {
                    ZStack {
                        // Pulsing background when recording
                        if speechManager.isRecording {
                            Circle()
                                .fill(LinearGradient.sizzle)
                                .frame(width: 90, height: 90)
                                .scaleEffect(1.2 + CGFloat(speechManager.audioLevel))
                                .opacity(0.3)
                                .animation(.easeInOut(duration: 0.1), value: speechManager.audioLevel)
                        }
                        
                        Circle()
                            .fill(speechManager.isRecording ? LinearGradient.sizzle : LinearGradient(colors: [.clipCookSurface, .clipCookSurface], startPoint: .top, endPoint: .bottom))
                            .frame(width: 80, height: 80)
                            .shadow(color: speechManager.isRecording ? .clipCookSizzleStart.opacity(0.5) : .black.opacity(0.3), radius: 15)
                        
                        Image(systemName: speechManager.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !speechManager.isRecording && !isProcessing {
                                    speechManager.startRecording()
                                }
                            }
                            .onEnded { _ in
                                if speechManager.isRecording {
                                    stopAndSend()
                                }
                            }
                    )
                    
                    Text(speechManager.isRecording ? "I'm all ears... 👂" : "Tap and hold to ask the sous chef questions")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.clipCookTextSecondary)
                        .opacity(speechManager.isRecording ? 0.7 : 1.0)
                        .animation(.whimsySpring, value: speechManager.isRecording)
                }
            }
        }
        .padding(.bottom, 50)
    }
    
    // MARK: - Navigation Methods
    private func navigateBack() {
        withAnimation {
            if hasSubSteps && currentSubStepIndex > 0 {
                // Go to previous sub-step
                currentSubStepIndex -= 1
            } else if currentStepIndex > 0 {
                // Go to previous main step
                currentStepIndex -= 1
                currentSubStepIndex = 0
                speakCurrentStepIntro()
            }
        }
    }
    
    private func navigateForward() {
        withAnimation {
            if hasSubSteps && currentSubStepIndex < totalSubSteps - 1 {
                // Go to next sub-step
                currentSubStepIndex += 1
            } else if currentStepIndex < totalSteps - 1 {
                // Go to next main step
                currentStepIndex += 1
                currentSubStepIndex = 0
                speakCurrentStepIntro()
            }
        }
    }
    
    // MARK: - Data Loading
    
    /// Pre-load all step preparations when cooking starts (non-blocking)
    private func preloadAllSteps() {
        guard !recipe.instructions.isEmptyOrNil else { return }
        
        let stepCount = recipe.instructions?.count ?? 0
        isPreloading = true
        
        Task {
            // Load all steps concurrently
            await withTaskGroup(of: (Int, StepPreparation?).self) { group in
                for index in 0..<stepCount {
                    group.addTask {
                        do {
                            let preparation = try await VoiceCompanionService.shared.prepareStep(
                                recipe: self.recipe,
                                stepIndex: index,
                                stepLabel: String(index + 1)
                            )
                            return (index, preparation)
                        } catch {
                            print("Error preloading step \(index): \(error)")
                            return (index, nil)
                        }
                    }
                }
                
                // Collect results as they complete
                for await (index, preparation) in group {
                    if let prep = preparation {
                        await MainActor.run {
                            stepPreparationCache[index] = prep
                            
                            // Speak the first step as soon as it's ready
                            if index == 0 && currentStepIndex == 0 {
                                speechManager.speak(prep.introduction)
                            }
                        }
                    }
                }
            }
            
            await MainActor.run {
                isPreloading = false
            }
        }
    }
    
    /// Speak the introduction for current step (uses cache)
    private func speakCurrentStepIntro() {
        if let prep = stepPreparationCache[currentStepIndex] {
            speechManager.speak(prep.introduction)
        }
    }
    
    private func loadUserPreferences() {
        // TODO: Get actual userId from auth
        Task {
            // For now, use defaults - will wire up with real auth later
        }
    }
    
    private func toggleUnitPreference() {
        userPreferences.unitSystem = userPreferences.unitSystem == "metric" ? "imperial" : "metric"
        // TODO: Save to backend with actual userId
    }
    
    // MARK: - Voice Q&A
    func stopAndSend() {
        isProcessing = true
        
        Task {
            guard let text = await speechManager.stopRecording() else {
                await MainActor.run { isProcessing = false }
                return
            }
            
            guard !text.isEmpty && text != "Listening..." && text != "Transcribing..." else {
                await MainActor.run { isProcessing = false }
                return
            }
            
            await MainActor.run {
                chatHistory.append(ChatMessage(role: "user", content: text))
            }
            
            do {
                let reply = try await VoiceCompanionService.shared.chat(
                    recipe: recipe,
                    currentStepIndex: currentStepIndex,
                    history: chatHistory,
                    message: text
                )
                
                await MainActor.run {
                    isProcessing = false
                    chatHistory.append(ChatMessage(role: "ai", content: reply))
                    showingAIResponse = true
                    speechManager.speak(reply)
                    
                    // Auto-hide after 5 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                        await MainActor.run {
                            withAnimation {
                                showingAIResponse = false
                            }
                        }
                    }
                }
            } catch {
                print("Companion error: \(error)")
                await MainActor.run { isProcessing = false }
            }
        }
    }
}

// MARK: - Helper Extension
extension Optional where Wrapped == [String] {
    var isEmptyOrNil: Bool {
        self?.isEmpty ?? true
    }
}

struct ChatBubble: View {
    let text: String
    let isUser: Bool
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            Text(text)
                .padding()
                .background(isUser ? Color.clipCookSurface : Color.clipCookSizzleStart.opacity(0.2))
                .foregroundColor(.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isUser ? Color.clear : Color.clipCookSizzleStart, lineWidth: 1)
                )
            
            if !isUser { Spacer() }
        }
    }
}
