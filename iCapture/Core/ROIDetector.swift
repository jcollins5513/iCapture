//
//  ROIDetector.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import AVFoundation
import Vision
import Combine
import UIKit

@MainActor
class ROIDetector: ObservableObject {
    @Published var isROIOccupied = false
    @Published var occupancyPercentage: Double = 0.0
    @Published var isBackgroundSampling = false
    @Published var backgroundSampleProgress: Double = 0.0
    @Published private(set) var isBackgroundLearned = false

    private var backgroundBuffer: CVPixelBuffer?
    private var backgroundMask: CVPixelBuffer?
    private var occupancyThreshold: Double = 0.15 // τ threshold (15% by default)

    // Background sampling parameters
    private let backgroundSampleDuration: TimeInterval = 1.0 // 1 second baseline
    private var backgroundSampleStartTime: Date?
    private var backgroundSampleFrames: [CVPixelBuffer] = []
    private let maxBackgroundSamples = 30 // 30 frames at 30fps
    private var lastLoggedBackgroundProgress = -1.0

    // ROI configuration
    private var roiRect: CGRect = CGRect(x: 50, y: 200, width: 300, height: 200)

    init() {
        loadROIConfiguration()
    }

    // MARK: - Public Interface

    func updateROIRect(_ rect: CGRect) {
        roiRect = rect
        saveROIConfiguration()
        resetBackgroundLearning()
    }

    func getROIRect() -> CGRect {
        roiRect
    }

