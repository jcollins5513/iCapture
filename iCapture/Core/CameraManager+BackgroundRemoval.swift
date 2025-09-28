import Foundation
import AVFoundation
import UIKit

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

        lidarBackgroundRemover.removeBackgroundFromPhotoData(
            imageData: imageData,
            depthData: depthData
        ) { [weak self] processedData in
            self?.handleBackgroundRemovalCompletion(
                processedData: processedData,
                originalData: imageData,
                filename: filename,
                sourceDescription: "photo depth",
                sessionFileURL: sessionFileURL
            )
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
            lidarBackgroundRemover.removeBackgroundFromPhotoData(
                imageData: imageData,
                depthData: latestDepth
            ) { [weak self] processedData in
                self?.handleBackgroundRemovalCompletion(
                    processedData: processedData,
                    originalData: imageData,
                    filename: filename,
                    sourceDescription: "LiDAR scan",
                    sessionFileURL: sessionFileURL
                )
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

            if let sessionFileURL = sessionFileURL {
                do {
                    try processedData.write(to: sessionFileURL, options: .atomic)
                    print("CameraManager: Overwrote session photo with background-removed version")
                } catch {
                    print("CameraManager: Failed to write processed photo to session directory: \(error)")
                }
            }

            if let processedImage = UIImage(data: processedData) {
                UIImageWriteToSavedPhotosAlbum(processedImage, nil, nil, nil)
                print("CameraManager: Background-removed photo saved to photo library")
            }

            self.saveToPhotoLibrary(imageData: originalData)
        }
    }
}
