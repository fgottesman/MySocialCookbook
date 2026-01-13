
import Foundation
import AVFoundation
import Combine

class SpeechManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let shared = SpeechManager()
    
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    
    private let backendUrl = "\(AppConfig.apiEndpoint)/ai/transcribe"
    private let ttsUrl = "\(AppConfig.apiEndpoint)/ai/synthesize"
    
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var isTranscribing = false
    @Published var permissionGranted = false
    @Published var preferredVoiceIdentifier: String?
    @Published var isSynthesizing = false
    @Published var isMuted = false
    
    // Configurable delay before speaking on step change (in seconds)
    static var stepIntroductionDelay: TimeInterval = 0.0
    
    var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
    }
    
    override init() {
        super.init()
    }
    
    func requestPermissions() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.permissionGranted = granted
                print("Microphone permission: \(granted)")
            }
        }
    }
    
    func startRecording() {
        // Create temp file for audio
        let tempDir = FileManager.default.temporaryDirectory
        audioFileURL = tempDir.appendingPathComponent("voice_recording.m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: audioFileURL!, settings: settings)
            audioRecorder?.isMeteringEnabled = true // Enable metering
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            startMonitoring() // Start timer
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.transcript = "Listening..."
            }
            print("Recording started")
        } catch {
            print("Error starting recording: \(error)")
        }
    }
    
    private var timer: Timer?
    @Published var audioLevel: Float = 0.0
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.audioRecorder?.updateMeters()
            // Normalize level from -160..0 to 0..1
            let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
            let level = max(0.0, (power + 50) / 50) // Show changes from -50dB upwards
            
            DispatchQueue.main.async {
                self.audioLevel = level
            }
        }
    }
    
    func stopRecording() async -> String? {
        print("DEBUG: stopRecording called")
        timer?.invalidate() // Stop monitoring
        audioLevel = 0
        audioRecorder?.stop()
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.isTranscribing = true
            self.transcript = "Transcribing..."
        }
        
        guard let fileURL = audioFileURL else {
            print("DEBUG: No audioFileURL")
            DispatchQueue.main.async { self.isTranscribing = false }
            return nil
        }
        
        // Check file existence and size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? UInt64 {
            print("DEBUG: Audio file exists at \(fileURL.path), size: \(size) bytes")
            if size == 0 {
                print("DEBUG: Audio file is empty!")
                DispatchQueue.main.async { self.isTranscribing = false }
                return nil
            }
        } else {
            print("DEBUG: Audio file does not exist or attributes unreadable")
        }
        
        do {
            // Read audio file and convert to base64
            print("DEBUG: Reading audio data...")
            let audioData = try Data(contentsOf: fileURL)
            let base64Audio = audioData.base64EncodedString()
            print("DEBUG: Base64 string length: \(base64Audio.count)")
            
            // Send to backend for Gemini transcription
            print("DEBUG: Sending request to backend...")
            let transcript = try await transcribeWithGemini(audioBase64: base64Audio)
            print("DEBUG: Transcription received: \(transcript)")
            
            DispatchQueue.main.async {
                self.transcript = transcript
                self.isTranscribing = false
            }
            
            // Cleanup temp file
            try? FileManager.default.removeItem(at: fileURL)
            
            return transcript
        } catch {
            print("DEBUG: Error in stopRecording: \(error)")
            DispatchQueue.main.async {
                self.transcript = "Error transcribing: \(error.localizedDescription)"
                self.isTranscribing = false
            }
            return nil
        }
    }
    
    private func transcribeWithGemini(audioBase64: String) async throws -> String {
        print("DEBUG: transcribeWithGemini start")
        guard let url = URL(string: backendUrl) else {
            print("DEBUG: Invalid URL: \(backendUrl)")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "audioBase64": audioBase64,
            "mimeType": "audio/mp4"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("DEBUG: JSON Serialization failed: \(error)")
            throw error
        }
        
        print("DEBUG: Sending request to \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("DEBUG: HTTP Status Code: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                let bodyString = String(data: data, encoding: .utf8) ?? "Unable to decode body"
                print("DEBUG: Response Body: \(bodyString)")
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        struct TranscribeResponse: Codable {
            let success: Bool
            let transcript: String
        }
        
        do {
            let decoded = try JSONDecoder().decode(TranscribeResponse.self, from: data)
            return decoded.transcript
        } catch {
            print("DEBUG: JSON Decoding failed: \(error)")
            let bodyString = String(data: data, encoding: .utf8) ?? "Unable to decode body"
            print("DEBUG: Raw Response: \(bodyString)")
            throw error
        }
    }
    
    func speak(_ text: String) {
        // Check mute status
        guard !isMuted else {
            print("DEBUG: Speech muted, skipping TTS")
            return
        }
        
        // High quality cloud voice via Gemini TTS
        Task {
            DispatchQueue.main.async { self.isSynthesizing = true }
            if let audioBase64 = try? await synthesizeWithBackend(text: text) {
                if let audioData = Data(base64Encoded: audioBase64) {
                    await playAudio(data: audioData)
                    DispatchQueue.main.async { self.isSynthesizing = false }
                    return
                }
            }
            
            // Fallback to local synthesis if backend fails
            DispatchQueue.main.async { 
                self.isSynthesizing = false
                let utterance = AVSpeechUtterance(string: text)
                
                if let identifier = self.preferredVoiceIdentifier,
                   let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                    utterance.voice = voice
                } else {
                    let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
                    if let enhanced = voices.first(where: { $0.quality == .enhanced }) {
                        utterance.voice = enhanced
                    } else {
                        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                    }
                }
                
                utterance.rate = 0.5
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt)
                try? AVAudioSession.sharedInstance().setActive(true)
                self.synthesizer.speak(utterance)
            }
        }
    }
    
    private func synthesizeWithBackend(text: String) async throws -> String? {
        print("DEBUG: synthesizeWithBackend start")
        guard let url = URL(string: ttsUrl) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["text": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        
        struct SynthesizeResponse: Codable {
            let success: Bool
            let audioBase64: String
        }
        
        let decoded = try JSONDecoder().decode(SynthesizeResponse.self, from: data)
        return decoded.audioBase64
    }
    
    @MainActor
    func playAudio(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // For file URLs
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("DEBUG: Error playing audio from URL: \(error)")
        }
    }

    @MainActor
    private func playAudio(data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            print("DEBUG: Error playing audio: \(error)")
        }
    }
    
    func stopSpeaking() {
        audioPlayer?.stop()
        synthesizer.stopSpeaking(at: .immediate)
    }
}
