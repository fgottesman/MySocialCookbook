import Foundation
import AVFoundation
import Combine

class LiveVoiceManager: NSObject, ObservableObject {
    static let shared = LiveVoiceManager()
    
    // connection state
    @Published var isConnected = false
    @Published var isListening = false
    @Published var isSpeaking = false // AI is speaking
    @Published var errorMessage: String? // For UI alerts
    @Published var audioLevel: Float = 0.0 // 0.0 to 1.0 for mic input visualization
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var playerNode: AVAudioPlayerNode?
    
    // Audio formats
    // Gemini Live defaults: Input 16kHz, Output 24kHz
    private let inputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!
    private let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false)!
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // PlayAndRecord with VoiceChat is optimal for bi-directional VoIP
            // Note: allowBluetooth is deprecated for allowBluetoothHFP in newer SDKs, but allowBluetooth is the symbol we have access to generally.
            // We keep it as is if it compiles, or update if strict.
            // Warning said: renamed to 'AVAudioSession.CategoryOptions.allowBluetoothHFP'
            // We will try using the new name if possible, otherwise suppress.
            var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker]
            // We use the raw value for allowBluetooth (0x4) to support bluetooth headsets 
            // while avoiding the deprecation warning/error for 'allowBluetooth' -> 'allowBluetoothHFP' renaming.
            options.insert(AVAudioSession.CategoryOptions(rawValue: 0x4))
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
            self.errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
    
    func connect(recipeId: String, initialStepIndex: Int) {
        print("🎙️ [LiveVoice] Starting connection...")
        print("🎙️ [LiveVoice] Recipe ID: \(recipeId), Step: \(initialStepIndex)")
        
        self.errorMessage = nil // Clear previous errors
        
        // Basic permission check
        var isPermissionDenied = false
        if #available(iOS 17.0, *) {
            let permission = AVAudioApplication.shared.recordPermission
            print("🎙️ [LiveVoice] Mic permission (iOS 17+): \(permission.rawValue)")
            if permission == .denied {
                isPermissionDenied = true
            }
        } else {
            let permission = AVAudioSession.sharedInstance().recordPermission
            print("🎙️ [LiveVoice] Mic permission: \(permission.rawValue)")
            if permission == .denied {
                 isPermissionDenied = true
            }
        }
        
        if isPermissionDenied {
            print("🎙️ [LiveVoice] ❌ Microphone permission DENIED")
            self.errorMessage = "Microphone access is denied. Please enable it in Settings."
            return
        }
        
        // Build WebSocket URL - MUST use wss:// scheme, not https://
        let wsUrlString = "\(AppConfig.wsEndpoint)/live-cooking?recipeId=\(recipeId)&stepIndex=\(initialStepIndex)"
        print("🎙️ [LiveVoice] WebSocket URL: \(wsUrlString)")
        
        guard let url = URL(string: wsUrlString) else {
            print("🎙️ [LiveVoice] ❌ Failed to create URL from string")
            self.errorMessage = "Invalid connection URL"
            return
        }
        
        // Validate the URL has a WebSocket scheme
        print("🎙️ [LiveVoice] URL scheme: \(url.scheme ?? "nil")")
        guard url.scheme == "wss" || url.scheme == "ws" else {
            self.errorMessage = "Live Chef is not available right now. Please try again later."
            print("🎙️ [LiveVoice] ❌ Invalid scheme '\(url.scheme ?? "nil")'. Expected 'wss' or 'ws'.")
            return
        }
        
        print("🎙️ [LiveVoice] ✅ URL validation passed, creating WebSocket task...")
        
        // Create WebSocket connection
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        
        webSocketTask = session.webSocketTask(with: url)
        print("🎙️ [LiveVoice] WebSocket task created, resuming...")
        webSocketTask?.resume()
        
        listen()
        print("🎙️ [LiveVoice] Now listening for messages...")
    }
    
    func disconnect() {
        stopAudioEngine()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        isConnected = false
        isListening = false
    }
    
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.listen() // Keep listening
            case .failure(let error):
                print("🎙️ [LiveVoice] ❌ WebSocket receive error: \(error)")
                print("🎙️ [LiveVoice] Error details: \(error.localizedDescription)")
                self.isConnected = false
                // Only show error if we didn't intentionally disconnect
                if self.webSocketTask?.state != .completed && self.webSocketTask?.state != .canceling {
                    DispatchQueue.main.async {
                        self.errorMessage = "Connection lost: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            print("🎙️ [LiveVoice] 📥 Received audio data: \(data.count) bytes")
            self.playAudioData(data)
        case .string(let text):
            // JSON control messages (tools, etc.)
            print("🎙️ [LiveVoice] 📥 Received text: \(text.prefix(200))...")
        @unknown default:
            print("🎙️ [LiveVoice] ⚠️ Unknown message type received")
            break
        }
    }
    
    // MARK: - Audio Engine
    
    func startSession() {
        // Check permission
        if #available(iOS 17.0, *) {
            if AVAudioApplication.shared.recordPermission != .granted {
                AVAudioApplication.requestRecordPermission { granted in
                     if granted {
                         self.dispatchStartEngine()
                     } else {
                         DispatchQueue.main.async { self.errorMessage = "Microphone permission denied." }
                     }
                }
            } else {
                dispatchStartEngine()
            }
        } else {
            if AVAudioSession.sharedInstance().recordPermission != .granted {
                 AVAudioSession.sharedInstance().requestRecordPermission { granted in
                     if granted {
                         self.dispatchStartEngine()
                     } else {
                         DispatchQueue.main.async { self.errorMessage = "Microphone permission denied." }
                     }
                 }
            } else {
                dispatchStartEngine()
            }
        }
    }
    
    private func dispatchStartEngine() {
        DispatchQueue.main.async { self.startAudioEngineOrReport() }
    }
    
    private func startAudioEngineOrReport() {
        print("🎙️ [LiveVoice] Starting audio engine...")
        
        // CRITICAL: Must configure audio session BEFORE accessing audioEngine.inputNode
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            print("🎙️ [LiveVoice] ✅ Audio session activated")
        } catch {
            print("🎙️ [LiveVoice] ❌ Audio session setup failed: \(error)")
            self.errorMessage = "Could not configure audio: \(error.localizedDescription)"
            self.disconnect()
            return
        }
        
        // Now setup the engine after session is active
        let setupSuccess = setupAudioEngine()
        guard setupSuccess else {
            print("🎙️ [LiveVoice] ❌ Audio engine setup failed")
            self.errorMessage = "Could not setup audio. Please try again."
            self.disconnect()
            return
        }
        
        do {
            try audioEngine.start()
            playerNode?.play()
            isListening = true
            print("🎙️ [LiveVoice] ✅ Audio engine started successfully")
        } catch {
            print("🎙️ [LiveVoice] ❌ Audio engine start error: \(error)")
            self.errorMessage = "Failed to start audio: \(error.localizedDescription)"
            self.disconnect()
        }
    }
    
    private func setupAudioEngine() -> Bool {
        print("🎙️ [LiveVoice] Setting up audio engine...")
        
        // Stop engine if running
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Get input node
        let inputNode = audioEngine.inputNode
        self.inputNode = inputNode
        
        // Remove any existing taps
        inputNode.removeTap(onBus: 0)
        
        // Create and attach player node
        let playerNode = AVAudioPlayerNode()
        self.playerNode = playerNode
        audioEngine.attach(playerNode)
        
        // Connect player to output using output format (24kHz for Gemini output)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: outputFormat)
        
        // Get native input format
        let nativeFormat = inputNode.inputFormat(forBus: 0)
        print("🎙️ [LiveVoice] Native input format: \(nativeFormat.sampleRate)Hz, \(nativeFormat.channelCount) channels, \(nativeFormat.commonFormat.rawValue)")
        
        // Validate format
        guard nativeFormat.sampleRate > 0 else {
            print("🎙️ [LiveVoice] ❌ Invalid native sample rate: 0")
            return false
        }
        
        // Create converter from native format to Gemini's expected format (16kHz, 16-bit PCM, mono)
        guard let converter = AVAudioConverter(from: nativeFormat, to: inputFormat) else {
            print("🎙️ [LiveVoice] ❌ Could not create audio converter")
            return false
        }
        
        print("🎙️ [LiveVoice] Created converter: \(nativeFormat.sampleRate)Hz -> 16000Hz")
        
        var audioSendCount = 0
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Calculate audio level from the raw buffer for UI visualization
            if let floatData = buffer.floatChannelData {
                let channelData = floatData[0]
                let frameLength = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<frameLength {
                    let sample = channelData[i]
                    sum += sample * sample
                }
                let rms = sqrt(sum / Float(frameLength))
                let level = min(1.0, rms * 5.0) // Scale up for visibility
                DispatchQueue.main.async {
                    self.audioLevel = level
                }
            }
            
            // Calculate output buffer size based on sample rate ratio
            let ratio = 16000.0 / nativeFormat.sampleRate
            let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: self.inputFormat, frameCapacity: outputFrameCount) else {
                return
            }
            
            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            if status == .error {
                if audioSendCount == 0 {
                    print("🎙️ [LiveVoice] ❌ Conversion error: \(error?.localizedDescription ?? "unknown")")
                }
                return
            }
            
            // Convert to Data and send
            if let data = self.pcmBufferToData(buffer: outputBuffer) {
                audioSendCount += 1
                if audioSendCount == 1 || audioSendCount % 50 == 0 {
                    print("🎙️ [LiveVoice] 📤 Sending audio chunk #\(audioSendCount): \(data.count) bytes")
                }
                self.sendAudio(data)
            }
        }
        
        print("🎙️ [LiveVoice] ✅ Audio engine setup complete")
        return true
    }
    
    // Convert 16-bit PCM buffer to Data
    private func pcmBufferToData(buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData else { return nil }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return nil }
        return Data(bytes: channelData.pointee, count: frameLength * 2)
    }
    
    private func stopAudioEngine() {
        if audioEngine.isRunning {
             audioEngine.stop()
        }
        // Safely remove tap
        inputNode?.removeTap(onBus: 0)
        
        audioEngine.reset()
        isListening = false
    }
    
    // MARK: - audio data handling
    
    private func sendAudio(_ data: Data) {
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Error sending audio: \(error)")
            }
        }
    }
    
    private func playAudioData(_ data: Data) {
        // simple PCM playback
        guard let pcmBuffer = toPCMBuffer(data: data) else { return }
        
        if !(playerNode?.isPlaying ?? false) {
             playerNode?.play()
        }
        
        // Schedule buffer
        // Note: For real low latency we might need more advanced handling, but this is a start
        playerNode?.scheduleBuffer(pcmBuffer, completionHandler: nil)
        
        DispatchQueue.main.async {
            self.isSpeaking = true
            // Simple timeout for visual "isSpeaking" state
            // In a real app we'd track buffer completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
              if self.playerNode?.isPlaying == false {
                  self.isSpeaking = false
              }
            }
        }
    }
    
    // Helpers
    
    // Convert native float buffer to Data (for sending to backend)
    private func bufferToData(buffer: AVAudioPCMBuffer) -> Data? {
        // Native iOS mic format is typically float32
        if let floatData = buffer.floatChannelData {
            let channelDataPointer = floatData.pointee
            let byteCount = Int(buffer.frameLength) * MemoryLayout<Float>.size
            return Data(bytes: channelDataPointer, count: byteCount)
        }
        // Fallback for int16 format
        if let int16Data = buffer.int16ChannelData {
            let channelDataPointer = int16Data.pointee
            return Data(bytes: channelDataPointer, count: Int(buffer.frameLength) * 2)
        }
        return nil
    }
    
    private func toData(buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData else { return nil }
        let channelDataPointer = channelData.pointee
        return Data(bytes: channelDataPointer, count: Int(buffer.frameLength) * 2)
    }
    
    private func toPCMBuffer(data: Data) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(data.count) / 2
        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return nil }
        
        buffer.frameLength = frameCount
        let channelData = buffer.int16ChannelData
        
        data.withUnsafeBytes { (body: UnsafeRawBufferPointer) in
            if let bodyAddress = body.baseAddress, let channelData = channelData {
                channelData.pointee.update(from: bodyAddress.assumingMemoryBound(to: Int16.self), count: Int(frameCount))
            }
        }
        return buffer
    }
}

extension LiveVoiceManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("🎙️ [LiveVoice] ✅ WebSocket CONNECTED! Protocol: \(`protocol` ?? "none")")
        DispatchQueue.main.async {
            self.isConnected = true
            self.startSession() // Start audio once connected
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "no reason"
        print("🎙️ [LiveVoice] ⚠️ WebSocket CLOSED. Code: \(closeCode.rawValue), Reason: \(reasonString)")
        DispatchQueue.main.async {
            self.isConnected = false
            self.stopAudioEngine()
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("🎙️ [LiveVoice] ❌ URLSession task failed: \(error)")
            print("🎙️ [LiveVoice] Error domain: \((error as NSError).domain)")
            print("🎙️ [LiveVoice] Error code: \((error as NSError).code)")
            DispatchQueue.main.async {
                self.errorMessage = "Connection failed: \(error.localizedDescription)"
                self.isConnected = false
            }
        }
    }
}
