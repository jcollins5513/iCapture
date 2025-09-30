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
import ImageIO

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

                let processedImage = self.applyForegroundMask(
                    result,
                    to: originalImage,
                    cgImage: cgImage,
                    depthMap: depthMap
                )
                completion(processedImage)
            }

            request.qualityLevel = .accurate
            request.revision = VNGenerateForegroundInstanceMaskRequest.currentRevision

            let orientation = CGImagePropertyOrientation(originalImage.imageOrientation)
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

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

    private func applyForegroundMask(
        _ segmentationResult: Any,
        to image: UIImage,
        cgImage: CGImage,
        depthMap: CVPixelBuffer?
    ) -> UIImage? {
        print("BackgroundRemover: Applying foreground + (optional) depth mask")

        guard let observation = segmentationResult as? VNInstanceMaskObservation else {
            return performSimpleBackgroundRemovalSync(image: image)
        }

        if #available(iOS 17.0, *) {
            do {
                let orientation = CGImagePropertyOrientation(image.imageOrientation)
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                let maskPixelBuffer = try observation.generateScaledMaskForImage(
                    forInstances: observation.allInstances,
                    from: handler
                )

                guard let visionMask = refineMask(
                    from: maskPixelBuffer,
                    depthMap: depthMap,
                    targetExtent: CGRect(origin: .zero, size: CGSize(width: cgImage.width, height: cgImage.height))
                ) else {
                    return performSimpleBackgroundRemovalSync(image: image)
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
    private func makeDepthMask(
        from depthPixelBuffer: CVPixelBuffer,
        guidedBy subjectMask: CVPixelBuffer?,
        targetExtent: CGRect
    ) -> CIImage? {
        guard let depthStatistics = DepthStatistics(depthPixelBuffer: depthPixelBuffer, subjectMask: subjectMask) else {
            return nil
        }

        let foregroundUpperBound = depthStatistics.foregroundUpperBound

        CVPixelBufferLockBaseAddress(depthPixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthPixelBuffer, .readOnly) }

        guard let depthBase = CVPixelBufferGetBaseAddress(depthPixelBuffer) else { return nil }

        let depthWidth = CVPixelBufferGetWidth(depthPixelBuffer)
        let depthHeight = CVPixelBufferGetHeight(depthPixelBuffer)
        let depthRowStride = CVPixelBufferGetBytesPerRow(depthPixelBuffer) / MemoryLayout<Float32>.stride
        let depthValues = depthBase.assumingMemoryBound(to: Float32.self)

        let attributes: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
        var maskBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            depthWidth,
            depthHeight,
            kCVPixelFormatType_OneComponent8,
            attributes as CFDictionary,
            &maskBuffer
        ) == kCVReturnSuccess, let mask = maskBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(mask, [])
        let maskRowStride = CVPixelBufferGetBytesPerRow(mask)
        guard let maskBase = CVPixelBufferGetBaseAddress(mask) else {
            CVPixelBufferUnlockBaseAddress(mask, [])
            return nil
        }

        let maskValues = maskBase.assumingMemoryBound(to: UInt8.self)

        for y in 0..<depthHeight {
            let depthRow = depthValues.advanced(by: y * depthRowStride)
            let maskRow = maskValues.advanced(by: y * maskRowStride)
            for x in 0..<depthWidth {
                let depthValue = depthRow[x]
                if depthValue > 0 && depthValue <= foregroundUpperBound {
                    maskRow[x] = 255
                } else {
                    maskRow[x] = 0
                }
            }
        }

        CVPixelBufferUnlockBaseAddress(mask, [])

        var depthMask = CIImage(cvPixelBuffer: mask)
        let scaleX = targetExtent.width / depthMask.extent.width
        let scaleY = targetExtent.height / depthMask.extent.height
        depthMask = depthMask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let blurRadius = max(1.0, min(targetExtent.width, targetExtent.height) * 0.0025)
        depthMask = depthMask
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blurRadius])
            .cropped(to: targetExtent)

        return depthMask.applyingFilter("CIMaskToAlpha")
    }

    @available(iOS 17.0, *)
    private func refineMask(
        from visionMask: CVPixelBuffer,
        depthMap: CVPixelBuffer?,
        targetExtent: CGRect
    ) -> CIImage? {
        var maskImage = CIImage(cvPixelBuffer: visionMask)

        if maskImage.extent.size != targetExtent.size {
            let scaleX = targetExtent.width / maskImage.extent.width
            let scaleY = targetExtent.height / maskImage.extent.height
            maskImage = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        }

        let cleanupRadius = max(1.5, min(targetExtent.width, targetExtent.height) * 0.003)
        maskImage = maskImage
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: cleanupRadius])
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: cleanupRadius])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 1.35,
                kCIInputBrightnessKey: -0.02
            ])

        var finalMask = maskImage.applyingFilter("CIMaskToAlpha")

        if let depthMap = depthMap,
           let depthMask = makeDepthMask(from: depthMap, guidedBy: visionMask, targetExtent: targetExtent) {
            let multiply = CIFilter.multiplyCompositing()
            multiply.inputImage = depthMask
            multiply.backgroundImage = finalMask
            if let combined = multiply.outputImage {
                finalMask = combined
            }
        }

        return finalMask.cropped(to: targetExtent)
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

