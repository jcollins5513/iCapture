//
//  BackgroundRemover.swift
//  iCapture
//
//  Created by Justin Collins on 9/28/25.
//

import AVFoundation
import Vision
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Combine

@MainActor
class BackgroundRemover: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var processedImage: UIImage?

    private let processingQueue = DispatchQueue(label: "background.removal.queue", qos: .userInitiated)
    private let ciContext = CIContext()

    // MARK: - Public Interface

    func removeBackground(from image: UIImage, completion: @escaping (UIImage?) -> Void) {
        guard !isProcessing else {
            print("BackgroundRemover: Already processing, skipping request")
            completion(nil)
            return
        }

        isProcessing = true
        processingProgress = 0.0

        processingQueue.async { [weak self] in
            self?.performBackgroundRemoval(image: image, depthMap: nil) { result in
                Task { @MainActor in
                    self?.isProcessing = false
                    self?.processingProgress = 1.0
                    self?.processedImage = result
                    completion(result)
                }
            }
        }
    }

    func removeBackground(from image: UIImage, depthMap: CVPixelBuffer?, completion: @escaping (UIImage?) -> Void) {
        guard !isProcessing else {
            print("BackgroundRemover: Already processing, skipping request")
            completion(nil)
            return
        }

        isProcessing = true
        processingProgress = 0.0

        processingQueue.async { [weak self] in
            self?.performBackgroundRemoval(image: image, depthMap: depthMap) { result in
                Task { @MainActor in
                    self?.isProcessing = false
                    self?.processingProgress = 1.0
                    self?.processedImage = result
                    completion(result)
                }
            }
        }
    }

    func removeBackgroundFromPhotoData(_ imageData: Data, completion: @escaping (Data?) -> Void) {
        guard let image = UIImage(data: imageData) else {
            print("BackgroundRemover: Failed to create UIImage from data")
            completion(nil)
            return
        }

        removeBackground(from: image) { processedImage in
            guard let processedImage = processedImage else {
                completion(nil)
                return
            }

            // Convert back to Data (try HEIF first, fallback to JPEG)
            if let processedData = processedImage.heifData() {
                completion(processedData)
            } else {
                print("BackgroundRemover: Failed to convert processed image to HEIF or JPEG data")
                completion(nil)
            }
        }
    }

    // MARK: - Private Methods

    private func performBackgroundRemoval(image: UIImage, depthMap: CVPixelBuffer?, completion: @escaping (UIImage?) -> Void) {
        guard let cgImage = image.cgImage else {
            print("BackgroundRemover: Failed to get CGImage")
            completion(nil)
            return
        }
        // Use Vision framework's foreground instance mask generation
        performForegroundSegmentation(cgImage: cgImage, depthMap: depthMap, originalImage: image, completion: completion)
    }

    private func performForegroundSegmentation(
        cgImage: CGImage,
        depthMap: CVPixelBuffer?,
        originalImage: UIImage,
        completion: @escaping (UIImage?) -> Void
    ) {
        if #available(iOS 17.0, *) {
            let request = VNGenerateForegroundInstanceMaskRequest { [weak self] request, error in
                guard let self = self else { return }
                if let error = error {
                    print("BackgroundRemover: Foreground segmentation failed: \(error)")
                    self.performSimpleBackgroundRemoval(image: originalImage, completion: completion)
                    return
                }

                guard let results = request.results, let result = results.first else {
                    print("BackgroundRemover: No segmentation results")
                    self.performSimpleBackgroundRemoval(image: originalImage, completion: completion)
                    return
                }

                let processedImage = self.applyForegroundMask(result, to: originalImage, cgImage: cgImage, depthMap: depthMap)
                completion(processedImage)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                print("BackgroundRemover: Failed to perform foreground segmentation: \(error)")
                performSimpleBackgroundRemoval(image: originalImage, completion: completion)
            }
        } else {
            // Older OS: fallback to simple removal
            performSimpleBackgroundRemoval(image: originalImage, completion: completion)
        }
    }

    private func applyForegroundMask(_ segmentationResult: Any, to image: UIImage, cgImage: CGImage, depthMap: CVPixelBuffer?) -> UIImage? {
        print("BackgroundRemover: Applying foreground + (optional) depth mask")

        guard let observation = segmentationResult as? VNInstanceMaskObservation else {
            return performSimpleBackgroundRemovalSync(image: image)
        }

        if #available(iOS 17.0, *) {
            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let maskPixelBuffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
                var visionMask = CIImage(cvPixelBuffer: maskPixelBuffer)

                // If a depth map is provided (15 Pro/Max with LiDAR), convert it to a mask and intersect with the Vision mask
                if let depthMap = depthMap {
                    let depthMask = makeDepthMask(from: depthMap, targetExtent: visionMask.extent)
                    // Intersect masks via multiply compositing (logical AND for [0,1] masks)
                    let multiply = CIFilter.multiplyCompositing()
                    multiply.inputImage = depthMask
                    multiply.backgroundImage = visionMask
                    if let combined = multiply.outputImage {
                        visionMask = combined
                    }
                }

                // Blend original image over transparent background using the (combined) mask
                let inputCIImage = CIImage(cgImage: cgImage)
                let blend = CIFilter.blendWithMask()
                blend.inputImage = inputCIImage
                blend.maskImage = visionMask
                let transparentBackground = CIImage(color: .clear).cropped(to: inputCIImage.extent)
                blend.backgroundImage = transparentBackground

                guard let outputCI = blend.outputImage,
                      let outputCG = ciContext.createCGImage(outputCI, from: outputCI.extent) else {
                    return performSimpleBackgroundRemovalSync(image: image)
                }
                return UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
            } catch {
                print("BackgroundRemover: Failed to apply mask: \(error)")
                return performSimpleBackgroundRemovalSync(image: image)
            }
        } else {
            return performSimpleBackgroundRemovalSync(image: image)
        }
    }

    @available(iOS 17.0, *)
    private func makeDepthMask(from depthPixelBuffer: CVPixelBuffer, targetExtent: CGRect) -> CIImage {
        // Convert depth to CIImage (typically 32-bit float, 1 channel)
        var depth = CIImage(cvPixelBuffer: depthPixelBuffer)

        // Scale depth map to match the target extent (Vision mask/original image size)
        let sx = targetExtent.width / depth.extent.width
        let sy = targetExtent.height / depth.extent.height
        depth = depth.transformed(by: CGAffineTransform(scaleX: sx, y: sy))

        // Convert luminance to alpha; then invert so nearer points (car) become white in the mask.
        let alpha = depth.applyingFilter("CIMaskToAlpha")
        let inverted = alpha.applyingFilter("CIColorInvert")

        // Optional smoothing to avoid jagged edges
        let blurred = inverted.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.5])

        // Clamp to the target extent
        return blurred.cropped(to: targetExtent)
    }

    private func performSimpleBackgroundRemoval(image: UIImage, completion: @escaping (UIImage?) -> Void) {
        let processedImage = performSimpleBackgroundRemovalSync(image: image)
        completion(processedImage)
    }

    private func performSimpleBackgroundRemovalSync(image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        // Draw the original image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Get pixel data
        guard let data = context.data else { return nil }
        let pixels = data.assumingMemoryBound(to: UInt8.self)

        // Simple background removal: make white/light areas transparent
        for pixelNumber in 0..<(width * height) {
            let pixelIndex = pixelNumber * 4
            let red = pixels[pixelIndex]
            let green = pixels[pixelIndex + 1]
            let blue = pixels[pixelIndex + 2]

            // Calculate brightness
            let brightness = (Int(red) + Int(green) + Int(blue)) / 3

            // Simple heuristic: if pixel is very light (white/background), make it transparent
            if brightness > 220 { // Adjust threshold as needed
                pixels[pixelIndex + 3] = 0 // Make transparent
            }
        }

        guard let outputCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: outputCGImage)
    }
}

// MARK: - UIImage Extension for HEIF Support

extension UIImage {
    func heifData() -> Data? {
        guard let cgImage = self.cgImage else { return nil }

        // Try HEIF first, fallback to JPEG if it fails
        let data = NSMutableData()

        // Try HEIF format first
        if let destination = CGImageDestinationCreateWithData(data, "public.heif" as CFString, 1, nil) {
            let options: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: 0.9,
                kCGImagePropertyHasAlpha: true
            ]

            CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
            CGImageDestinationFinalize(destination)

            return data as Data
        } else {
            // Fallback to JPEG if HEIF is not supported
            print("BackgroundRemover: HEIF not supported, falling back to JPEG")
            return self.jpegData(compressionQuality: 0.9)
        }
    }
}
