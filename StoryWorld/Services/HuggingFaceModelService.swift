import Foundation

/// Free text-to-3D generation using OpenAI's Shap-E model hosted on Hugging Face Spaces.
/// No API key required — completely free via the Gradio API.
class HuggingFaceModelService {
    private let spaceURL = "https://hysts-shap-e.hf.space/gradio_api"

    /// Generate a 3D model from a text prompt, returns local GLB file URL
    func generateModel(prompt: String) async throws -> URL {
        // Step 1: Submit the request
        let eventId = try await submitRequest(prompt: prompt)
        print("HuggingFaceModelService: Submitted, event_id = \(eventId)")

        // Step 2: Poll for result via SSE data endpoint
        let fileURL = try await pollForResult(eventId: eventId)
        print("HuggingFaceModelService: 3D model ready at \(fileURL)")
        return fileURL
    }

    /// Download remote GLB/PLY file to local temp directory
    func downloadModel(from remoteURL: URL) async throws -> URL {
        let (data, response) = try await URLSession.shared.data(from: remoteURL)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw AppError.networkError("Download failed (\(http.statusCode))")
        }

        // Determine extension from URL or default to .glb
        let ext = remoteURL.pathExtension.isEmpty ? "glb" : remoteURL.pathExtension
        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("model_\(UUID().uuidString).\(ext)")
        try data.write(to: localURL)
        print("HuggingFaceModelService: Downloaded \(data.count) bytes to \(localURL.lastPathComponent)")
        return localURL
    }

    // MARK: - Gradio API

    /// Submit a text-to-3d request via Gradio's call endpoint
    private func submitRequest(prompt: String) async throws -> String {
        let url = URL(string: "\(spaceURL)/call/text-to-3d")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Gradio call format: data array with positional args
        // Args: prompt, seed, guidance_scale, num_inference_steps
        let body: [String: Any] = [
            "data": [prompt, 0, 15.0, 64]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        let responseBody = String(data: data, encoding: .utf8) ?? "Unknown"
        print("HuggingFaceModelService: Submit response: \(responseBody)")

        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            print("HuggingFaceModelService: Submit error \(http.statusCode): \(responseBody)")
            throw AppError.networkError("HF Space submit failed (\(http.statusCode))")
        }

        // Response: {"event_id": "abc123"}
        let result = try JSONDecoder().decode(GradioCallResponse.self, from: data)
        return result.event_id
    }

    /// Poll the SSE data endpoint until we get the result
    private func pollForResult(eventId: String) async throws -> URL {
        let url = URL(string: "\(spaceURL)/call/text-to-3d/\(eventId)")!
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        // Gradio returns SSE events. We'll fetch and parse the response.
        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("HuggingFaceModelService: Poll error \(http.statusCode): \(body)")
            throw AppError.networkError("HF Space poll failed (\(http.statusCode))")
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""
        print("HuggingFaceModelService: SSE response: \(responseText.prefix(500))")

        // Parse SSE events - look for "event: complete" followed by "data: ..."
        let lines = responseText.components(separatedBy: "\n")
        var foundComplete = false
        for line in lines {
            if line.starts(with: "event: complete") {
                foundComplete = true
                continue
            }
            if line.starts(with: "event: error") {
                // Next data line has the error
                throw AppError.networkError("HF Space generation failed")
            }
            if foundComplete && line.starts(with: "data: ") {
                let jsonStr = String(line.dropFirst(6))
                if let jsonData = jsonStr.data(using: .utf8) {
                    // SSE data is a raw array: [{path, url, ...}]
                    let files = try JSONDecoder().decode([GradioFileData].self, from: jsonData)
                    if let fileInfo = files.first {
                        // Prefer the full URL if available, otherwise construct from path
                        let downloadURL = URL(string: fileInfo.url ?? "")
                            ?? URL(string: "\(spaceURL)/file=\(fileInfo.path)")
                        if let downloadURL = downloadURL {
                            return downloadURL
                        }
                    }
                }
                throw AppError.generationFailed
            }
        }

        // If we didn't get a complete event, the generation might still be processing
        // Retry with a delay
        print("HuggingFaceModelService: No complete event yet, retrying...")
        try await Task.sleep(nanoseconds: 5_000_000_000)
        return try await pollForResult(eventId: eventId)
    }
}

// MARK: - Gradio Response Models

struct GradioCallResponse: Codable {
    let event_id: String
}

struct GradioFileData: Codable {
    let path: String
    let url: String?
    let orig_name: String?
    let mime_type: String?
}
