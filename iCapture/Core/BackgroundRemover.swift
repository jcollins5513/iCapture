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
    private let depthForegroundThreshold: Float = 15.0 // retained for legacy paths

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

            if let processedData = processedImage.heifData() {
                completion(processedData)
            } else {
                print("BackgroundRemover: Failed to convert processed image to HEIF or JPEG data")
                completion(nil)
            }
        }
    }

    func removeBackgroundFromPhotoData(
        _ imageData: Data,
        depthMap: CVPixelBuffer,
        completion: @escaping (Data?) -> Void
    ) {
        guard let image = UIImage(data: imageData) else {
            print("BackgroundRemover: Failed to create UIImage from data")
            completion(nil)
            return
        }

        removeBackground(from: image, depthMap: depthMap) { processedImage in
            guard let processedImage = processedImage else {
                completion(nil)
                return
            }

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
        let normalizedImage = image.normalizedForProcessing()

        guard let cgImage = normalizedImage.cgImage else {
            print("BackgroundRemover: Failed to get CGImage")
            completion(nil)
            return
        }
        performForegroundSegmentation(
            cgImage: cgImage,
            depthMap: depthMap,
            originalImage: normalizedImage,
            completion: completion
        )
    }

    private func performForegroundSegmentation(
        cgImage: CGImage,
        depthMap: CVPixelBuffer?,
        originalImage: UIImage,
        completion: @escaping (UIImage?) -> Void
    ) {
        if #available(iOS 17.0, *) {
            let orientation = CGImagePropertyOrientation(originalImage.imageOrientation)
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

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
                    handler: handler,
                    to: originalImage,
                    cgImage: cgImage,
                    depthMap: depthMap
                )
                completion(processedImage)
            }

            request.qualityLevel = .accurate
            request.revision = VNGenerateForegroundInstanceMaskRequest.currentRevision

            do {
                try handler.perform([request])
            } catch {
                print("BackgroundRemover: Failed to perform foreground segmentation: \(error)")
                performSimpleBackgroundRemoval(image: originalImage, completion: completion)
            }
        } else {
            performSimpleBackgroundRemoval(image: originalImage, completion: completion)
        }
    }

    private func applyForegroundMask(
        _ segmentationResult: Any,
        handler: VNImageRequestHandler,
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
                // choose the best instance mask
                guard let maskPixelBuffer = dominantMaskPixelBuffer(from: observation, using: handler) else {
                    return performSimpleBackgroundRemovalSync(image: image)
                }

                let inputCIImage = CIImage(cgImage: cgImage)
                let inputExtent = inputCIImage.extent

                // refine the vision mask
                var visionMask = CIImage(cvPixelBuffer: maskPixelBuffer)
                visionMask = refinedMask(visionMask, targetExtent: inputExtent)

                // intersect with depth if present
                if let depthMap = depthMap,
                   let depthMask = makeDepthMask(
                        from: depthMap,
                        guidedBy: maskPixelBuffer,
                        targetExtent: inputExtent
                   ) {
                    let multiply = CIFilter.multiplyCompositing()
                    multiply.inputImage = depthMask
                    multiply.backgroundImage = visionMask
                    if let combined = multiply.outputImage {
                        visionMask = refinedMask(combined, targetExtent: inputExtent)
                    }
                }

                // blend over transparent background
                let blend = CIFilter.blendWithMask()
                blend.inputImage = inputCIImage
                blend.maskImage = visionMask
                let transparentBackground = CIImage(color: .clear).cropped(to: inputCIImage.extent)
                blend.backgroundImage = transparentBackground

                guard let outputCI = blend.outputImage,
                      let outputCG = ciContext.createCGImage(outputCI, from: outputCI.extent) else {
                    return performSimpleBackgroundRemovalSync(image: image)
                }
                return UIImage(cgImage: outputCG, scale: image.scale, orientation: .up)
            } catch {
                print("BackgroundRemover: Failed to apply mask: \(error)")
                return performSimpleBackgroundRemovalSync(image: image)
            }
        } else {
            return performSimpleBackgroundRemovalSync(image: image)
        }
    }

    // MARK: - Mask refinement helpers (iOS 17+)

    @available(iOS 17.0, *)
    private func refinedMask(_ mask: CIImage, targetExtent: CGRect) -> CIImage {
        var refined = mask.clampedToExtent()

        let contrast = CIFilter.colorControls()
        contrast.inputImage = refined
        contrast.saturation = 0
        contrast.brightness = -0.02
        contrast.contrast = 1.1
        if let adjusted = contrast.outputImage { refined = adjusted }

        let dilate = CIFilter.morphologyMaximum()
        dilate.inputImage = refined
        dilate.radius = 2.0
        if let dilated = dilate.outputImage { refined = dilated }

        let erode = CIFilter.morphologyMinimum()
        erode.inputImage = refined
        erode.radius = 1.5
        if let eroded = erode.outputImage { refined = eroded }

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = refined
        blur.radius = 0.8
        if let blurred = blur.outputImage { refined = blurred }

        return refined.cropped(to: targetExtent)
    }

    @available(iOS 17.0, *)
    private func dominantMaskPixelBuffer(
        from observation: VNInstanceMaskObservation,
        using handler: VNImageRequestHandler
    ) -> CVPixelBuffer? {
        let instances = observation.allInstances
        if instances.isEmpty {
            return try? observation.generateScaledMaskForImage(forInstances: instances, from: handler)
        }

        var bestScore: Float = -Float.greatestFiniteMagnitude
        var bestBuffer: CVPixelBuffer?

        for instance in instances {
            let selection = IndexSet(integer: instance)
            guard let mask = try? observation.generateScaledMaskForImage(forInstances: selection, from: handler) else {
                continue
            }
            let score = maskScore(mask)
            if score > bestScore {
                bestScore = score
                bestBuffer = mask
            }
        }

        if let bestBuffer { return bestBuffer }
        return try? observation.generateScaledMaskForImage(forInstances: instances, from: handler)
    }

    @available(iOS 17.0, *)
    private func maskScore(_ pixelBuffer: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return -Float.greatestFiniteMagnitude
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)

        var total: Float = 0
        var center: Float = 0

        let cx0 = Int(Float(width) * 0.25)
        let cx1 = Int(Float(width) * 0.75)
        let cy0 = Int(Float(height) * 0.25)
        let cy1 = Int(Float(height) * 0.75)

        for row in 0..<height {
            let rowPtr = pointer.advanced(by: row * bytesPerRow)
            for col in 0..<width {
                let v = Float(rowPtr[col])
                total += v
                if row >= cy0 && row < cy1 && col >= cx0 && col < cx1 { center += v }
            }
        }

        let pixelCount = Float(width * height)
        let coverage = total / (pixelCount * 255.0)

        let centerW = max(1, cx1 - cx0)
        let centerH = max(1, cy1 - cy0)
        let centerCoverage = center / (Float(centerW * centerH) * 255.0)

        return (coverage * 0.65) + (centerCoverage * 0.35)
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

        let attrs: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
        var maskBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            depthWidth,
            depthHeight,
            kCVPixelFormatType_OneComponent8,
            attrs as CFDictionary,
            &maskBuffer
        ) == kCVReturnSuccess, let mask = maskBuffer else { return nil }

        CVPixelBufferLockBaseAddress(mask, [])
        guard let maskBase = CVPixelBufferGetBaseAddress(mask) else {
            CVPixelBufferUnlockBaseAddress(mask, [])
            return nil
        }
        let maskRowStride = CVPixelBufferGetBytesPerRow(mask)
        let maskValues = maskBase.assumingMemoryBound(to: UInt8.self)

        for y in 0..<depthHeight {
            let depthRow = depthValues.advanced(by: y * depthRowStride)
            let maskRow = maskValues.advanced(by: y * maskRowStride)
            for x in 0..<depthWidth {
                let d = depthRow[x]
                maskRow[x] = (d > 0 && d <= foregroundUpperBound) ? 255 : 0
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

    // MARK: - Simple fallback

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
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return nil }
        let pixels = data.assumingMemoryBound(to: UInt8.self)

        for i in 0..<(width * height) {
            let idx = i * 4
            let r = pixels[idx]
            let g = pixels[idx + 1]
            let b = pixels[idx + 2]
            let brightness = (Int(r) + Int(g) + Int(b)) / 3
            if brightness > 220 { pixels[idx + 3] = 0 }
        }

        guard let outputCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
    }

    // MARK: - Sticker Generation

    func createStickerImage(from image: UIImage, padding: CGFloat = 24) -> UIImage? {
        let baseImage = image.normalizedForProcessing()

        guard let cgImage = baseImage.cgImage else { return nil }
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let pointer = CFDataGetBytePtr(data) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow

        var minX = width
        var maxX = -1
        var minY = height
        var maxY = -1

        for y in 0..<height {
            let row = pointer.advanced(by: y * bytesPerRow)
            for x in 0..<width {
                let alpha = row[x * bytesPerPixel + 3]
                if alpha > 12 { // Small threshold to ignore halo pixels
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }

        guard minX <= maxX, minY <= maxY else {
            return nil
        }

        let scaledPadding = Int((padding * baseImage.scale).rounded(.toNearestOrAwayFromZero))
        let cropMinX = max(0, minX - scaledPadding)
        let cropMaxX = min(width - 1, maxX + scaledPadding)
        let cropMinY = max(0, minY - scaledPadding)
        let cropMaxY = min(height - 1, maxY + scaledPadding)

        let cropRect = CGRect(
            x: cropMinX,
            y: cropMinY,
            width: cropMaxX - cropMinX + 1,
            height: cropMaxY - cropMinY + 1
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }

        let outputSize = CGSize(
            width: CGFloat(cropRect.width) / baseImage.scale,
            height: CGFloat(cropRect.height) / baseImage.scale
        )

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = baseImage.scale
        rendererFormat.opaque = false

        let renderer = UIGraphicsImageRenderer(size: outputSize, format: rendererFormat)

        let sticker = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))

            let oriented = UIImage(cgImage: cropped, scale: baseImage.scale, orientation: .up)
            oriented.draw(in: CGRect(origin: .zero, size: outputSize))
        }

        return sticker
    }

    func createStickerData(from imageData: Data, padding: CGFloat = 24) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        guard let stickerImage = createStickerImage(from: image, padding: padding) else { return nil }
        return stickerImage.pngData()
    }

    // MARK: - Sticker Generation

    func createStickerImage(from image: UIImage, padding: CGFloat = 24) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let pointer = CFDataGetBytePtr(data) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow

        var minX = width
        var maxX = -1
        var minY = height
        var maxY = -1

        for y in 0..<height {
            let row = pointer.advanced(by: y * bytesPerRow)
            for x in 0..<width {
                let alpha = row[x * bytesPerPixel + 3]
                if alpha > 12 { // Small threshold to ignore halo pixels
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }

        guard minX <= maxX, minY <= maxY else {
            return nil
        }

        let scaledPadding = Int((padding * image.scale).rounded(.toNearestOrAwayFromZero))
        let cropMinX = max(0, minX - scaledPadding)
        let cropMaxX = min(width - 1, maxX + scaledPadding)
        let cropMinY = max(0, minY - scaledPadding)
        let cropMaxY = min(height - 1, maxY + scaledPadding)

        let cropRect = CGRect(
            x: cropMinX,
            y: cropMinY,
            width: cropMaxX - cropMinX + 1,
            height: cropMaxY - cropMinY + 1
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }

        return UIImage(
            cgImage: cropped,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }

    func createStickerData(from imageData: Data, padding: CGFloat = 24) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        guard let stickerImage = createStickerImage(from: image, padding: padding) else { return nil }
        return stickerImage.pngData()
    }
}

