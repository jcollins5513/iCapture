//
//  CameraManager+PhotoCapture.swift
//  iCapture
//
//  Created by Codex on 10/13/25.
//

import AVFoundation
import Foundation
import UIKit

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }

        // Record capture end for performance monitoring
        DispatchQueue.main.async {
            self.performanceMonitor.recordCaptureEnd()
        }

        // Save photo to appropriate directory
        photoQueue.async { [weak self] in
            guard let self = self else { return }
            let triggerType = self.pendingTriggerType
            defer { self.pendingTriggerType = .manual }

            guard let imageData = photo.fileDataRepresentation() else {
                print("Failed to get image data")
                return
            }

            let width = photo.resolvedSettings.photoDimensions.width
            let height = photo.resolvedSettings.photoDimensions.height

            let roiRect = DispatchQueue.main.sync {
                self.roiDetector.getROIRect()
            }

            var depthData = photo.depthData?.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
            if let orientationValue = photo.metadata[kCGImagePropertyOrientation as String] as? UInt32,
               let orientation = CGImagePropertyOrientation(rawValue: orientationValue) {
                depthData = depthData?.applyingExifOrientation(orientation)
            }

            let timestamp = Date().timeIntervalSince1970
            let resolutionSuffix = (width >= 8_000 || height >= 6_000) ? "_48MP" : "_12MP"
            let filename = "photo_\(Int(timestamp))\(resolutionSuffix).heic"

            let fileSizeMB = Double(imageData.count) / (1_024 * 1_024)
            let isHighResolution = (width >= 8_000 || height >= 6_000)
            let maxSizeMB = isHighResolution ? 15.0 : 5.0

            let widthInt = Int(width)
            let heightInt = Int(height)
            print(
                "CameraManager: Captured photo - Resolution: \(widthInt)x\(heightInt), " +
                "Size: \(String(format: "%.2f", fileSizeMB))MB"
            )

            if fileSizeMB > maxSizeMB {
                print(
                    "CameraManager: WARNING - Photo size (\(String(format: "%.2f", fileSizeMB))MB) " +
                    "exceeds target (\(maxSizeMB)MB)"
                )
            } else {
                print("CameraManager: Photo size within target limits")
            }

            let isSessionActive = DispatchQueue.main.sync {
                self.sessionManager?.isSessionActive ?? false
            }

            if isSessionActive {
                let params = PhotoSessionParams(
                    imageData: imageData,
                    filename: filename,
                    width: widthInt,
                    height: heightInt,
                    roiRect: roiRect,
                    triggerType: triggerType,
                    depthData: depthData
                )
                DispatchQueue.main.async {
                    self.savePhotoToSession(params)
                }
            } else {
                DispatchQueue.main.async {
                    self.saveTestShot(imageData: imageData, filename: filename)
                }
            }
        }
    }

    struct PhotoSessionParams {
        let imageData: Data
        let filename: String
        let width: Int
        let height: Int
        let roiRect: CGRect
        let triggerType: TriggerType
        let depthData: AVDepthData?
    }

    @MainActor
    func savePhotoToSession(_ params: PhotoSessionParams) {
        guard let sessionManager = sessionManager,
              let session = sessionManager.currentSession,
              let sessionURL = sessionManager.sessionDirectory else {
            print("No active session - saving as test shot")
            saveTestShot(imageData: params.imageData, filename: params.filename)
            return
        }

        do {
            // Save to photos subdirectory
            let photosURL = sessionURL.appendingPathComponent("photos")
            let fileURL = photosURL.appendingPathComponent(params.filename)
            try params.imageData.write(to: fileURL)

            // Ensure the file was written successfully
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("CameraManager: Failed to write photo file: \(fileURL.path)")
                return
            }

            // Create capture asset
            let asset = CaptureAsset(
                sessionId: session.id,
                type: .photo,
                filename: params.filename,
                width: params.width,
                height: params.height,
                roiRect: params.roiRect,
                triggerType: params.triggerType
            )

            // Add asset to session
            try sessionManager.addAsset(asset)

            print("Photo saved to session: \(params.filename)")

            // Process background removal if enabled
            if self.backgroundRemovalEnabled {
                self.processBackgroundRemoval(
                    imageData: params.imageData,
                    filename: params.filename,
                    depthData: params.depthData,
                    sessionFileURL: fileURL
                )
            } else {
                if self.saveToPhotoLibraryAutomatically {
                    self.saveToPhotoLibrary(imageData: params.imageData)
                }
            }

            DispatchQueue.main.async {
                self.testShotCaptured = true
            }
        } catch {
            print("Failed to save photo to session: \(error)")
        }
    }

    @MainActor
    func saveTestShot(imageData: Data, filename: String) {
        // Create test shots directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let testShotsDirectory = documentsPath.appendingPathComponent("TestShots")

        try? FileManager.default.createDirectory(at: testShotsDirectory, withIntermediateDirectories: true)

        // Save with timestamp
        let fileURL = testShotsDirectory.appendingPathComponent(filename)

        do {
            try imageData.write(to: fileURL)
            print("Test shot saved: \(fileURL)")

            DispatchQueue.main.async {
                self.testShotCaptured = true
            }
        } catch {
            print("Failed to save test shot: \(error)")
        }
    }
}
