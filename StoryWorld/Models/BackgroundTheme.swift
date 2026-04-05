import SwiftUI
import UIKit

enum BackgroundTheme: String, CaseIterable, Identifiable {
    case realWorld = "Real World"
    case desert = "Desert"
    case hills = "Hills"
    case snow = "Snow"
    case gallery = "My Photos"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .realWorld: return "camera.fill"
        case .desert: return "sun.max.fill"
        case .hills: return "mountain.2.fill"
        case .snow: return "snowflake"
        case .gallery: return "photo.on.rectangle"
        }
    }

    /// Asset catalog image name for bundled backgrounds
    var assetName: String? {
        switch self {
        case .desert: return "bg_desert"
        case .hills: return "bg_hills"
        case .snow: return "bg_snow"
        default: return nil
        }
    }

    /// Whether this is a bundled background with a photo
    var isBundled: Bool {
        assetName != nil
    }

    /// Load the bundled background UIImage from Assets.xcassets
    func loadBundledImage() -> UIImage? {
        guard let name = assetName else { return nil }
        return UIImage(named: name)
    }
}
