import SwiftUI

enum BackgroundTheme: String, CaseIterable, Identifiable {
    case realWorld = "Real World"
    case desert = "Desert"
    case snow = "Snow"
    case forest = "Forest"
    case space = "Space"
    case ocean = "Ocean"
    case sunset = "Sunset"
    case cyberpunk = "Cyberpunk"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .realWorld: return "camera.fill"
        case .desert: return "sun.max.fill"
        case .snow: return "snowflake"
        case .forest: return "leaf.fill"
        case .space: return "sparkles"
        case .ocean: return "water.waves"
        case .sunset: return "sunset.fill"
        case .cyberpunk: return "bolt.fill"
        }
    }

    var colors: (Color, Color) {
        switch self {
        case .realWorld: return (.clear, .clear)
        case .desert: return (Color(red: 0.96, green: 0.76, blue: 0.42), Color(red: 0.78, green: 0.48, blue: 0.18))
        case .snow: return (Color(red: 0.85, green: 0.92, blue: 0.98), Color(red: 0.70, green: 0.80, blue: 0.90))
        case .forest: return (Color(red: 0.18, green: 0.42, blue: 0.22), Color(red: 0.08, green: 0.22, blue: 0.12))
        case .space: return (Color(red: 0.05, green: 0.02, blue: 0.15), Color(red: 0.0, green: 0.0, blue: 0.0))
        case .ocean: return (Color(red: 0.10, green: 0.50, blue: 0.80), Color(red: 0.04, green: 0.20, blue: 0.50))
        case .sunset: return (Color(red: 1.0, green: 0.55, blue: 0.20), Color(red: 0.80, green: 0.20, blue: 0.40))
        case .cyberpunk: return (Color(red: 0.10, green: 0.0, blue: 0.25), Color(red: 0.60, green: 0.0, blue: 0.80))
        }
    }

    /// Generate a gradient UIImage for compositing
    func renderBackground(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let (top, bottom) = colors
        return renderer.image { context in
            let cgColors = [UIColor(top).cgColor, UIColor(bottom).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
    }
}
