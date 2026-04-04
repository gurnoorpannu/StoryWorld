import Foundation
import RealityKit
import UIKit

/// Custom GLB parser that creates RealityKit entities directly.
/// Works with Shap-E's vertex-colored meshes that Apple's frameworks can't convert.
class GLBLoader {

    /// Parse a GLB file and create a RealityKit ModelEntity
    static func loadEntity(from glbURL: URL) throws -> ModelEntity {
        let data = try Data(contentsOf: glbURL)
        print("GLBLoader: Parsing \(data.count) bytes")

        // Parse GLB header (12 bytes)
        guard data.count >= 12 else { throw AppError.conversionFailed }
        let magic = String(data: data[0..<4], encoding: .ascii)
        guard magic == "glTF" else {
            print("GLBLoader: Not a valid GLB file (bad magic)")
            throw AppError.conversionFailed
        }

        // Parse JSON chunk
        let jsonChunkLength = readUInt32(data, offset: 12)
        let jsonStart = 20
        let jsonEnd = jsonStart + Int(jsonChunkLength)
        guard jsonEnd <= data.count else { throw AppError.conversionFailed }

        let jsonData = data[jsonStart..<jsonEnd]
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw AppError.conversionFailed
        }

        // Parse BIN chunk
        let binChunkStart = jsonEnd
        guard binChunkStart + 8 <= data.count else { throw AppError.conversionFailed }
        // Skip chunk length (4 bytes) + chunk type (4 bytes)
        let binStart = binChunkStart + 8
        let binData = data[binStart...]

        // Extract mesh data from JSON
        guard let meshes = json["meshes"] as? [[String: Any]],
              let accessors = json["accessors"] as? [[String: Any]],
              let bufferViews = json["bufferViews"] as? [[String: Any]],
              let firstMesh = meshes.first,
              let primitives = firstMesh["primitives"] as? [[String: Any]],
              let firstPrim = primitives.first,
              let attributes = firstPrim["attributes"] as? [String: Any],
              let posAccessorIdx = attributes["POSITION"] as? Int else {
            print("GLBLoader: Missing required mesh data in JSON")
            throw AppError.conversionFailed
        }

        print("GLBLoader: Found mesh with \(primitives.count) primitive(s)")

        // Read vertex positions
        let positions = try readVec3(accessorIndex: posAccessorIdx, accessors: accessors,
                                     bufferViews: bufferViews, binData: binData)
        print("GLBLoader: Read \(positions.count) vertices")

        // Read indices
        var indices: [UInt32] = []
        if let indicesIdx = firstPrim["indices"] as? Int {
            indices = try readIndices(accessorIndex: indicesIdx, accessors: accessors,
                                     bufferViews: bufferViews, binData: binData)
            print("GLBLoader: Read \(indices.count) indices (\(indices.count / 3) triangles)")
        } else {
            // No indices — generate sequential
            indices = (0..<UInt32(positions.count)).map { $0 }
        }

