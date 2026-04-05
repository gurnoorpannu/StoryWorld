import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

class BackgroundRemovalService {
    private let ciContext = CIContext()

    /// Remove the background from an image and composite onto a bundled photo background.
    /// Returns nil if background removal is unavailable (iOS < 17) or fails.
    func applyBackground(to image: UIImage, theme: BackgroundTheme) -> UIImage? {
        guard let bgImage = theme.loadBundledImage() else { return nil }
        return compositeWithBackground(foreground: image, background: bgImage)
    }

    /// Remove the background and composite onto a custom photo background (e.g. from Photos picker).
    /// Returns nil if background removal is unavailable (iOS < 17) or fails.
    func applyPhotoBackground(to image: UIImage, backgroundPhoto: UIImage) -> UIImage? {
        // Resize background photo to match the foreground image size
        let resizedBg = resizeImage(backgroundPhoto, to: image.size)
        return compositeWithBackground(foreground: image, background: resizedBg)
    }

    /// Composite using a virtual-object-focused mask built from:
    /// - `withObjects`: AR snapshot with virtual content visible
    /// - `withoutObjects`: AR snapshot with virtual content hidden
    /// This keeps the generated 3D object as the subject.
    func applyPhotoBackgroundFocusingVirtualObjects(
        withObjects: UIImage,
        withoutObjects: UIImage,
        backgroundPhoto: UIImage
    ) -> UIImage? {
        guard let withCG = withObjects.cgImage,
              let withoutCG = withoutObjects.cgImage else { return nil }

        let resizedBg = resizeImage(backgroundPhoto, to: withObjects.size)
        guard let bgCG = resizedBg.cgImage else { return nil }

        let withCI = CIImage(cgImage: withCG)
        let withoutCI = CIImage(cgImage: withoutCG)
        let backgroundCI = CIImage(cgImage: bgCG)

        let mask = buildVirtualObjectMask(withObjects: withCI, withoutObjects: withoutCI)
        let composite = withCI.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: backgroundCI,
            kCIInputMaskImageKey: mask
        ])

        guard let outputCGImage = ciContext.createCGImage(composite, from: withCI.extent) else {
            return nil
        }

        return UIImage(cgImage: outputCGImage)
    }

    // MARK: - Core Compositing

    private func compositeWithBackground(foreground: UIImage, background: UIImage) -> UIImage? {
        guard #available(iOS 17.0, *) else {
            print("BackgroundRemovalService: Requires iOS 17+")
            return nil
        }
        return performRemoval(foreground: foreground, background: background)
    }

    @available(iOS 17.0, *)
    private func performRemoval(foreground: UIImage, background: UIImage) -> UIImage? {
        guard let inputCGImage = foreground.cgImage else { return nil }

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

        guard let bgCGImage = background.cgImage else { return nil }
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

    private func buildVirtualObjectMask(withObjects: CIImage, withoutObjects: CIImage) -> CIImage {
        let extent = withObjects.extent

        let difference = withObjects
            .applyingFilter("CIDifferenceBlendMode", parameters: [
                kCIInputBackgroundImageKey: withoutObjects
            ])
            .cropped(to: extent)

        let grayscale = difference.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
            kCIInputContrastKey: 5.0,
            kCIInputBrightnessKey: 0.0
        ])

        // Approximate threshold with a high gain + negative bias color matrix.
        let thresholded = grayscale.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 12, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 12, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 12, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: -4.5, y: -4.5, z: -4.5, w: 0)
        ])

        let grown = thresholded.applyingFilter("CIMorphologyMaximum", parameters: [
            "inputRadius": 2
        ])

        return grown
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.0])
            .cropped(to: extent)
    }

    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
