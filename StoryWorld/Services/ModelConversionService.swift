import Foundation
import ModelIO

class ModelConversionService {

    /// Convert a local GLB file to USDZ using ModelIO
    func convertGLBtoUSDZ(glbLocalURL: URL) throws -> URL {
        let asset = MDLAsset(url: glbLocalURL)

        let usdzURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("model_\(UUID().uuidString).usdz")

        // Remove existing file at destination if any
        try? FileManager.default.removeItem(at: usdzURL)

        guard asset.export(to: usdzURL) else {
            print("ModelConversionService: export(to:) returned false")
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
