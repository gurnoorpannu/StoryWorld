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

        // Load GLB via MDLAsset, create SCNScene, then write as USDZ
        let mdlAsset = MDLAsset(url: glbLocalURL)
        mdlAsset.loadTextures()

        let scene = SCNScene(mdlAsset: mdlAsset)

        let success = scene.write(to: usdzURL, delegate: nil)

        guard success else {
            print("ModelConversionService: scene.write(to:) returned false")
            throw AppError.conversionFailed
        }

        // Verify file was created and has content
        let attrs = try FileManager.default.attributesOfItem(atPath: usdzURL.path)
        let size = attrs[.size] as? Int ?? 0
        if size == 0 {
            print("ModelConversionService: Exported file is empty")
            throw AppError.conversionFailed
        }

        print("ModelConversionService: Converted to USDZ (\(size) bytes)")
        return usdzURL
    }
}
