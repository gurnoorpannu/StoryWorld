import Foundation
import UIKit

class ImageUploadService {

    /// Upload a UIImage as JPEG to fal.ai storage, returns the hosted URL
    func upload(_ image: UIImage, falKey: String) async throws -> URL {
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            throw AppError.compressionFailed
        }

        print("ImageUploadService: Uploading \(jpegData.count) bytes")

        let url = URL(string: "https://fal.ai/api/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Key \(falKey)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = jpegData

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("ImageUploadService: Upload error \(http.statusCode): \(errorBody)")
            throw AppError.networkError("Image upload failed (\(http.statusCode))")
        }

        // Response is the URL string directly, or a JSON object with "url"
        // Try JSON first, fall back to raw string
        if let result = try? JSONDecoder().decode(UploadResult.self, from: data),
           let uploadedURL = URL(string: result.url) {
            print("ImageUploadService: Uploaded to \(uploadedURL)")
            return uploadedURL
        }

        // Some fal.ai upload endpoints return the URL as a plain string
        if let urlString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let uploadedURL = URL(string: urlString) {
            print("ImageUploadService: Uploaded to \(uploadedURL)")
            return uploadedURL
        }

        throw AppError.parseError
    }
}
