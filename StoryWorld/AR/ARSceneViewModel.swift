import Foundation
import RealityKit
import ARKit
import Combine
import UIKit

@MainActor
class ARSceneViewModel: ObservableObject {
    @Published var placedCharacters: [PlacedCharacter] = []
    @Published var trackingStatus: String = "Initializing AR..."

    var pendingModelURL: URL?
    var pendingEntity: ModelEntity?
    weak var arView: ARView?

    // MARK: - Placement

    func handlePlacement(at worldTransform: simd_float4x4) {
        guard let arView = arView else { return }

        if let entity = pendingEntity {
            pendingEntity = nil
            pendingModelURL = nil
            placeEntity(entity, at: worldTransform, in: arView)
        } else if let modelURL = pendingModelURL {
            pendingModelURL = nil
            Task {
                await placeModel(from: modelURL, at: worldTransform, in: arView)
            }
        } else {
            // No pending model — place a starter model for testing
            placeStarterModel(at: worldTransform, in: arView)
        }
    }

    func placeEntity(_ entity: ModelEntity, at transform: simd_float4x4, in arView: ARView) {
        entity.scale = SIMD3<Float>(repeating: 0.3)
        entity.generateCollisionShapes(recursive: true)

        let anchor = AnchorEntity(world: transform)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)

        installGestures(on: entity, in: arView)

        let character = PlacedCharacter(entity: entity, anchor: anchor, modelURL: nil)
        placedCharacters.append(character)
    }

    func placeModel(from usdzURL: URL, at transform: simd_float4x4, in arView: ARView) async {
        do {
            // Use Entity.load (not .loadModel) — handles both ModelEntity and complex scene hierarchies
            let entity = try await Entity.load(contentsOf: usdzURL)
            entity.scale = SIMD3<Float>(repeating: 0.3)
            entity.generateCollisionShapes(recursive: true)

            let anchor = AnchorEntity(world: transform)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)

            // Install gestures on ModelEntity children
            installGestures(on: entity, in: arView)

            let character = PlacedCharacter(entity: entity, anchor: anchor, modelURL: usdzURL)
            placedCharacters.append(character)
        } catch {
            print("Failed to load model: \(error)")
            // Fall back to starter model
            placeStarterModel(at: transform, in: arView)
        }
    }

    func placeStarterModel(at transform: simd_float4x4, in arView: ARView) {
        let starterNames = ["toy_biplane_realistic", "toy_car"]

        for name in starterNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "usdz") {
                Task {
                    await placeModel(from: url, at: transform, in: arView)
                }
                return
            }
        }

        print("No starter models found in bundle")
    }

    // MARK: - Gestures

    private func installGestures(on entity: Entity, in arView: ARView) {
        if let modelEntity = entity as? ModelEntity {
            arView.installGestures([.translation, .rotation, .scale], for: modelEntity)
        }
        // Also check children recursively
        for child in entity.children {
            installGestures(on: child, in: arView)
        }
    }

    // MARK: - Capture

    func captureFrame() async -> UIImage? {
        guard let arView = arView else { return nil }
        return await withCheckedContinuation { continuation in
            arView.snapshot(saveToHDR: false) { image in
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Management

    func removeAllCharacters() {
        guard let arView = arView else { return }
        for character in placedCharacters {
            arView.scene.removeAnchor(character.anchor)
        }
        placedCharacters.removeAll()
    }

    func removeCharacter(_ character: PlacedCharacter) {
        guard let arView = arView else { return }
        arView.scene.removeAnchor(character.anchor)
        placedCharacters.removeAll { $0.id == character.id }
    }
}
