import Foundation

struct FalQueueResponse: Codable {
    let request_id: String
}

struct FalStatus: Codable {
    let status: String
}

struct RodinResult: Codable {
    let model_mesh: RodinMesh
}

struct RodinMesh: Codable {
    let url: String
    let file_name: String
}

struct FluxEditResult: Codable {
    let images: [FluxImage]
}

struct FluxImage: Codable {
    let url: String
}

struct SeedanceResult: Codable {
    let video: SeedanceVideo
}

struct SeedanceVideo: Codable {
    let url: String
}

struct UploadResult: Codable {
    let url: String
}
