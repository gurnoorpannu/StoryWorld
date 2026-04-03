import Foundation

class TripoModelService {
    private let apiKey: String
    private let baseURL = "https://api.tripo3d.ai/v2/openapi"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// Generate a 3D model from a text prompt, returns remote GLB URL
    func generateModel(prompt: String) async throws -> URL {
        // 1. Create task
        let taskId = try await createTask(prompt: prompt)
        print("TripoModelService: Created task \(taskId)")

        // 2. Poll until complete
        let modelURL = try await pollUntilComplete(taskId: taskId)
        print("TripoModelService: Model ready at \(modelURL)")
        return modelURL
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
        print("TripoModelService: Downloaded \(data.count) bytes to \(localURL.lastPathComponent)")
        return localURL
    }

    // MARK: - Tripo API

    private func createTask(prompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/task")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "type": "text_to_model",
            "prompt": prompt
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("TripoModelService: Submit error \(http.statusCode): \(errorBody)")
            throw AppError.networkError("Tripo submit failed (\(http.statusCode))")
        }

        let result = try JSONDecoder().decode(TripoTaskResponse.self, from: data)
        return result.data.task_id
    }

    private func pollUntilComplete(taskId: String) async throws -> URL {
        let url = URL(string: "\(baseURL)/task/\(taskId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var pollCount = 0
        while true {
            let (data, _) = try await URLSession.shared.data(for: request)
            let status = try JSONDecoder().decode(TripoStatusResponse.self, from: data)

            pollCount += 1
            print("TripoModelService: Poll #\(pollCount) status = \(status.data.status)")

            switch status.data.status {
            case "success":
                guard let modelURLString = status.data.output?.model,
                      let modelURL = URL(string: modelURLString) else {
                    throw AppError.generationFailed
                }
                return modelURL
            case "failed":
                throw AppError.generationFailed
            default:
                // queued, running — wait 3 seconds
                try await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }
}
