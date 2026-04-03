import Foundation
import UIKit

class CapturedFrame: Identifiable, ObservableObject {
    let id = UUID()
    let image: UIImage
    let capturedAt: Date
    @Published var uploadedURL: URL?
    @Published var videoURL: URL?
    @Published var isAnimating: Bool = false

    init(image: UIImage) {
        self.image = image
        self.capturedAt = Date()
    }
}
