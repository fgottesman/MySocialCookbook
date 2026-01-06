
import SwiftUI

struct VoiceCompanionView: View {
    let recipe: Recipe
    
    @State private var currentStepIndex: Int = 0
    
    @StateObject private var speechManager = SpeechManager.shared
    @State private var chatHistory: [ChatMessage] = []
    @State private var isProcessing = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.clipCookBackground.ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Text("Sous Chef Mode")
                        .modifier(UtilityHeadline())
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.clipCookTextSecondary)
                    }
                }
                .padding()
                
                Spacer()
                
                // Chat Display
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(chatHistory.indices, id: \.self) { index in
                            let msg = chatHistory[index]
                            ChatBubble(
                                text: msg.content,
                                isUser: msg.role == "user"
                            )
                        }
                        
                        // Live Status
                        if !speechManager.transcript.isEmpty && (speechManager.isRecording || speechManager.isTranscribing) {
                            Text(speechManager.transcript)
                                .font(.title2)
                                .foregroundColor(.clipCookTextSecondary)
                                .italic()
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // Controls
                VStack(spacing: 20) {
                    if isProcessing || speechManager.isTranscribing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .clipCookSizzleStart))
                            .scaleEffect(1.5)
                        Text(speechManager.isTranscribing ? "Transcribing..." : "Thinking...")
                            .font(.caption)
                            .foregroundColor(.clipCookTextSecondary)
                    } else {
                        Button(action: toggleRecording) {
                            ZStack {
                                Circle()
                                    .fill(speechManager.isRecording ? LinearGradient.sizzle : LinearGradient(colors: [.clipCookSurface, .clipCookSurface], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 80, height: 80)
                                    .scaleEffect(speechManager.isRecording ? 1.0 + CGFloat(speechManager.audioLevel) * 0.5 : 1.0)
                                    .animation(.easeInOut(duration: 0.1), value: speechManager.audioLevel)
                                    .shadow(color: speechManager.isRecording ? .clipCookSizzleStart.opacity(0.5) : .clear, radius: 20)
                                
                                Image(systemName: speechManager.isRecording ? "waveform" : "mic.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Text(speechManager.isRecording ? "Tap to Stop" : "Tap to Speak")
                            .font(.headline)
                            .foregroundColor(.clipCookTextSecondary)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            speechManager.requestPermissions()
        }
    }
    
    func toggleRecording() {
        if speechManager.isRecording {
            stopAndSend()
        } else {
            speechManager.startRecording()
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
                    speechManager.speak(reply)
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
