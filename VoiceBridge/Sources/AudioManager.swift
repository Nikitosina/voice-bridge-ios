import SwiftUI
import AVFoundation

enum BridgeState: Equatable {
    case idle
    case connecting
    case listening
    case processing(stt: String?)
    case speaking
    case error(String)
    
    var label: String {
        switch self {
        case .idle: return "Нажми звонок"
        case .connecting: return "Соединение..."
        case .listening: return "Слушаю 👂"
        case .processing(let stt): return stt != nil ? "Услышал: \(stt!)" : "Думаю..."
        case .speaking: return "Говорю 🗣"
        case .error(let msg): return "Ошибка: \(msg)"
        }
    }
    
    var color: Color {
        switch self {
        case .idle: return .gray
        case .connecting: return .orange
        case .listening: return .red
        case .processing: return .blue
        case .speaking: return .green
        case .error: return .red
        }
    }
}

class AudioManager: NSObject, ObservableObject {
    @Published var state: BridgeState = .idle
    
    // MARK: — WebSocket
    private var webSocketTask: URLSessionWebSocketTask?
    // ЗАМЕНИ IP НА IP ТВОЕГО МАКА В ЛОКАЛЬНОЙ СЕТИ
    private let serverURL = URL(string: "ws://192.168.1.x:8765/ws")!
    
    // MARK: — Mic (Record)
    private var micEngine = AVAudioEngine()
    private let micFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    
    // MARK: — Playback (Speaker)
    private var playbackEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private let playbackFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 22050, channels: 1, interleaved: false)!
    
    // MARK: — VAD state
    private var isRecordingVoice = false
    private var silenceTimer: Timer?
    private let silenceThreshold: Float = 0.015
    private let silenceDuration = 1.2

    func connect() {
        state = .connecting
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: serverURL)
        webSocketTask?.delegate = self
        webSocketTask?.resume()
        receiveMessage()
    }
    
    func disconnect() {
        Task { [weak self] in
            self?.stopMic()
            self?.stopPlayback()
            self?.webSocketTask?.cancel(with: .goingAway, reason: nil)
            self?.webSocketTask = nil
            await MainActor.run { self?.state = .idle }
        }
    }
    
    // MARK: — Mic Lifecycle
    
    private func startMic() {
        let inputNode = micEngine.inputNode
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: micFormat) { [weak self] buffer, _ in
            self?.processMicBuffer(buffer)
        }
        do {
            micEngine.prepare()
            try micEngine.start()
            state = .listening
        } catch {
            state = .error("Mic: \(error.localizedDescription)")
        }
    }
    
    private func stopMic() {
        micEngine.inputNode.removeTap(onBus: 0)
        micEngine.stop()
        silenceTimer?.invalidate()
        isRecordingVoice = false
    }
    
    // MARK: — Playback Lifecycle
    
    private func startPlayback() {
        playbackEngine.attach(playerNode)
        let mixer = playbackEngine.mainMixerNode
        playbackEngine.connect(playerNode, to: mixer, format: playbackFormat)
        playerNode.volume = 1.0
        do {
            playbackEngine.prepare()
            try playbackEngine.start()
            playerNode.play()
        } catch {
            state = .error("Playback: \(error.localizedDescription)")
        }
    }
    
    private func stopPlayback() {
        playerNode.stop()
        playbackEngine.stop()
        playbackEngine.detach(playerNode)
        // Пересоздаём чистый на следующий цикл
        playerNode = AVAudioPlayerNode()
        playbackEngine.reset()
    }
    
    // MARK: — VAD + Audio Streaming
    
    private func processMicBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        
        // RMS
        var sum: Float = 0
        for i in 0..<frames { sum += channelData[i] * channelData[i] }
        let rms = sqrt(sum / Float(frames))
        
        if rms > silenceThreshold {
            if !isRecordingVoice {
                isRecordingVoice = true
            }
            silenceTimer?.invalidate()
        } else {
            if isRecordingVoice {
                silenceTimer?.invalidate()
                silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceDuration, repeats: false) { [weak self] _ in
                    self?.finishUtterance()
                }
            }
        }
        
        // Шлём сырой PCM f32 на сервер (сервер сам накопит)
        let data = Data(bytes: channelData, count: frames * MemoryLayout<Float>.size)
        sendBinary(data)
    }
    
    private func finishUtterance() {
        guard isRecordingVoice else { return }
        isRecordingVoice = false
        stopMic()
        state = .processing(stt: nil)
        sendText("{\"type\":\"utterance_end\"}")
        startPlayback()
    }
    
    // MARK: — WebSocket Helpers
    
    private func sendText(_ string: String) {
        let msg = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(msg) { _ in }
    }
    
    private func sendBinary(_ data: Data) {
        let msg = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(msg) { _ in }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async { self.state = .error("WS: \(error.localizedDescription)") }
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleTextMessage(text)
                case .data(let data):
                    self.enqueueAudio(data)
                @unknown default: break
                }
                self.receiveMessage()
            }
        }
    }
    
    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch type {
            case "processing":
                let stt = json["stt"] as? String
                self.state = .processing(stt: stt)
            case "done_speaking":
                // Цикл завершён — возвращаемся к слушанию
                self.stopPlayback()
                self.startMic()
            default: break
            }
        }
    }
    
    private func enqueueAudio(_ data: Data) {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: playbackFormat,
                                            frameCapacity: AVAudioFrameCount(data.count / 2)) else { return }
        buffer.frameLength = buffer.frameCapacity
        data.withUnsafeBytes { raw in
            guard let ptr = raw.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            if let dst = buffer.int16ChannelData?[0] {
                memcpy(dst, ptr, data.count)
            }
        }
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
}

extension AudioManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.startMic()
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if let err = error {
                self?.state = .error("Conn: \(err.localizedDescription)")
            } else {
                self?.state = .idle
            }
        }
    }
}
