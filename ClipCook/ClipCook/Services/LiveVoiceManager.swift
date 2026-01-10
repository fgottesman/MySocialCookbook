import Foundation
import AVFoundation
import Combine
import Supabase

class LiveVoiceManager: NSObject, ObservableObject {
    static let shared = LiveVoiceManager()
    
    // connection state
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var isListening = false
    @Published var isSpeaking = false // AI is speaking
    @Published var errorMessage: String? // For UI alerts
    @Published var audioLevel: Float = 0.0 // 0.0 to 1.0 for mic input visualization
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var playerNode: AVAudioPlayerNode?
    private let audioQueue = DispatchQueue(label: "com.clipcook.audioQueue")
    
    // Audio formats
    // Gemini Live defaults: Input 16kHz, Output 24kHz
    private let inputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!
    private let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false)!
    
    override init() {
        super.init()
        setupNotifications()
        setupAudioSession()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotifications() {
        // Handle audio interruptions (phone calls, etc.)
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        
        // Handle route changes (headphones plugged/unplugged)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
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
    
    func connect(recipeId: String, versionId: String? = nil, initialStepIndex: Int) {
        print("🎙️ [LiveVoice] Starting connection... (Recipe: \(recipeId), Version: \(versionId ?? "original"))")
        
        self.errorMessage = nil
        self.isConnecting = true
        self.isConnected = false
        
        // Basic permission check
        checkMicrophonePermission { [weak self] granted in
            guard let self = self else { return }
            if !granted {
                self.errorMessage = "Please enable microphone access in Settings to talk to the Chef."
                self.isConnecting = false
                return
            }
            
            Task {
                await self.internalConnect(recipeId: recipeId, versionId: versionId, stepIndex: initialStepIndex)
            }
        }
    }
    
    private func internalConnect(recipeId: String, versionId: String?, stepIndex: Int) async {
        var wsUrlString = "\(AppConfig.wsEndpoint)/live-cooking?recipeId=\(recipeId)&stepIndex=\(stepIndex)"
        if let vId = versionId {
            wsUrlString += "&versionId=\(vId)"
        }

        guard let url = URL(string: wsUrlString) else {
            DispatchQueue.main.async { 
                self.errorMessage = "We couldn't reach the Chef. Check your connection."
                self.isConnecting = false
            }
            return
        }
        
        // Restore validation
        guard url.scheme == "wss" || url.scheme == "ws" else {
            DispatchQueue.main.async { 
                self.errorMessage = "Live Chef is temporarily resting. Try again in a bit!"
                self.isConnecting = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        // Add auth header if we have a session
        if let session = try? await SupabaseManager.shared.client.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        listen()
    }
    
    private func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            let permission = AVAudioApplication.shared.recordPermission
            switch permission {
            case .granted:
                completion(true)
            case .denied:
                completion(false)
            case .undetermined:
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async { completion(granted) }
                }
            @unknown default:
                completion(false)
            }
        } else {
            let permission = AVAudioSession.sharedInstance().recordPermission
            switch permission {
            case .granted:
                completion(true)
            case .denied:
                completion(false)
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async { completion(granted) }
                }
            @unknown default:
                completion(false)
            }
        }
    }
    
    func disconnect() {
        stopAudioEngine()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        isConnected = false
        isConnecting = false
        isListening = false
    }
    
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleMessage(message)
                
                // If this is the first message, we are connected
                if self.isConnecting {
                    DispatchQueue.main.async {
                        self.isConnecting = false
                        self.isConnected = true
                    }
                }
                
                self.listen() // Keep listening
            case .failure(let error):
                print("🎙️ [LiveVoice] ❌ WebSocket receive error: \(error)")
                print("🎙️ [LiveVoice] Error details: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.isConnecting = false
                }
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
        audioQueue.async { [weak self] in
            self?.startAudioEngineOrReport()
        }
    }
    
    private func startAudioEngineOrReport() {
        print("🎙️ [LiveVoice] Starting audio engine...")
        
        // CRITICAL: Must configure audio session BEFORE accessing audioEngine.inputNode
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            print("🎙️ [LiveVoice] ✅ Audio session activated")
            print("🎙️ [LiveVoice] Input available: \(session.isInputAvailable)")
            print("🎙️ [LiveVoice] Current route: \(session.currentRoute.inputs.first?.portName ?? "none")")
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
            
            DispatchQueue.main.async {
                self.isListening = true
            }
            
            print("🎙️ [LiveVoice] ✅ Audio engine started successfully")
            print("🎙️ [LiveVoice] Engine running: \(audioEngine.isRunning)")
            
            // Verify engine is actually running after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if self.audioEngine.isRunning {
                    print("🎙️ [LiveVoice] ✅ VERIFIED: Audio engine is running")
                } else {
                    print("🎙️ [LiveVoice] ❌ PROBLEM: Audio engine stopped unexpectedly")
                    self.errorMessage = "Audio stopped unexpectedly"
                }
            }
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
        
        // Enable Voice Processing (AEC) - CRITICAL to keep AI from hearing itself
        do {
            try inputNode.setVoiceProcessingEnabled(true)
            print("🎙️ [LiveVoice] ✅ Voice processing (AEC) enabled")
        } catch {
            print("🎙️ [LiveVoice] ⚠️ Could not enable voice processing: \(error)")
        }
        
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
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            if self.audioEngine.isRunning {
                 self.audioEngine.stop()
            }
            // Safely remove tap
            self.inputNode?.removeTap(onBus: 0)
            
            self.audioEngine.reset()
            DispatchQueue.main.async {
                self.isListening = false
            }
        }
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
        
        // Schedule buffer
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            if !(self.playerNode?.isPlaying ?? false) {
                 self.playerNode?.play()
            }
            self.playerNode?.scheduleBuffer(pcmBuffer, completionHandler: nil)
        }
        
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
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        if type == .began {
            print("🎙️ [LiveVoice] Audio interruption began")
            stopAudioEngine()
        } else if type == .ended {
            audioQueue.async { [weak self] in
                guard let self = self else { return }
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        print("🎙️ [LiveVoice] Audio interruption ended, resuming...")
                        self.startAudioEngineOrReport()
                    }
                }
            }
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        
        switch reason {
        case .newDeviceAvailable:
            print("🎙️ [LiveVoice] New audio device available")
        case .oldDeviceUnavailable:
            print("🎙️ [LiveVoice] Audio device unavailable, stopping...")
            stopAudioEngine()
        default:
            break
        }
    }
    
    // Helpers
    
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
