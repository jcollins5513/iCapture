import Foundation
import AVFoundation
import UIKit
import ARKit

extension CameraManager {
    func processBackgroundRemoval(
        imageData: Data,
        filename: String,
        depthData: AVDepthData?,
        sessionFileURL: URL?
    ) {
        print("CameraManager: Starting background removal for \(filename)")

        if let depthData = depthData {
            processDepthBasedBackgroundRemoval(
                imageData: imageData,
                filename: filename,
                depthData: depthData,
                sessionFileURL: sessionFileURL
            )
        } else {
            handleBackgroundRemovalFallback(
                imageData: imageData,
                filename: filename,
                sessionFileURL: sessionFileURL
            )
        }
    }

    private func processDepthBasedBackgroundRemoval(
        imageData: Data,
        filename: String,
        depthData: AVDepthData,
        sessionFileURL: URL?
    ) {
        print("CameraManager: Using photo depth data for background removal")
        let convertedDepth = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let depthMap = convertedDepth.depthDataMap

        backgroundRemover.removeBackgroundFromPhotoData(
            imageData,
            depthMap: depthMap
        ) { [weak self] processedData in
            guard let self else { return }

            if let processedData = processedData {
                self.handleBackgroundRemovalCompletion(
                    processedData: processedData,
                    originalData: imageData,
                    filename: filename,
                    sourceDescription: "Vision + photo depth",
                    sessionFileURL: sessionFileURL
                )
            } else {
                print("CameraManager: Vision+depth removal failed, falling back to LiDAR-only mask")
                self.lidarBackgroundRemover.removeBackgroundFromPhotoData(
                    imageData: imageData,
                    depthData: convertedDepth
                ) { [weak self] fallbackData in
                    self?.handleBackgroundRemovalCompletion(
                        processedData: fallbackData,
                        originalData: imageData,
                        filename: filename,
                        sourceDescription: "LiDAR-only fallback",
                        sessionFileURL: sessionFileURL
                    )
                }
            }
        }
    }

    private func handleBackgroundRemovalFallback(
        imageData: Data,
        filename: String,
        sessionFileURL: URL?
    ) {
        if useLiDARDetection,
           lidarDetector.isLiDARAvailable,
           let latestDepth = lidarDetector.latestDepthData {
            print("CameraManager: Using cached LiDAR depth data for background removal")
            backgroundRemover.removeBackgroundFromPhotoData(
                imageData,
                depthMap: latestDepth.depthMap
            ) { [weak self] processedData in
                guard let self else { return }

                if let processedData = processedData {
                    self.handleBackgroundRemovalCompletion(
                        processedData: processedData,
                        originalData: imageData,
                        filename: filename,
                        sourceDescription: "Vision + LiDAR scan",
                        sessionFileURL: sessionFileURL
                    )
                } else {
                    print("CameraManager: Cached LiDAR depth fusion failed, using LiDAR-only mask")
                    self.lidarBackgroundRemover.removeBackgroundFromPhotoData(
                        imageData: imageData,
                        depthData: latestDepth
                    ) { [weak self] fallbackData in
                        self?.handleBackgroundRemovalCompletion(
                            processedData: fallbackData,
                            originalData: imageData,
                            filename: filename,
                            sourceDescription: "LiDAR scan fallback",
                            sessionFileURL: sessionFileURL
                        )
                    }
                }
            }
        } else {
            print("CameraManager: Falling back to Vision-based background removal")
            backgroundRemover.removeBackgroundFromPhotoData(imageData) { [weak self] processedData in
                self?.handleBackgroundRemovalCompletion(
                    processedData: processedData,
                    originalData: imageData,
                    filename: filename,
                    sourceDescription: "Vision fallback",
                    sessionFileURL: sessionFileURL
                )
            }
        }
    }

