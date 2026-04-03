import Foundation

class VideoGenerationService {
    private let falKey: String
    private let endpoint = "fal-ai/bytedance/seedance/v1/pro/image-to-video"

    init(falKey: String) {
        self.falKey = falKey
    }

    /// Generate a cinematic video from an image URL + motion prompt
    func generateVideo(fromImageURL imageURL: URL, motionPrompt: String, onProgress: @escaping (String) -> Void) async throws -> URL {
        // 1. Submit
        let requestId = try await submit(imageURL: imageURL, motionPrompt: motionPrompt)
        print("VideoGenerationService: Submitted, request_id = \(requestId)")
        onProgress("Video generation started...")

        // 2. Poll (video gen takes 1-3 minutes)
        try await pollUntilComplete(requestId: requestId, onProgress: onProgress)

        // 3. Get result
        let videoURL = try await fetchResult(requestId: requestId)
        print("VideoGenerationService: Video ready at \(videoURL)")
        onProgress("Video ready!")
        return videoURL
    }

    // MARK: - Fal.ai queue pattern

    private func submit(imageURL: URL, motionPrompt: String) async throws -> String {
        let url = URL(string: "https://queue.fal.run/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Key \(falKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "prompt": motionPrompt,
            "image_url": imageURL.absoluteString
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("VideoGenerationService: Submit error \(http.statusCode): \(errorBody)")
            throw AppError.networkError("Video submit failed (\(http.statusCode))")
        }

        let queueResponse = try JSONDecoder().decode(FalQueueResponse.self, from: data)
        return queueResponse.request_id
    }

    private func pollUntilComplete(requestId: String, onProgress: @escaping (String) -> Void) async throws {
        let url = URL(string: "https://queue.fal.run/\(endpoint)/requests/\(requestId)/status")!
        var request = URLRequest(url: url)
        request.setValue("Key \(falKey)", forHTTPHeaderField: "Authorization")

        var pollCount = 0
        while true {
            let (data, _) = try await URLSession.shared.data(for: request)
            let status = try JSONDecoder().decode(FalStatus.self, from: data)

            pollCount += 1
            let elapsed = pollCount * 5
            print("VideoGenerationService: Poll #\(pollCount) status = \(status.status)")

            switch status.status {
            case "COMPLETED":
                return
            case "FAILED":
                throw AppError.generationFailed
            default:
                onProgress("Generating video... \(elapsed)s elapsed")
                try await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    private func fetchResult(requestId: String) async throws -> URL {
        let url = URL(string: "https://queue.fal.run/\(endpoint)/requests/\(requestId)")!
        var request = URLRequest(url: url)
        request.setValue("Key \(falKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(SeedanceResult.self, from: data)

        guard let videoURL = URL(string: result.video.url) else {
            throw AppError.generationFailed
        }

        return videoURL
    }
}
