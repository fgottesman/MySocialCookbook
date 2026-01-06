
import SwiftUI
import AVFoundation
import AVFAudio

struct VoiceCompanionView: View {
    let recipe: Recipe
    
    @State private var currentStepIndex: Int = 0
    
    @StateObject private var speechManager = SpeechManager.shared
    @State private var chatHistory: [ChatMessage] = []
    @State private var isProcessing = false
    @State private var showingAIResponse = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.clipCookBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
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
                    
                    // Voice Test Button
                    Menu {
                        ForEach(speechManager.availableVoices, id: \.identifier) { voice in
                            Button(action: {
                                speechManager.preferredVoiceIdentifier = voice.identifier
                                speechManager.speak("I am your Sous Chef. How do I sound?")
                            }) {
                                HStack {
                                    Text(voice.name)
                                    if voice.quality == .enhanced {
                                        Image(systemName: "sparkles")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.title2)
                            Text("Voice")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.clipCookSizzleStart.opacity(0.3))
                        .cornerRadius(12)
                        .padding(.trailing, 8)
                    }
                    
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.clipCookTextSecondary)
                    }
                }
                .padding()
                
                Spacer()
                
                // Main Step Content
                if let instructions = recipe.instructions, !instructions.isEmpty {
                    HStack(spacing: 20) {
                        // Back Arrow
                        Button(action: { navigateStep(by: -1) }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(currentStepIndex > 0 ? .white : .white.opacity(0.1))
                        }
                        .disabled(currentStepIndex == 0)
                        
                        // Step Text
                        VStack(spacing: 24) {
                            Text("STEP \(currentStepIndex + 1)")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.clipCookSizzleStart)
                                .tracking(2)
                            
                            ScrollView {
                                Text(instructions[currentStepIndex])
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(8)
                                    .padding(.horizontal)
                            }
                            .frame(maxHeight: 300)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Forward Arrow
                        Button(action: { navigateStep(by: 1) }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(currentStepIndex < instructions.count - 1 ? .white : .white.opacity(0.1))
                        }
                        .disabled(currentStepIndex == instructions.count - 1)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // AI Response / Transcription Overlay
                if !speechManager.transcript.isEmpty && (speechManager.isRecording || speechManager.isTranscribing) {
                    Text(speechManager.transcript)
                        .font(.headline)
                        .foregroundColor(.clipCookTextSecondary)
                        .italic()
                        .padding()
                        .background(Color.clipCookSurface.opacity(0.8))
                        .cornerRadius(12)
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
                        .transition(.opacity)
                }
                
                // Microphone Controls
                VStack(spacing: 16) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Thinking...")
                            .font(.caption)
                            .foregroundColor(.clipCookTextSecondary)
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
                            
                            Text("Tap and hold to ask questions")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.clipCookTextSecondary)
                                .opacity(speechManager.isRecording ? 0.5 : 1.0)
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            speechManager.requestPermissions()
        }
    }
    
    private func navigateStep(by delta: Int) {
        guard let instructions = recipe.instructions else { return }
        let newIndex = currentStepIndex + delta
        if newIndex >= 0 && newIndex < instructions.count {
            withAnimation {
                currentStepIndex = newIndex
            }
        }
    }
    
    func stopAndSend() {
        isProcessing = true
        
        Task {
            // Stop recording and get transcription via Gemini
            guard let text = await speechManager.stopRecording() else {
                await MainActor.run { isProcessing = false }
                return
            }
            
            guard !text.isEmpty && text != "Listening..." && text != "Transcribing..." else {
                await MainActor.run { isProcessing = false }
                return
            }
            
            // Add User Message
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
