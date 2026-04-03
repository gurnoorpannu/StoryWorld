import Foundation

struct TripoTaskResponse: Codable {
    let data: TripoTaskData
}

struct TripoTaskData: Codable {
    let task_id: String
}

struct TripoStatusResponse: Codable {
    let data: TripoStatusData
}

struct TripoStatusData: Codable {
    let status: String
    let output: TripoOutput?
}

struct TripoOutput: Codable {
    let model: String?
}