// MARK: - UIImage Extension for HEIF Support

extension UIImage {
    func heifData() -> Data? {
        guard let cgImage = self.cgImage else { return nil }

        let data = NSMutableData()
        if let destination = CGImageDestinationCreateWithData(data, "public.heif" as CFString, 1, nil) {
            let options: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: 0.9,
                kCGImagePropertyHasAlpha: true
            ]
            CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
            CGImageDestinationFinalize(destination)
            return data as Data
        } else {
            print("BackgroundRemover: HEIF not supported, falling back to JPEG")
            return self.jpegData(compressionQuality: 0.9)
        }
    }
}

private extension UIImage {
    func normalizedForProcessing() -> UIImage {
        guard imageOrientation != .up else { return self }
        guard size != .zero else { return self }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
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
        @unknown default: self = .up
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
            if value.isFinite && value > 0 { samples.append(value) }
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
            for y in stride(from: 0, to: depthHeight, by: stepY) {
                let depthRow = depthValues.advanced(by: y * depthRowStride)
                for x in stride(from: 0, to: depthWidth, by: stepX) { appendSample(depthRow[x]) }
            }
        }

        guard !samples.isEmpty else { return nil }
        samples.sort()

        func percentile(_ p: Double) -> Float {
            let clamped = min(1.0, max(0.0, p))
            let idx = Int(clamped * Double(samples.count - 1))
            return samples[idx]
        }

        let median = percentile(0.5)
        let lower = percentile(0.1)
        let upper = percentile(0.9)
        let spread = max(0.05, upper - lower)

        let bufferedUpper = min(
            max(upper + spread * 0.35, median + spread * 0.25),
            median + spread * 1.25
        ) + 0.05

        foregroundUpperBound = max(bufferedUpper, 0.25)
    }
}