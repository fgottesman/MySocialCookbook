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
        self.errorMessage = nil // Clear previous errors
        
        // Basic permission check
        // Basic permission check
        // Basic permission check
        var isPermissionDenied = false
        if #available(iOS 17.0, *) {
            if AVAudioApplication.shared.recordPermission == .denied {
                isPermissionDenied = true
            }
        } else {
            if AVAudioSession.sharedInstance().recordPermission == .denied {
                 isPermissionDenied = true
            }
        }
        
        if isPermissionDenied {
            self.errorMessage = "Microphone access is denied. Please enable it in Settings."
            return
        }
        
        guard let url = URL(string: "\(AppConfig.wsEndpoint)/live-cooking?recipeId=\(recipeId)&stepIndex=\(initialStepIndex)") else {
            self.errorMessage = "Invalid connection URL"
            return
        }
        // Note: URLSession automatically handles ws/wss upgrade from http/https
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue.main)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        listen()
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
                print("WebSocket receive error: \(error)")
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
            // Binary data is usually audio PCM
            self.playAudioData(data)
        case .string(let text):
            // JSON control messages (tools, etc.)
            print("Received text from Gemini: \(text)")
        @unknown default:
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
        setupAudioEngine()
        do {
            try audioEngine.start()
            playerNode?.play()
            isListening = true
        } catch {
            print("Audio Engine Start Error: \(error)")
            self.errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            self.disconnect()
        }
    }
    
    private func setupAudioEngine() {
        // Re-init engine components to be safe
        let inputNode = audioEngine.inputNode
        let playerNode = AVAudioPlayerNode()
        self.playerNode = playerNode
        self.inputNode = inputNode
        
        // Ensure no existing tap causes a crash
        inputNode.removeTap(onBus: 0)
        
        // Attach and Connect
        if audioEngine.attachedNodes.contains(playerNode) {
            audioEngine.detach(playerNode)
        }
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: outputFormat)
        
        // Prepare format conversion
        let nativeFormat = inputNode.inputFormat(forBus: 0)
        
        // Prevent crash if sample rate is 0 (engine invalid state)
        if nativeFormat.sampleRate == 0 {
            print("Error: Input node has invalid sample rate (0)")
            return
        }

        guard let formatConverter = AVAudioConverter(from: nativeFormat, to: inputFormat) else {
            print("Could not create audio converter")
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Convert to 16kHz
            let targetFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * (16000.0 / buffer.format.sampleRate))
            if let outputBuffer = AVAudioPCMBuffer(pcmFormat: self.inputFormat, frameCapacity: targetFrameCapacity) {
                var error: NSError? = nil
                formatConverter.convert(to: outputBuffer, error: &error) { packetCount, status in
                    status.pointee = .haveData
                    return buffer
                }
                
                if let data = self.toData(buffer: outputBuffer) {
                    self.sendAudio(data)
                }
            }
        }
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
        print("WebSocket Connected")
        DispatchQueue.main.async {
            self.isConnected = true
            self.startSession() // Start audio once connected
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket Closed")
        DispatchQueue.main.async {
            self.isConnected = false
            self.stopAudioEngine()
        }
    }
}
