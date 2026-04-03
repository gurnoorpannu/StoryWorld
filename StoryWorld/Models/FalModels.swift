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

// MARK: - MiniMax Models

struct MiniMaxTaskResponse: Codable {
    let task_id: String?

    // MiniMax may include base_resp with error info
    let base_resp: MiniMaxBaseResp?
}

struct MiniMaxBaseResp: Codable {
    let status_code: Int?
    let status_msg: String?
}

struct MiniMaxQueryResponse: Codable {
    let status: String
    let file_id: String?
    let error_message: String?
    let base_resp: MiniMaxBaseResp?
}

struct MiniMaxFileResponse: Codable {
    let file: MiniMaxFile
}

struct MiniMaxFile: Codable {
    let download_url: String
}
