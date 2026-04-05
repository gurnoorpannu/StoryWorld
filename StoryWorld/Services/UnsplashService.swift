import UIKit

/// Fetches high-quality landscape photos from Unsplash for AR background compositing.
/// Free tier: 50 requests/hour. No payment required.
class UnsplashService {
    private let accessKey: String
    private let baseURL = "https://api.unsplash.com"

    /// In-memory cache: query → downloaded UIImage
    private var cache: [String: UIImage] = [:]

    init(accessKey: String) {
        self.accessKey = accessKey
    }

    /// Fetch a random landscape photo matching a search query.
    /// Returns cached image if same query was fetched before.
    func fetchPhoto(query: String) async -> UIImage? {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return nil }

        // Return cached image if we have one
        if let cached = cache[trimmed] {
            print("UnsplashService: Returning cached image for '\(trimmed)'")
            return cached
        }

        do {
            let image = try await searchAndDownload(query: trimmed)
            cache[trimmed] = image
            print("UnsplashService: Fetched and cached image for '\(trimmed)'")
            return image
        } catch {
            print("UnsplashService: Failed to fetch '\(trimmed)': \(error)")
            return nil
        }
    }

    // MARK: - Unsplash API

    private func searchAndDownload(query: String) async throws -> UIImage {
        var components = URLComponents(string: "\(baseURL)/photos/random")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "orientation", value: "landscape"),
            URLQueryItem(name: "content_filter", value: "high"),
            URLQueryItem(name: "client_id", value: accessKey)
        ]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("UnsplashService: API error \(http.statusCode): \(body)")
            throw AppError.networkError("Unsplash API error (\(http.statusCode))")
        }

        let photo = try JSONDecoder().decode(UnsplashPhoto.self, from: data)

        // Download the "regular" size (1080px width)
        let imageURL = URL(string: photo.urls.regular)!
        let (imageData, _) = try await URLSession.shared.data(from: imageURL)

        guard let image = UIImage(data: imageData) else {
            throw AppError.networkError("Failed to decode Unsplash image")
        }

        return image
    }
}

// MARK: - Unsplash API Models

struct UnsplashPhoto: Codable {
    let urls: UnsplashURLs
}

struct UnsplashURLs: Codable {
    let raw: String
    let full: String
    let regular: String
    let small: String
    let thumb: String
}
