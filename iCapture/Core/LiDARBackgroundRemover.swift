//
//  LiDARBackgroundRemover.swift
//  iCapture
//
//  Created by Justin Collins on 9/28/25.
//

import ARKit
import AVFoundation
import UIKit
import CoreImage
import Combine

@MainActor
class LiDARBackgroundRemover: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var processedImage: UIImage?

    // LiDAR configuration
    private let backgroundDepthThreshold: Float = 15.0 // 15+ meters is background

    // MARK: - Public Interface

    func removeBackground(
        image: UIImage,
        depthMap: CVPixelBuffer,
        completion: @escaping (UIImage?) -> Void
    ) {
        guard !isProcessing else {
            print("LiDARBackgroundRemover: Already processing, skipping request")
            completion(nil)
            return
        }

        isProcessing = true
        processingProgress = 0.0

        let result = performBackgroundRemoval(image: image, depthMap: depthMap)
        isProcessing = false
        processingProgress = 1.0
        processedImage = result
        completion(result)
    }

    func removeBackground(
        image: UIImage,
        depthData: ARDepthData,
        completion: @escaping (UIImage?) -> Void
    ) {
        removeBackground(image: image, depthMap: depthData.depthMap, completion: completion)
    }

    func removeBackground(
        image: UIImage,
        depthData: AVDepthData,
        completion: @escaping (UIImage?) -> Void
    ) {
        let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        removeBackground(image: image, depthMap: converted.depthDataMap, completion: completion)
    }

    func removeBackgroundFromPhotoData(
        imageData: Data,
        depthMap: CVPixelBuffer,
        completion: @escaping (Data?) -> Void
    ) {
        guard let image = UIImage(data: imageData) else {
            print("LiDARBackgroundRemover: Failed to create UIImage from data")
            completion(nil)
            return
        }

        removeBackground(image: image, depthMap: depthMap) { processedImage in
            guard let processedImage = processedImage else {
                completion(nil)
                return
            }

            if let processedData = processedImage.heifData() {
                completion(processedData)
            } else {
                print("LiDARBackgroundRemover: Failed to convert processed image to data")
                completion(nil)
            }
        }
    }

    func removeBackgroundFromPhotoData(
        imageData: Data,
        depthData: ARDepthData,
        completion: @escaping (Data?) -> Void
    ) {
        removeBackgroundFromPhotoData(
            imageData: imageData,
            depthMap: depthData.depthMap,
            completion: completion
        )
    }

    func removeBackgroundFromPhotoData(
        imageData: Data,
        depthData: AVDepthData,
        completion: @escaping (Data?) -> Void
    ) {
        let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        removeBackgroundFromPhotoData(
            imageData: imageData,
            depthMap: converted.depthDataMap,
            completion: completion
        )
    }

    // MARK: - Private Methods

    private func performBackgroundRemoval(
        image: UIImage,
        depthMap: CVPixelBuffer
    ) -> UIImage? {
        guard let cgImage = image.cgImage else {
            print("LiDARBackgroundRemover: Failed to get CGImage")
            return nil
        }

        guard let mask = createDepthBasedMask(depthMap: depthMap, imageSize: image.size) else {
            print("LiDARBackgroundRemover: Failed to create depth mask")
            return nil
        }

        guard let processedImage = applyMaskToImage(cgImage: cgImage, mask: mask) else {
            print("LiDARBackgroundRemover: Failed to apply mask to image")
            return nil
        }

        return processedImage
    }

    private func createDepthBasedMask(depthMap: CVPixelBuffer, imageSize: CGSize) -> CVPixelBuffer? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let depthData = CVPixelBufferGetBaseAddress(depthMap) else { return nil }

        let depthValues = depthData.assumingMemoryBound(to: Float32.self)
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        // Create mask pixel buffer
        let maskAttributes: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        var maskBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent8,
            maskAttributes as CFDictionary,
            &maskBuffer
        )

        guard status == kCVReturnSuccess, let mask = maskBuffer else { return nil }

        CVPixelBufferLockBaseAddress(mask, [])
        defer { CVPixelBufferUnlockBaseAddress(mask, []) }

        guard let maskData = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let maskValues = maskData.assumingMemoryBound(to: UInt8.self)

        // Create mask based on depth values
        for row in 0..<height {
            for col in 0..<width {
                let depthIndex = row * width + col
                let maskIndex = row * width + col

                let depth = depthValues[depthIndex]

                // Set mask value based on depth
                if depth > 0 && depth <= backgroundDepthThreshold {
                    // Vehicle range - keep pixel (white in mask)
                    maskValues[maskIndex] = 255
                } else {
                    // Background - remove pixel (black in mask)
                    maskValues[maskIndex] = 0
                }
            }
        }

        return mask
    }

    private func applyMaskToImage(cgImage: CGImage, mask: CVPixelBuffer) -> UIImage? {
        let width = cgImage.width
        let height = cgImage.height

        // Create context for processing
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        // Draw original image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply mask
        applyMaskToContext(context, mask: mask, imageSize: CGSize(width: width, height: height))

        // Create result image
        guard let resultCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: resultCGImage)
    }

    private func applyMaskToContext(_ context: CGContext, mask: CVPixelBuffer, imageSize: CGSize) {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        guard let maskData = CVPixelBufferGetBaseAddress(mask) else { return }
        let maskValues = maskData.assumingMemoryBound(to: UInt8.self)

        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)

        // Scale mask to image size
        let scaleX = imageSize.width / CGFloat(width)
        let scaleY = imageSize.height / CGFloat(height)

        // Apply mask to image data
        guard let imageData = context.data else { return }
        let pixels = imageData.assumingMemoryBound(to: UInt8.self)

        for row in 0..<Int(imageSize.height) {
            for col in 0..<Int(imageSize.width) {
                let pixelIndex = (row * Int(imageSize.width) + col) * 4

                // Calculate corresponding mask coordinates
                let maskRow = Int(CGFloat(row) / scaleY)
                let maskCol = Int(CGFloat(col) / scaleX)

                if maskRow < height && maskCol < width {
                    let maskIndex = maskRow * width + maskCol
                    let maskValue = maskValues[maskIndex]

                    // Apply mask (0 = transparent, 255 = opaque)
                    let alpha = maskValue
                    pixels[pixelIndex + 3] = alpha
                }
            }
        }
    }
}

// Note: heifData() extension is already defined in BackgroundRemover.swift
