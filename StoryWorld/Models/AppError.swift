import Foundation

enum AppError: Error, LocalizedError {
    case captureFailed
    case compressionFailed
    case generationFailed
    case conversionFailed
    case noResponse
    case parseError
    case networkError(String)
    case modelNotFound

    var errorDescription: String? {
        switch self {
        case .captureFailed: return "Failed to capture AR frame"
        case .compressionFailed: return "Failed to compress image"
        case .generationFailed: return "AI generation failed"
        case .conversionFailed: return "3D model conversion failed"
        case .noResponse: return "No response from API"
        case .parseError: return "Failed to parse response"
        case .networkError(let msg): return msg
        case .modelNotFound: return "3D model file not found"
        }
    }
}
