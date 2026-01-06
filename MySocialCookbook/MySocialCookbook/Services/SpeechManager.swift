
import Foundation
import AVFoundation
import Combine

class SpeechManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let shared = SpeechManager()
    
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    private let synthesizer = AVSpeechSynthesizer()
    
    private let backendUrl = "https://mysocialcookbook-production.up.railway.app/api/transcribe-audio"
    
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var isTranscribing = false
    @Published var permissionGranted = false
    
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
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: audioFileURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.transcript = "Listening..."
            }
            print("Recording started")
        } catch {
            print("Error starting recording: \(error)")
        }
    }
    
    func stopRecording() async -> String? {
        audioRecorder?.stop()
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.isTranscribing = true
            self.transcript = "Transcribing..."
        }
        
        guard let fileURL = audioFileURL else {
            DispatchQueue.main.async { self.isTranscribing = false }
            return nil
        }
        
        do {
            // Read audio file and convert to base64
            let audioData = try Data(contentsOf: fileURL)
            let base64Audio = audioData.base64EncodedString()
            
            // Send to backend for Gemini transcription
            let transcript = try await transcribeWithGemini(audioBase64: base64Audio)
            
            DispatchQueue.main.async {
                self.transcript = transcript
                self.isTranscribing = false
            }
            
            // Cleanup temp file
            try? FileManager.default.removeItem(at: fileURL)
            
            return transcript
        } catch {
            print("Error processing audio: \(error)")
            DispatchQueue.main.async {
                self.transcript = "Error transcribing"
                self.isTranscribing = false
            }
            return nil
        }
    }
    
    private func transcribeWithGemini(audioBase64: String) async throws -> String {
        guard let url = URL(string: backendUrl) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "audioBase64": audioBase64,
            "mimeType": "audio/mp4" // m4a is mp4 audio
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        struct TranscribeResponse: Codable {
            let success: Bool
            let transcript: String
        }
        
        let decoded = try JSONDecoder().decode(TranscribeResponse.self, from: data)
        return decoded.transcript
    }
    
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        // Configure audio session for playback
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        synthesizer.speak(utterance)
    }
}
