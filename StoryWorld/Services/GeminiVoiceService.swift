import Foundation

class GeminiVoiceService {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Simple transcription

    func transcribe(audioData: Data) async throws -> String {
        let body = buildRequestBody(
            textPrompt: "Transcribe this audio. Return ONLY the spoken text, nothing else.",
            audioData: audioData
        )
        let response = try await sendRequest(body: body)
        guard let text = response.candidates?.first?.content.parts.first?.text else {
            throw AppError.noResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Transcribe + enhance into CharacterPrompt

    func extractCharacterPrompt(audioData: Data) async throws -> CharacterPrompt {
        let systemPrompt = """
        Listen to this audio. The user is describing a 3D character or object.
        Return ONLY a JSON object:
        {"raw_transcript": "what they said", "optimized_3d_prompt": "short simple 3D prompt", "motion_prompt": "cinematic motion description for video generation"}

        IMPORTANT for optimized_3d_prompt:
        - Keep it SHORT (under 10 words). Example: "a spider monster" or "a red dragon" or "a wooden chair"
        - Do NOT add style words like "photorealistic", "detailed", "cinematic lighting", "high resolution"
        - Just describe the object simply and concisely
        - The 3D model generator works best with plain, simple descriptions

        Return raw JSON only, no markdown backticks.
        """

        let body = buildRequestBody(textPrompt: systemPrompt, audioData: audioData)
        let response = try await sendRequest(body: body)

        guard let rawText = response.candidates?.first?.content.parts.first?.text else {
            throw AppError.noResponse
        }

        let cleanedJSON = stripMarkdownCodeBlock(rawText)
        print("GeminiVoiceService: Raw response: \(rawText)")
        print("GeminiVoiceService: Cleaned JSON: \(cleanedJSON)")

        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AppError.parseError
        }

        do {
            let prompt = try JSONDecoder().decode(CharacterPrompt.self, from: data)
            return prompt
        } catch {
            print("GeminiVoiceService: JSON decode failed: \(error)")
            throw AppError.parseError
        }
    }

    // MARK: - Private helpers

    private func buildRequestBody(textPrompt: String, audioData: Data) -> [String: Any] {
        let base64Audio = audioData.base64EncodedString()
        return [
            "contents": [[
                "parts": [
                    ["text": textPrompt],
                    ["inline_data": [
                        "mime_type": "audio/m4a",
                        "data": base64Audio
                    ]]
                ]
            ]]
        ]
    }

    private func sendRequest(body: [String: Any]) async throws -> GeminiResponse {
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw AppError.networkError("Invalid URL")
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = urlComponents.url else {
            throw AppError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("GeminiVoiceService: HTTP \(http.statusCode): \(errorBody)")
            throw AppError.networkError("Gemini API error (\(http.statusCode))")
        }

        return try JSONDecoder().decode(GeminiResponse.self, from: data)
    }

    /// Gemini sometimes wraps JSON in ```json ... ``` blocks — strip them
    private func stripMarkdownCodeBlock(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove ```json ... ``` wrapper
        if cleaned.hasPrefix("```") {
            // Remove opening line (```json or ```)
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            // Remove closing ```
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
