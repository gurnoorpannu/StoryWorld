import Foundation

class ImageEditService {
    private let falKey: String
    private let endpoint = "fal-ai/flux-2-pro/edit"

    init(falKey: String) {
        self.falKey = falKey
    }

    /// Stylize an image using Flux 2.0 Pro via fal.ai
    func stylizeFrame(
        imageURL: URL,
        stylePrompt: String = "Cinematic film still, dramatic lighting, shallow depth of field, 35mm film grain"
    ) async throws -> URL {
        // 1. Submit
        let requestId = try await submit(imageURL: imageURL, stylePrompt: stylePrompt)
        print("ImageEditService: Submitted, request_id = \(requestId)")

        // 2. Poll
        try await pollUntilComplete(requestId: requestId)

        // 3. Get result
        let styledURL = try await fetchResult(requestId: requestId)
        print("ImageEditService: Styled image at \(styledURL)")
        return styledURL
    }

    // MARK: - Fal.ai queue pattern

    private func submit(imageURL: URL, stylePrompt: String) async throws -> String {
        let url = URL(string: "https://queue.fal.run/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Key \(falKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "prompt": stylePrompt,
            "image_url": imageURL.absoluteString
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("ImageEditService: Submit error \(http.statusCode): \(errorBody)")
            throw AppError.networkError("Image stylization submit failed (\(http.statusCode))")
        }

        let queueResponse = try JSONDecoder().decode(FalQueueResponse.self, from: data)
        return queueResponse.request_id
    }

    private func pollUntilComplete(requestId: String) async throws {
        let url = URL(string: "https://queue.fal.run/\(endpoint)/requests/\(requestId)/status")!
        var request = URLRequest(url: url)
        request.setValue("Key \(falKey)", forHTTPHeaderField: "Authorization")

        while true {
            let (data, _) = try await URLSession.shared.data(for: request)
            let status = try JSONDecoder().decode(FalStatus.self, from: data)

            print("ImageEditService: Poll status = \(status.status)")

            switch status.status {
            case "COMPLETED":
                return
            case "FAILED":
                throw AppError.generationFailed
            default:
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func fetchResult(requestId: String) async throws -> URL {
        let url = URL(string: "https://queue.fal.run/\(endpoint)/requests/\(requestId)")!
        var request = URLRequest(url: url)
        request.setValue("Key \(falKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(FluxEditResult.self, from: data)

        guard let first = result.images.first, let styledURL = URL(string: first.url) else {
            throw AppError.generationFailed
        }

        return styledURL
    }
}
