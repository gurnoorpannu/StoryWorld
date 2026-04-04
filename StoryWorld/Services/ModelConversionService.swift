import Foundation
import ModelIO
import SceneKit
import SceneKit.ModelIO

class ModelConversionService {

    /// Convert a local GLB file to USDZ using SceneKit + ModelIO
    func convertGLBtoUSDZ(glbLocalURL: URL) throws -> URL {
        let usdzURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("model_\(UUID().uuidString).usdz")

        // Remove existing file at destination if any
        try? FileManager.default.removeItem(at: usdzURL)

        // Try SceneKit's native loader first (better GLB/glTF support)
        let scene: SCNScene
        do {
            scene = try SCNScene(url: glbLocalURL, options: [
                .checkConsistency: true,
                .convertToYUp: true
            ])
            print("ModelConversionService: Loaded GLB via SCNScene(url:)")
        } catch {
            print("ModelConversionService: SCNScene(url:) failed: \(error), trying MDLAsset...")
            // Fallback to MDLAsset approach
            let mdlAsset = MDLAsset(url: glbLocalURL)
            mdlAsset.loadTextures()
            scene = SCNScene(mdlAsset: mdlAsset)
        }

        // Ensure the scene has visible content by checking node count
        let nodeCount = countNodes(in: scene.rootNode)
        print("ModelConversionService: Scene has \(nodeCount) nodes")

        let success = scene.write(to: usdzURL, delegate: nil)

        guard success else {
            print("ModelConversionService: scene.write(to:) returned false")
            throw AppError.conversionFailed
        }

        // Verify file was created and has meaningful content (>2KB)
        let attrs = try FileManager.default.attributesOfItem(atPath: usdzURL.path)
        let size = attrs[.size] as? Int ?? 0
        if size < 2048 {
            print("ModelConversionService: Exported file too small (\(size) bytes), likely empty")
            throw AppError.conversionFailed
        }

        print("ModelConversionService: Converted to USDZ (\(size) bytes)")
        return usdzURL
    }

    private func countNodes(in node: SCNNode) -> Int {
        var count = 1
        for child in node.childNodes {
            count += countNodes(in: child)
        }
        return count
    }
}
