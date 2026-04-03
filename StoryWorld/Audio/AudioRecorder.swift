import Foundation
import AVFoundation

class AudioRecorder: ObservableObject {
    @Published var isRecording = false

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    func setupSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("AudioRecorder: Failed to set up audio session: \(error)")
        }
    }

    func startRecording() {
        setupSession()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("storyworld_recording_\(UUID().uuidString).m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 24000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            print("AudioRecorder: Started recording to \(url.lastPathComponent)")
        } catch {
            print("AudioRecorder: Failed to start recording: \(error)")
        }
    }

    func stopRecording() -> Data? {
        guard let recorder = audioRecorder, recorder.isRecording else {
            print("AudioRecorder: Not currently recording")
            return nil
        }

        recorder.stop()
        isRecording = false

        guard let url = recordingURL else { return nil }

        do {
            let data = try Data(contentsOf: url)
            print("AudioRecorder: Recorded \(data.count) bytes (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))")
            // Clean up the temp file
            try? FileManager.default.removeItem(at: url)
            return data
        } catch {
            print("AudioRecorder: Failed to read recording data: \(error)")
            return nil
        }
    }
}
