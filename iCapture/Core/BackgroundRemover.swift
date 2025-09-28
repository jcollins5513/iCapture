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
import Combine

@MainActor
class BackgroundRemover: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var processedImage: UIImage?

    private let processingQueue = DispatchQueue(label: "background.removal.queue", qos: .userInitiated)

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
            self?.performBackgroundRemoval(image: image) { result in
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

    private func performBackgroundRemoval(image: UIImage, completion: @escaping (UIImage?) -> Void) {
        guard let cgImage = image.cgImage else {
            print("BackgroundRemover: Failed to get CGImage")
            completion(nil)
            return
        }

        // Use Vision framework's foreground instance mask generation
        performForegroundSegmentation(cgImage: cgImage, originalImage: image, completion: completion)
    }

    private func performForegroundSegmentation(
        cgImage: CGImage,
        originalImage: UIImage,
        completion: @escaping (UIImage?) -> Void
    ) {
        let request = VNGenerateForegroundInstanceMaskRequest { request, error in
            if let error = error {
                print("BackgroundRemover: Foreground segmentation failed: \(error)")
                // Fallback to simple background removal
                self.performSimpleBackgroundRemoval(image: originalImage, completion: completion)
                return
            }

            guard let results = request.results, let result = results.first else {
                print("BackgroundRemover: No segmentation results")
                // Fallback to simple background removal
                self.performSimpleBackgroundRemoval(image: originalImage, completion: completion)
                return
            }

            // Apply the segmentation mask to create transparent background
            let processedImage = self.applyForegroundMask(result, to: originalImage, cgImage: cgImage)
            completion(processedImage)
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("BackgroundRemover: Failed to perform foreground segmentation: \(error)")
            // Fallback to simple background removal
            performSimpleBackgroundRemoval(image: originalImage, completion: completion)
        }
    }

    private func applyForegroundMask(_ segmentationResult: Any, to image: UIImage, cgImage: CGImage) -> UIImage? {
        print("BackgroundRemover: Applying foreground mask to image")

        // For now, use the simple background removal approach
        // In a future implementation, we would properly handle the Vision framework results
        return performSimpleBackgroundRemovalSync(image: image)
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
