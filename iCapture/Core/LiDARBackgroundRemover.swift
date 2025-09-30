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
import CoreImage.CIFilterBuiltins
import Combine

@MainActor
class LiDARBackgroundRemover: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var processedImage: UIImage?

    private let ciContext = CIContext()

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
        let input = CIImage(cgImage: cgImage)
        var maskCI = CIImage(cvPixelBuffer: mask)

        // Scale mask to match image extent
        let sx = input.extent.width / maskCI.extent.width
        let sy = input.extent.height / maskCI.extent.height
        maskCI = maskCI.transformed(by: CGAffineTransform(scaleX: sx, y: sy))

        // Lightly blur for softer edges
        maskCI = maskCI.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.2])

        let blend = CIFilter.blendWithMask()
        blend.inputImage = input
        blend.maskImage = maskCI
        let transparentBackground = CIImage(color: .clear).cropped(to: input.extent)
        blend.backgroundImage = transparentBackground // transparent

        guard let out = blend.outputImage,
              let outCG = ciContext.createCGImage(out, from: out.extent) else {
            return nil
        }
        return UIImage(cgImage: outCG)
    }
}

// Note: heifData() extension is already defined in BackgroundRemover.swift
