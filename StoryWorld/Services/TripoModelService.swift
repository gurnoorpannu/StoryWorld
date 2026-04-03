import Foundation

class TripoModelService {
    private let tripoKey: String

    init(tripoKey: String) {
        self.tripoKey = tripoKey
    }

    /// Alternative 3D generation via Tripo AI (not wired into main pipeline)
    func generateModel(prompt: String) async throws -> URL {
        throw AppError.networkError("Tripo AI is not configured — use FalModelService instead")
    }
}
