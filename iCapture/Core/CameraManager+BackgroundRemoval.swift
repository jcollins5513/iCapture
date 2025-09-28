import Foundation
import AVFoundation
import UIKit

extension CameraManager {
    func processBackgroundRemoval(
        imageData: Data,
        filename: String,
        depthData: AVDepthData?
    ) {
        print("CameraManager: Starting background removal for \(filename)")

        if let depthData = depthData {
            processDepthBasedBackgroundRemoval(
                imageData: imageData,
                filename: filename,
                depthData: depthData
            )
        } else {
            handleBackgroundRemovalFallback(imageData: imageData, filename: filename)
        }
    }

    private func processDepthBasedBackgroundRemoval(
        imageData: Data,
        filename: String,
        depthData: AVDepthData
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
                sourceDescription: "photo depth"
            )
        }
    }

    private func handleBackgroundRemovalFallback(imageData: Data, filename: String) {
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
                    sourceDescription: "LiDAR scan"
                )
            }
        } else {
            print("CameraManager: Falling back to Vision-based background removal")
            backgroundRemover.removeBackgroundFromPhotoData(imageData) { [weak self] processedData in
                self?.handleBackgroundRemovalCompletion(
                    processedData: processedData,
                    originalData: imageData,
                    filename: filename,
                    sourceDescription: "Vision fallback"
                )
            }
        }
    }

    private func handleBackgroundRemovalCompletion(
        processedData: Data?,
        originalData: Data,
        filename: String,
        sourceDescription: String
    ) {
        DispatchQueue.main.async {
            guard let processedData = processedData else {
                print("CameraManager: Background removal failed for \(filename)")
                self.saveToPhotoLibrary(imageData: originalData)
                return
            }

            print("CameraManager: Background removal completed for \(filename) using \(sourceDescription)")

            if let processedImage = UIImage(data: processedData) {
                UIImageWriteToSavedPhotosAlbum(processedImage, nil, nil, nil)
                print("CameraManager: Background-removed photo saved to photo library")
            }

            self.saveToPhotoLibrary(imageData: originalData)
        }
    }
}
