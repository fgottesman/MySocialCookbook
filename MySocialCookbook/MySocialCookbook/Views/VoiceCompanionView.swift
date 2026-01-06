
import SwiftUI

struct VoiceCompanionView: View {
    let recipe: Recipe
    
    // CURRENTLY, we don't track steps accurately in scrolling view, 
    // so we pass 0 or maybe allow manual step selection later. 
    // For MVP, we pass 0 (general context).
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
                        
                        // Live Transcript
                        if !speechManager.transcript.isEmpty && speechManager.isListening {
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
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .clipCookSizzleStart))
                            .scaleEffect(1.5)
                        Text("Thinking...")
                            .font(.caption)
                            .foregroundColor(.clipCookTextSecondary)
                    } else {
                        Button(action: toggleListening) {
                            ZStack {
                                Circle()
                                    .fill(speechManager.isListening ? LinearGradient.sizzle : LinearGradient(colors: [.clipCookSurface, .clipCookSurface], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 80, height: 80)
                                    .shadow(color: speechManager.isListening ? .clipCookSizzleStart.opacity(0.5) : .clear, radius: 20)
                                
                                Image(systemName: speechManager.isListening ? "waveform" : "mic.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Text(speechManager.isListening ? "Tap to Stop" : "Tap to Speak")
                            .font(.headline)
                            .foregroundColor(.clipCookTextSecondary)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            speechManager.requestPermissions()
            // Initial greeting? 
            // maybe not, let user initiate
        }
        .onDisappear {
            speechManager.stopListening()
        }
    }
    
    func toggleListening() {
        if speechManager.isListening {
            stopAndSend()
        } else {
            do {
                try speechManager.startListening()
            } catch {
                print("Error starting speech: \(error)")
            }
        }
    }
    
    func stopAndSend() {
        speechManager.stopListening()
        let text = speechManager.transcript
        
        guard !text.isEmpty && text != "Listening..." else { return }
        
        // Add User Message
        let userMsg = ChatMessage(role: "user", content: text)
        chatHistory.append(userMsg)
        
        isProcessing = true
        
        Task {
            do {
                let reply = try await VoiceCompanionService.shared.chat(
                    recipe: recipe,
                    currentStepIndex: currentStepIndex,
                    history: chatHistory,
                    message: text
                )
                
                await MainActor.run {
                    isProcessing = false
                    // Add AI Message
                    let aiMsg = ChatMessage(role: "ai", content: reply)
                    chatHistory.append(aiMsg)
                    
                    // Speak it
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