    private func handleBackgroundRemovalCompletion(
        processedData: Data?,
        originalData: Data,
        filename: String,
        sourceDescription: String,
        sessionFileURL: URL?
    ) {
        DispatchQueue.main.async {
            guard let processedData = processedData else {
                print("CameraManager: Background removal failed for \(filename)")
                self.saveToPhotoLibrary(imageData: originalData)
                return
            }

            print("CameraManager: Background removal completed for \(filename) using \(sourceDescription)")

            if let processedImage = UIImage(data: processedData) {
                let normalizedImage = processedImage

                if let stickerImage = self.backgroundRemover.createStickerImage(from: normalizedImage) {
                    self.persistStickerImage(
                        stickerImage,
                        originalFilename: filename
                    )
                }

                self.persistCutoutImage(
                    normalizedImage,
                    originalFilename: filename,
                    sessionFileURL: sessionFileURL
                )

                UIImageWriteToSavedPhotosAlbum(normalizedImage, nil, nil, nil)
                print("CameraManager: Background-removed photo saved to photo library")
            } else {
                print("CameraManager: Unable to decode processed image data; saving original instead")
                self.saveToPhotoLibrary(imageData: originalData)
            }
        }
    }

    private func persistStickerImage(
        _ stickerImage: UIImage,
        originalFilename: String
    ) {
        guard let sessionManager = sessionManager,
              sessionManager.isSessionActive,
              let sessionDirectory = sessionManager.sessionDirectory else {
            return
        }

        let stickersDirectory = sessionDirectory.appendingPathComponent("stickers", isDirectory: true)
        let fileManager = FileManager.default

        do {
            if !fileManager.fileExists(atPath: stickersDirectory.path) {
                try fileManager.createDirectory(
                    at: stickersDirectory,
                    withIntermediateDirectories: true
                )
            }

            let baseName = (originalFilename as NSString).deletingPathExtension
            let stickerFilename = "\(baseName)_sticker.png"
            let stickerURL = stickersDirectory.appendingPathComponent(stickerFilename)

            guard let stickerData = stickerImage.pngData() else {
                print("CameraManager: Failed to create PNG data for sticker")
                return
            }

            try stickerData.write(to: stickerURL, options: .atomic)
            sessionManager.attachSticker(
                toOriginalFilename: originalFilename,
                stickerFilename: stickerFilename
            )
            print("CameraManager: Saved sticker to \(stickerURL.lastPathComponent)")
        } catch {
            print("CameraManager: Failed to persist sticker image: \(error)")
        }
    }

    private func persistCutoutImage(
        _ cutoutImage: UIImage,
        originalFilename: String,
        sessionFileURL: URL?
    ) {
        guard let sessionManager = sessionManager,
              sessionManager.isSessionActive,
              let sessionDirectory = sessionManager.sessionDirectory,
              let pngData = cutoutImage.pngData() else {
            return
        }

        let cutoutsDirectory = sessionDirectory.appendingPathComponent("cutouts", isDirectory: true)
        let fileManager = FileManager.default

        do {
            if !fileManager.fileExists(atPath: cutoutsDirectory.path) {
                try fileManager.createDirectory(at: cutoutsDirectory, withIntermediateDirectories: true)
            }

            let baseName = (originalFilename as NSString).deletingPathExtension
            let cutoutFilename = "\(baseName)_cutout.png"
            let cutoutURL = cutoutsDirectory.appendingPathComponent(cutoutFilename)
            try pngData.write(to: cutoutURL, options: .atomic)

            sessionManager.attachCutout(
                toOriginalFilename: originalFilename,
                cutoutFilename: cutoutFilename
            )

            print("CameraManager: Saved transparent cutout to \(cutoutURL.lastPathComponent)")

            if let sessionFileURL {
                print("CameraManager: Original capture preserved at \(sessionFileURL.lastPathComponent)")
            }
        } catch {
            print("CameraManager: Failed to persist cutout image: \(error)")
        }
    }
}