        // Read vertex colors for average tint
        var materialColor: UIColor = .init(red: 0.6, green: 0.6, blue: 0.65, alpha: 1)
        if let colorIdx = attributes["COLOR_0"] as? Int {
            let colors = try readVertexColors(accessorIndex: colorIdx, accessors: accessors,
                                              bufferViews: bufferViews, binData: binData)
            if !colors.isEmpty {
                var r: Float = 0, g: Float = 0, b: Float = 0
                for c in colors { r += c.x; g += c.y; b += c.z }
                let n = Float(colors.count)
                r /= n; g /= n; b /= n
                print("GLBLoader: Raw average vertex color: R=\(r) G=\(g) B=\(b)")

                // Boost very dark colors so the model is visible in AR
                let brightness = (r + g + b) / 3.0
                if brightness < 0.15 {
                    // Too dark — brighten significantly
                    let boost: Float = 0.3 / max(brightness, 0.01)
                    r = min(r * boost + 0.15, 1.0)
                    g = min(g * boost + 0.15, 1.0)
                    b = min(b * boost + 0.15, 1.0)
                    print("GLBLoader: Boosted dark color to: R=\(r) G=\(g) B=\(b)")
                } else if brightness < 0.3 {
                    // Somewhat dark — moderate boost
                    r = min(r * 1.5 + 0.1, 1.0)
                    g = min(g * 1.5 + 0.1, 1.0)
                    b = min(b * 1.5 + 0.1, 1.0)
                }

                materialColor = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)
            }
        }

        // Read normals if available
        var normals: [SIMD3<Float>]? = nil
        if let normalIdx = attributes["NORMAL"] as? Int {
            normals = try readVec3(accessorIndex: normalIdx, accessors: accessors,
                                   bufferViews: bufferViews, binData: binData)
            print("GLBLoader: Read \(normals!.count) normals")
        }

        // Build MeshDescriptor
        var meshDescriptor = MeshDescriptor()
        meshDescriptor.positions = MeshBuffers.Positions(positions)
        meshDescriptor.primitives = .triangles(indices)
        if let normals = normals {
            meshDescriptor.normals = MeshBuffers.Normals(normals)
        }

        let mesh = try MeshResource.generate(from: [meshDescriptor])

        var material = SimpleMaterial()
        material.color = .init(tint: materialColor)
        material.roughness = .float(0.7)
        material.metallic = .float(0.1)

        let entity = ModelEntity(mesh: mesh, materials: [material])
        print("GLBLoader: Created ModelEntity successfully")
        return entity
    }

    // MARK: - Binary Readers

    private static func readVec3(accessorIndex: Int, accessors: [[String: Any]],
                                  bufferViews: [[String: Any]], binData: Data.SubSequence) throws -> [SIMD3<Float>] {
        let accessor = accessors[accessorIndex]
        guard let bvIndex = accessor["bufferView"] as? Int,
              let count = accessor["count"] as? Int,
              let componentType = accessor["componentType"] as? Int else {
            throw AppError.conversionFailed
        }

        let bufferView = bufferViews[bvIndex]
        let bvOffset = bufferView["byteOffset"] as? Int ?? 0
        let accOffset = accessor["byteOffset"] as? Int ?? 0
        let totalOffset = binData.startIndex + bvOffset + accOffset

        guard componentType == 5126 else { // 5126 = FLOAT
            print("GLBLoader: Unsupported VEC3 component type: \(componentType)")
            throw AppError.conversionFailed
        }

        // Check for byte stride (interleaved buffers)
        let defaultStride = 12 // 3 floats * 4 bytes
        let stride = bufferView["byteStride"] as? Int ?? defaultStride

        var result: [SIMD3<Float>] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            let base = totalOffset + i * stride
            guard base + 12 <= binData.endIndex else { break }

            let x = binData[base..<(base + 4)].withUnsafeBytes { $0.load(as: Float.self) }
            let y = binData[(base + 4)..<(base + 8)].withUnsafeBytes { $0.load(as: Float.self) }
            let z = binData[(base + 8)..<(base + 12)].withUnsafeBytes { $0.load(as: Float.self) }
            result.append(SIMD3<Float>(x, y, z))
        }

        return result
    }

    private static func readVertexColors(accessorIndex: Int, accessors: [[String: Any]],
                                          bufferViews: [[String: Any]], binData: Data.SubSequence) throws -> [SIMD3<Float>] {
        let accessor = accessors[accessorIndex]
        guard let bvIndex = accessor["bufferView"] as? Int,
              let count = accessor["count"] as? Int,
              let componentType = accessor["componentType"] as? Int,
              let type = accessor["type"] as? String else {
            throw AppError.conversionFailed
        }

        let bufferView = bufferViews[bvIndex]
        let bvOffset = bufferView["byteOffset"] as? Int ?? 0
        let accOffset = accessor["byteOffset"] as? Int ?? 0
        let totalOffset = binData.startIndex + bvOffset + accOffset

        let componentsPerVertex = type == "VEC4" ? 4 : 3

        var result: [SIMD3<Float>] = []
        result.reserveCapacity(count)

        if componentType == 5126 { // FLOAT
            let bytesPerComponent = 4
            let defaultStride = componentsPerVertex * bytesPerComponent
            let stride = bufferView["byteStride"] as? Int ?? defaultStride

            for i in 0..<count {
                let base = totalOffset + i * stride
                guard base + 12 <= binData.endIndex else { break }
                let r = binData[base..<(base + 4)].withUnsafeBytes { $0.load(as: Float.self) }
                let g = binData[(base + 4)..<(base + 8)].withUnsafeBytes { $0.load(as: Float.self) }
                let b = binData[(base + 8)..<(base + 12)].withUnsafeBytes { $0.load(as: Float.self) }
                result.append(SIMD3<Float>(r, g, b))
            }
        } else if componentType == 5121 { // UNSIGNED_BYTE (normalized)
            let defaultStride = componentsPerVertex
            let stride = bufferView["byteStride"] as? Int ?? defaultStride

            for i in 0..<count {
                let base = totalOffset + i * stride
                guard base + 3 <= binData.endIndex else { break }
                let r = Float(binData[base]) / 255.0
                let g = Float(binData[base + 1]) / 255.0
                let b = Float(binData[base + 2]) / 255.0
                result.append(SIMD3<Float>(r, g, b))
            }
        } else if componentType == 5123 { // UNSIGNED_SHORT (normalized)
            let bytesPerComponent = 2
            let defaultStride = componentsPerVertex * bytesPerComponent
            let stride = bufferView["byteStride"] as? Int ?? defaultStride

            for i in 0..<count {
                let base = totalOffset + i * stride
                guard base + 6 <= binData.endIndex else { break }
                let r = Float(binData[base..<(base + 2)].withUnsafeBytes { $0.load(as: UInt16.self) }) / 65535.0
                let g = Float(binData[(base + 2)..<(base + 4)].withUnsafeBytes { $0.load(as: UInt16.self) }) / 65535.0
                let b = Float(binData[(base + 4)..<(base + 6)].withUnsafeBytes { $0.load(as: UInt16.self) }) / 65535.0
                result.append(SIMD3<Float>(r, g, b))
            }
        }

        return result
    }

    private static func readIndices(accessorIndex: Int, accessors: [[String: Any]],
                                     bufferViews: [[String: Any]], binData: Data.SubSequence) throws -> [UInt32] {
        let accessor = accessors[accessorIndex]
        guard let bvIndex = accessor["bufferView"] as? Int,
              let count = accessor["count"] as? Int,
              let componentType = accessor["componentType"] as? Int else {
            throw AppError.conversionFailed
        }

        let bufferView = bufferViews[bvIndex]
        let bvOffset = bufferView["byteOffset"] as? Int ?? 0
        let accOffset = accessor["byteOffset"] as? Int ?? 0
        let totalOffset = binData.startIndex + bvOffset + accOffset

        var result: [UInt32] = []
        result.reserveCapacity(count)

        switch componentType {
        case 5125: // UNSIGNED_INT
            for i in 0..<count {
                let base = totalOffset + i * 4
                guard base + 4 <= binData.endIndex else { break }
                let val = binData[base..<(base + 4)].withUnsafeBytes { $0.load(as: UInt32.self) }
                result.append(val)
            }
        case 5123: // UNSIGNED_SHORT
            for i in 0..<count {
                let base = totalOffset + i * 2
                guard base + 2 <= binData.endIndex else { break }
                let val = binData[base..<(base + 2)].withUnsafeBytes { $0.load(as: UInt16.self) }
                result.append(UInt32(val))
            }
        case 5121: // UNSIGNED_BYTE
            for i in 0..<count {
                let base = totalOffset + i
                guard base < binData.endIndex else { break }
                result.append(UInt32(binData[base]))
            }
        default:
            print("GLBLoader: Unsupported index component type: \(componentType)")
            throw AppError.conversionFailed
        }

        return result
    }

    private static func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        data[offset..<(offset + 4)].withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
    }
}
