import Foundation
import Speech
import AVFoundation

class AppleSpeechService: ObservableObject {
    @Published var transcript: String = ""
    @Published var isListening: Bool = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startListening() {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("AppleSpeechService: Recognizer not available")
            return
        }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AppleSpeechService: Audio session error: \(error)")
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            transcript = ""
        } catch {
            print("AppleSpeechService: Engine start error: \(error)")
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async {
                    self.stopListening()
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    /// One-shot: record for a duration, return transcript
    func transcribeFromAudio(_ audioData: Data) async -> String? {
        // Apple Speech can also recognize from audio files
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("speech_\(UUID().uuidString).m4a")
        do {
            try audioData.write(to: tempURL)
            guard let recognizer = recognizer, recognizer.isAvailable else { return nil }

            let request = SFSpeechURLRecognitionRequest(url: tempURL)
            let result = try await recognizer.recognitionTask(with: request)
            try? FileManager.default.removeItem(at: tempURL)
            return result.bestTranscription.formattedString
        } catch {
            print("AppleSpeechService: File transcription error: \(error)")
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
    }
}

// Helper to make SFSpeechRecognizer async-compatible
extension SFSpeechRecognizer {
    func recognitionTask(with request: SFSpeechRecognitionRequest) async throws -> SFSpeechRecognitionResult {
        try await withCheckedThrowingContinuation { continuation in
            recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result, result.isFinal {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}
