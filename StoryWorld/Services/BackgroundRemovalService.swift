import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

class BackgroundRemovalService {
    private let ciContext = CIContext()

    /// Remove the background from an image and composite onto a themed background.
    /// Returns nil if background removal is unavailable (iOS < 17) or fails.
    func applyBackground(to image: UIImage, theme: BackgroundTheme) -> UIImage? {
        guard #available(iOS 17.0, *) else {
            print("BackgroundRemovalService: Requires iOS 17+")
            return nil
        }
        return performRemoval(image: image, theme: theme)
    }

    @available(iOS 17.0, *)
    private func performRemoval(image: UIImage, theme: BackgroundTheme) -> UIImage? {
        guard let inputCGImage = image.cgImage else { return nil }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: inputCGImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("BackgroundRemovalService: Vision request failed: \(error)")
            return nil
        }

        guard let result = request.results?.first else {
            print("BackgroundRemovalService: No mask result")
            return nil
        }

        let maskPixelBuffer: CVPixelBuffer
        do {
            maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        } catch {
            print("BackgroundRemovalService: Mask generation failed: \(error)")
            return nil
        }

        // Convert to CIImages
        let maskCI = CIImage(cvPixelBuffer: maskPixelBuffer)
        let originalCI = CIImage(cgImage: inputCGImage)

        // Generate themed background
        let bgUIImage = theme.renderBackground(size: image.size)
        guard let bgCGImage = bgUIImage.cgImage else { return nil }
        let backgroundCI = CIImage(cgImage: bgCGImage)

        // Scale mask to match original image size
        let scaleX = originalCI.extent.width / maskCI.extent.width
        let scaleY = originalCI.extent.height / maskCI.extent.height
        let scaledMask = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Composite: foreground (original) over background using mask
        let composite = originalCI.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: backgroundCI,
            kCIInputMaskImageKey: scaledMask
        ])

        guard let outputCGImage = ciContext.createCGImage(composite, from: originalCI.extent) else {
            print("BackgroundRemovalService: Failed to render composite")
            return nil
        }

        return UIImage(cgImage: outputCGImage)
    }
}
