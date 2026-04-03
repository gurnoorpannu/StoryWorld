import Foundation

class FalModelService {
    private let falKey: String
    private let endpoint = "fal-ai/hyper3d/rodin"

    init(falKey: String) {
        self.falKey = falKey
    }

    /// Submit prompt, poll until complete, return remote GLB URL
    func generateModel(prompt: String) async throws -> URL {
        // 1. Submit to queue
        let requestId = try await submit(prompt: prompt)
        print("FalModelService: Submitted, request_id = \(requestId)")

        // 2. Poll for completion
        try await pollUntilComplete(requestId: requestId)

        // 3. Get result
        let glbURL = try await fetchResult(requestId: requestId)
        print("FalModelService: Model ready at \(glbURL)")
        return glbURL
    }

    /// Download remote GLB file to local temp directory
    func downloadModel(from remoteURL: URL) async throws -> URL {
        let (data, response) = try await URLSession.shared.data(from: remoteURL)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw AppError.networkError("Download failed (\(http.statusCode))")
        }

        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("model_\(UUID().uuidString).glb")
        try data.write(to: localURL)
        print("FalModelService: Downloaded \(data.count) bytes to \(localURL.lastPathComponent)")
        return localURL
    }

    // MARK: - Fal.ai queue pattern

    private func submit(prompt: String) async throws -> String {
        let url = URL(string: "https://queue.fal.run/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Key \(falKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "prompt": prompt,
            "quality": "medium",
            "material": "PBR",
            "geometry_file_format": "glb"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("FalModelService: Submit error \(http.statusCode): \(errorBody)")
            throw AppError.networkError("fal.ai submit failed (\(http.statusCode))")
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

            print("FalModelService: Poll status = \(status.status)")

            switch status.status {
            case "COMPLETED":
                return
            case "FAILED":
                throw AppError.generationFailed
            default:
                // IN_QUEUE or IN_PROGRESS — wait 3 seconds
                try await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func fetchResult(requestId: String) async throws -> URL {
        let url = URL(string: "https://queue.fal.run/\(endpoint)/requests/\(requestId)")!
        var request = URLRequest(url: url)
        request.setValue("Key \(falKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(RodinResult.self, from: data)

        guard let glbURL = URL(string: result.model_mesh.url) else {
            throw AppError.generationFailed
        }

        return glbURL
    }
}