@available(iOS 17.0, *)
private struct DepthStatistics {
    let foregroundUpperBound: Float

    init?(depthPixelBuffer: CVPixelBuffer, subjectMask: CVPixelBuffer?) {
        CVPixelBufferLockBaseAddress(depthPixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthPixelBuffer, .readOnly) }

        guard let depthBase = CVPixelBufferGetBaseAddress(depthPixelBuffer) else { return nil }

        let depthWidth = CVPixelBufferGetWidth(depthPixelBuffer)
        let depthHeight = CVPixelBufferGetHeight(depthPixelBuffer)
        let depthRowStride = CVPixelBufferGetBytesPerRow(depthPixelBuffer) / MemoryLayout<Float32>.stride
        let depthValues = depthBase.assumingMemoryBound(to: Float32.self)

        var samples: [Float] = []
        samples.reserveCapacity(5000)

        func appendSample(_ value: Float32) {
            if value.isFinite && value > 0 {
                samples.append(value)
            }
        }

        if let subjectMask = subjectMask {
            CVPixelBufferLockBaseAddress(subjectMask, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(subjectMask, .readOnly) }

            guard let maskBase = CVPixelBufferGetBaseAddress(subjectMask) else { return nil }

            let maskWidth = CVPixelBufferGetWidth(subjectMask)
            let maskHeight = CVPixelBufferGetHeight(subjectMask)
            let maskRowStride = CVPixelBufferGetBytesPerRow(subjectMask)
            let maskValues = maskBase.assumingMemoryBound(to: UInt8.self)

            let stepX = max(1, maskWidth / 200)
            let stepY = max(1, maskHeight / 200)

            for maskY in stride(from: 0, to: maskHeight, by: stepY) {
                let maskRow = maskValues.advanced(by: maskY * maskRowStride)
                let depthY = min(depthHeight - 1, Int(round(Float(maskY) * Float(depthHeight) / Float(maskHeight))))
                let depthRow = depthValues.advanced(by: depthY * depthRowStride)

                for maskX in stride(from: 0, to: maskWidth, by: stepX) {
                    let maskValue = maskRow[maskX]
                    if maskValue < 170 { continue }

                    let depthX = min(depthWidth - 1, Int(round(Float(maskX) * Float(depthWidth) / Float(maskWidth))))
                    appendSample(depthRow[depthX])
                }
            }
        }

        if samples.isEmpty {
            let stepX = max(1, depthWidth / 200)
            let stepY = max(1, depthHeight / 200)

            for depthY in stride(from: 0, to: depthHeight, by: stepY) {
                let depthRow = depthValues.advanced(by: depthY * depthRowStride)
                for depthX in stride(from: 0, to: depthWidth, by: stepX) {
                    appendSample(depthRow[depthX])
                }
            }
        }

        guard !samples.isEmpty else { return nil }

        samples.sort()

        func percentile(_ value: Double) -> Float {
            let clamped = min(1.0, max(0.0, value))
            let index = Int(clamped * Double(samples.count - 1))
            return samples[index]
        }

        let median = percentile(0.5)
        let lower = percentile(0.1)
        let upper = percentile(0.9)
        let spread = max(0.05, upper - lower)

        let bufferedUpper = min(max(upper + spread * 0.35, median + spread * 0.25), median + spread * 1.25) + 0.05
        foregroundUpperBound = max(bufferedUpper, 0.25)
    }
}

fileprivate extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
