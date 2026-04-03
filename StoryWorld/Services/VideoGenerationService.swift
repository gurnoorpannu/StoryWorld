import Foundation
import UIKit

class VideoGenerationService {
    private let apiKey: String
    private let baseURL = "https://api.minimax.io/v1"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// Generate a video from a UIImage + motion prompt using MiniMax Hailuo (no upload needed)
    func generateVideo(fromImage image: UIImage, motionPrompt: String, onProgress: @escaping (String) -> Void) async throws -> URL {
        // Convert image to base64 data URI
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            throw AppError.compressionFailed
        }
        let base64String = jpegData.base64EncodedString()
        let dataURI = "data:image/jpeg;base64,\(base64String)"

        // 1. Submit task
        let taskId = try await submitTask(imageString: dataURI, motionPrompt: motionPrompt)
        print("VideoGenerationService: Submitted, task_id = \(taskId)")
        onProgress("Video generation started...")

        // 2. Poll until complete (~10s intervals)
        let fileId = try await pollUntilComplete(taskId: taskId, onProgress: onProgress)
        print("VideoGenerationService: Task complete, file_id = \(fileId)")

        // 3. Retrieve download URL
        let videoURL = try await retrieveFile(fileId: fileId)
        print("VideoGenerationService: Video ready at \(videoURL)")
        onProgress("Video ready!")
        return videoURL
    }

    /// Generate a video from an image URL + motion prompt using MiniMax Hailuo
    func generateVideo(fromImageURL imageURL: URL, motionPrompt: String, onProgress: @escaping (String) -> Void) async throws -> URL {
        // 1. Submit task
        let taskId = try await submitTask(imageString: imageURL.absoluteString, motionPrompt: motionPrompt)
        print("VideoGenerationService: Submitted, task_id = \(taskId)")
        onProgress("Video generation started...")

        // 2. Poll until complete (~10s intervals)
        let fileId = try await pollUntilComplete(taskId: taskId, onProgress: onProgress)
        print("VideoGenerationService: Task complete, file_id = \(fileId)")

        // 3. Retrieve download URL
        let videoURL = try await retrieveFile(fileId: fileId)
        print("VideoGenerationService: Video ready at \(videoURL)")
        onProgress("Video ready!")
        return videoURL
    }

    // MARK: - MiniMax API

    private func submitTask(imageString: String, motionPrompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/video_generation")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "MiniMax-Hailuo-2.3",
            "prompt": motionPrompt,
            "first_frame_image": imageString,
            "duration": 6,
            "resolution": "1080P"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        let responseBody = String(data: data, encoding: .utf8) ?? "Unknown"
        print("VideoGenerationService: Submit response: \(responseBody)")

        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            print("VideoGenerationService: Submit error \(http.statusCode): \(responseBody)")
            throw AppError.networkError("Video submit failed (\(http.statusCode))")
        }

        let result = try JSONDecoder().decode(MiniMaxTaskResponse.self, from: data)

        guard let taskId = result.task_id, !taskId.isEmpty else {
            let errorMsg = result.base_resp?.status_msg ?? "No task_id returned"
            print("VideoGenerationService: API error: \(errorMsg)")
            throw AppError.networkError("MiniMax error: \(errorMsg)")
        }

        return taskId
    }

    private func pollUntilComplete(taskId: String, onProgress: @escaping (String) -> Void) async throws -> String {
        var urlComponents = URLComponents(string: "\(baseURL)/query/video_generation")!
        urlComponents.queryItems = [URLQueryItem(name: "task_id", value: taskId)]

        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var pollCount = 0
        while true {
            let (data, _) = try await URLSession.shared.data(for: request)
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            print("VideoGenerationService: Poll response: \(responseBody)")
            let status = try JSONDecoder().decode(MiniMaxQueryResponse.self, from: data)

            pollCount += 1
            let elapsed = pollCount * 10
            print("VideoGenerationService: Poll #\(pollCount) status = \(status.status)")

            switch status.status {
            case "Success":
                guard let fileId = status.file_id else {
                    throw AppError.generationFailed
                }
                return fileId
            case "Fail":
                let msg = status.error_message ?? "Unknown error"
                print("VideoGenerationService: Task failed: \(msg)")
                throw AppError.networkError("Video generation failed: \(msg)")
            default:
                onProgress("Generating video... \(elapsed)s elapsed")
                try await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }

    private func retrieveFile(fileId: String) async throws -> URL {
        var urlComponents = URLComponents(string: "\(baseURL)/files/retrieve")!
        urlComponents.queryItems = [URLQueryItem(name: "file_id", value: fileId)]

        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(MiniMaxFileResponse.self, from: data)

        guard let downloadURL = URL(string: result.file.download_url) else {
            throw AppError.generationFailed
        }

        return downloadURL
    }
}