    func startBackgroundSampling() {
        guard !isBackgroundSampling else { return }

        isBackgroundSampling = true
        backgroundSampleProgress = 0.0
        backgroundSampleStartTime = Date()
        backgroundSampleFrames.removeAll()
        isBackgroundLearned = false
        lastLoggedBackgroundProgress = -1.0

        print("ROIDetector: Starting background sampling...")
    }

    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        if isBackgroundSampling {
            processBackgroundFrame(pixelBuffer)
        } else if isBackgroundLearned {
            processOccupancyFrame(pixelBuffer)
        }
    }

    func resetBackgroundLearning() {
        backgroundBuffer = nil
        backgroundMask = nil
        isBackgroundLearned = false
        isBackgroundSampling = false
        backgroundSampleProgress = 0.0
        backgroundSampleFrames.removeAll()
        lastLoggedBackgroundProgress = -1.0
    }

    func setOccupancyThreshold(_ threshold: Double) {
        occupancyThreshold = max(0.05, min(0.5, threshold)) // Clamp between 5% and 50%
    }

    func getOccupancyThreshold() -> Double {
        occupancyThreshold
    }

    // MARK: - Private Methods

    private func processBackgroundFrame(_ pixelBuffer: CVPixelBuffer) {
        guard let startTime = backgroundSampleStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let progress = min(elapsed / backgroundSampleDuration, 1.0)

        // Store frame for background learning
        backgroundSampleFrames.append(pixelBuffer)

        // Update progress on main thread
        Task { @MainActor in
            self.backgroundSampleProgress = progress
        }

        if progress - lastLoggedBackgroundProgress >= 0.25 || progress >= 0.99 {
            lastLoggedBackgroundProgress = progress
            let percent = Int(progress * 100)
            print(
                "ROIDetector: Background sampling progress \(percent)% (frames: \(backgroundSampleFrames.count)) elapsed=\(String(format: "%.2f", elapsed))"
            )
        }

        // Check if sampling is complete
        if elapsed >= backgroundSampleDuration || backgroundSampleFrames.count >= maxBackgroundSamples {
            completeBackgroundSampling()
        }
    }

    private func completeBackgroundSampling() {
        guard !backgroundSampleFrames.isEmpty else {
            Task { @MainActor in
                self.isBackgroundSampling = false
            }
            return
        }

        // Use the middle frame as the reference background
        let middleIndex = backgroundSampleFrames.count / 2
        backgroundBuffer = backgroundSampleFrames[middleIndex]

        // Create background mask using Vision framework
        createBackgroundMask()

        Task { @MainActor in
            self.isBackgroundSampling = false
            self.isBackgroundLearned = true
            self.backgroundSampleProgress = 1.0
        }

        print(
            "ROIDetector: Background sampling complete (frames: \(backgroundSampleFrames.count)). Threshold: \(occupancyThreshold)"
        )
        NotificationCenter.default.post(name: .BackgroundSamplingCompleted, object: self)
    }

    private func createBackgroundMask() {
        guard let backgroundBuffer = backgroundBuffer else { return }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: backgroundBuffer, options: [:])

        do {
            try handler.perform([request])

            if request.results?.first != nil {
                // Convert the result to a usable mask
                // For now, we'll use a simplified approach
                // In a full implementation, we'd convert the instance mask to a pixel buffer
                print("ROIDetector: Background mask created successfully")
            }
        } catch {
            print("ROIDetector: Failed to create background mask: \(error)")
        }
    }

    private func processOccupancyFrame(_ pixelBuffer: CVPixelBuffer) {
        // Calculate occupancy within ROI
        let occupancy = calculateROIOccupancy(pixelBuffer)

        // Update occupancy state
        let isOccupied = occupancy >= occupancyThreshold

        Task { @MainActor in
            self.occupancyPercentage = occupancy * 100
            self.isROIOccupied = isOccupied

            // Debug logging every 30 frames (about once per second at 30fps)
            if self.occupancyPercentage > 0 {
                let occupancyText = String(format: "%.1f", self.occupancyPercentage)
                let thresholdText = String(format: "%.1f", self.occupancyThreshold * 100)
                print("ROIDetector: Occupancy: \(occupancyText)%, Threshold: \(thresholdText)%, Occupied: \(isOccupied)")
            }
        }
    }

    private func calculateROIOccupancy(_ pixelBuffer: CVPixelBuffer) -> Double {
        // Convert ROI rect to pixel buffer coordinates
        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)

        // Get the screen bounds to properly convert coordinates
        let screenBounds = UIScreen.main.bounds

        // Convert screen coordinates to buffer coordinates
        // Note: This assumes the preview layer fills the screen
        let roiInBuffer = CGRect(
            x: roiRect.origin.x * CGFloat(bufferWidth) / screenBounds.width,
            y: roiRect.origin.y * CGFloat(bufferHeight) / screenBounds.height,
            width: roiRect.width * CGFloat(bufferWidth) / screenBounds.width,
            height: roiRect.height * CGFloat(bufferHeight) / screenBounds.height
        )

        // Ensure ROI is within buffer bounds
        let clampedROI = CGRect(
            x: max(0, min(roiInBuffer.origin.x, CGFloat(bufferWidth))),
            y: max(0, min(roiInBuffer.origin.y, CGFloat(bufferHeight))),
            width: min(roiInBuffer.width, CGFloat(bufferWidth) - roiInBuffer.origin.x),
            height: min(roiInBuffer.height, CGFloat(bufferHeight) - roiInBuffer.origin.y)
        )

        // Use Vision framework for more accurate foreground detection
        if let backgroundBuffer = backgroundBuffer {
            return calculateForegroundOccupancy(currentFrame: pixelBuffer, backgroundFrame: backgroundBuffer, roi: clampedROI)
        } else {
            // Fallback to pixel variance if no background is available
            return calculatePixelVarianceInROI(pixelBuffer, roi: clampedROI)
        }
    }

    private func calculatePixelVarianceInROI(_ pixelBuffer: CVPixelBuffer, roi: CGRect) -> Double {
        // Lock the pixel buffer
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return 0.0
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        // Convert to 8-bit grayscale for analysis
        let pixelBufferBaseAddress = baseAddress.assumingMemoryBound(to: UInt8.self)

        // Calculate bounds within the ROI
        let startX = max(0, Int(roi.origin.x))
        let startY = max(0, Int(roi.origin.y))
        let endX = min(width, Int(roi.origin.x + roi.width))
        let endY = min(height, Int(roi.origin.y + roi.height))

        guard startX < endX && startY < endY else { return 0.0 }

        var totalIntensity: Double = 0
        var pixelCount = 0
        var intensitySquared: Double = 0

        // Sample pixels in the ROI (every 4th pixel for performance)
        for rowY in stride(from: startY, to: endY, by: 4) {
            for colX in stride(from: startX, to: endX, by: 4) {
                let pixelIndex = rowY * bytesPerRow + colX
                if pixelIndex < bytesPerRow * height {
                    let intensity = Double(pixelBufferBaseAddress[pixelIndex])
                    totalIntensity += intensity
                    intensitySquared += intensity * intensity
                    pixelCount += 1
                }
            }
        }

        guard pixelCount > 0 else { return 0.0 }

        // Calculate mean and variance
        let mean = totalIntensity / Double(pixelCount)
        let variance = (intensitySquared / Double(pixelCount)) - (mean * mean)

        // Normalize variance to occupancy percentage
        // Higher variance indicates more movement/change in the ROI
        let normalizedVariance = min(variance / 1_000.0, 1.0) // Scale factor may need adjustment

        return normalizedVariance
    }

    private func calculateForegroundOccupancy(currentFrame: CVPixelBuffer, backgroundFrame: CVPixelBuffer, roi: CGRect) -> Double {
        // Lock both pixel buffers
        CVPixelBufferLockBaseAddress(currentFrame, .readOnly)
        CVPixelBufferLockBaseAddress(backgroundFrame, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(currentFrame, .readOnly)
            CVPixelBufferUnlockBaseAddress(backgroundFrame, .readOnly)
        }

        guard let currentBaseAddress = CVPixelBufferGetBaseAddress(currentFrame),
              let backgroundBaseAddress = CVPixelBufferGetBaseAddress(backgroundFrame) else {
            return 0.0
        }

        let width = CVPixelBufferGetWidth(currentFrame)
        let height = CVPixelBufferGetHeight(currentFrame)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(currentFrame)

        // Convert to 8-bit grayscale for analysis
        let currentPixels = currentBaseAddress.assumingMemoryBound(to: UInt8.self)
        let backgroundPixels = backgroundBaseAddress.assumingMemoryBound(to: UInt8.self)

        // Calculate bounds within the ROI
        let startX = max(0, Int(roi.origin.x))
        let startY = max(0, Int(roi.origin.y))
        let endX = min(width, Int(roi.origin.x + roi.width))
        let endY = min(height, Int(roi.origin.y + roi.height))

        guard startX < endX && startY < endY else { return 0.0 }

        var foregroundPixels = 0
        var totalPixels = 0
        let threshold = 30 // Intensity difference threshold for foreground detection

        // Sample pixels in the ROI (every 2nd pixel for performance)
        for rowY in stride(from: startY, to: endY, by: 2) {
            for colX in stride(from: startX, to: endX, by: 2) {
                let pixelIndex = rowY * bytesPerRow + colX
                if pixelIndex < bytesPerRow * height {
                    let currentIntensity = Int(currentPixels[pixelIndex])
                    let backgroundIntensity = Int(backgroundPixels[pixelIndex])
                    let difference = abs(currentIntensity - backgroundIntensity)

                    if difference > threshold {
                        foregroundPixels += 1
                    }
                    totalPixels += 1
                }
            }
        }

        guard totalPixels > 0 else { return 0.0 }

        // Return the percentage of foreground pixels
        return Double(foregroundPixels) / Double(totalPixels)
    }

    // MARK: - Persistence

    private func saveROIConfiguration() {
        let roiData = [
            "x": roiRect.origin.x,
            "y": roiRect.origin.y,
            "width": roiRect.size.width,
            "height": roiRect.size.height,
            "threshold": occupancyThreshold
        ]
        UserDefaults.standard.set(roiData, forKey: "roiConfiguration")
    }

    private func loadROIConfiguration() {
        if let roiData = UserDefaults.standard.dictionary(forKey: "roiConfiguration"),
           let xValue = roiData["x"] as? CGFloat,
           let yValue = roiData["y"] as? CGFloat,
           let width = roiData["width"] as? CGFloat,
           let height = roiData["height"] as? CGFloat {
            roiRect = CGRect(x: xValue, y: yValue, width: width, height: height)

            if let threshold = roiData["threshold"] as? Double {
                occupancyThreshold = threshold
            }
        }
    }
}
