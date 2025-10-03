//
//  MotionDetector.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import AVFoundation
import Vision
import Combine
import UIKit

@MainActor
class MotionDetector: ObservableObject {
    @Published var motionMagnitude: Double = 0.0
    @Published var isVehicleStopped = false
    @Published var motionHistory: [Double] = []

    // Motion detection parameters
    private let motionThreshold: Double = 0.1 // ε threshold for stop detection
    private let stopDetectionDuration: TimeInterval = 0.7 // 0.7 seconds of low motion
    private let historyWindowSize = 15 // 15 frames at 30fps

    // Frame history for optical flow calculation
    private var previousFrame: CVPixelBuffer?
    private var motionHistoryBuffer: [Double] = []
    private var stopDetectionStartTime: Date?

    // ROI configuration
    private var roiRect: CGRect = CGRect(x: 50, y: 200, width: 300, height: 200)

    // Processing queue
    private let processingQueue = DispatchQueue(label: "motion.detection.queue", qos: .userInitiated)

    init() {
        loadMotionConfiguration()
    }

    // MARK: - Public Interface

    func updateROIRect(_ rect: CGRect) {
        roiRect = rect
        saveMotionConfiguration()
        resetMotionDetection()
    }

    func getROIRect() -> CGRect {
        roiRect
    }

    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        // Get local copies of needed properties
        let localPreviousFrame = previousFrame
        let localROIRect = roiRect

        if let previousFrame = localPreviousFrame {
            processingQueue.async { [weak self] in
                guard let self = self else { return }

                // Calculate motion on background queue
                let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
                let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
                let roiInBuffer = self.convertROIToBufferCoordinates(
                    roiRect: localROIRect,
                    bufferWidth: bufferWidth,
                    bufferHeight: bufferHeight
                )

                let motionMag = self.calculateMotionMagnitudeInROI(
                    currentFrame: pixelBuffer,
                    previousFrame: previousFrame,
                    roi: roiInBuffer
                )

                // Update on main actor
                Task { @MainActor in
                    self.updateMotionHistory(motionMag)
                    self.checkStopCondition()
                    self.motionMagnitude = motionMag
                    self.motionHistory = Array(self.motionHistoryBuffer)
                }
            }
        }

        // Store current frame for next calculation
        previousFrame = pixelBuffer
    }

    func resetMotionDetection() {
        previousFrame = nil
        motionHistoryBuffer.removeAll()
        motionHistory.removeAll()
        isVehicleStopped = false
        stopDetectionStartTime = nil
        motionMagnitude = 0.0
    }

    func setMotionThreshold(_ threshold: Double) {
        // Clamp threshold between 0.01 and 1.0
        _ = max(0.01, min(1.0, threshold))
        // Note: This would require updating the stored configuration
        // For now, we'll keep it constant as per the specification
    }

    func getMotionThreshold() -> Double {
        motionThreshold
    }

    // MARK: - Private Methods

    private func convertROIToBufferCoordinates(roiRect: CGRect, bufferWidth: Int, bufferHeight: Int) -> CGRect {
        CGRect(
            x: roiRect.origin.x * CGFloat(bufferWidth) / 400, // Assuming 400pt screen width
            y: roiRect.origin.y * CGFloat(bufferHeight) / 800, // Assuming 800pt screen height
            width: roiRect.width * CGFloat(bufferWidth) / 400,
            height: roiRect.height * CGFloat(bufferHeight) / 800
        )
    }

    private func calculateMotionMagnitudeInROI(
        currentFrame: CVPixelBuffer,
        previousFrame: CVPixelBuffer,
        roi: CGRect
    ) -> Double {
        // Lock both pixel buffers
        CVPixelBufferLockBaseAddress(currentFrame, .readOnly)
        CVPixelBufferLockBaseAddress(previousFrame, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(currentFrame, .readOnly)
            CVPixelBufferUnlockBaseAddress(previousFrame, .readOnly)
        }

        guard let currentBaseAddress = CVPixelBufferGetBaseAddress(currentFrame),
              let previousBaseAddress = CVPixelBufferGetBaseAddress(previousFrame) else {
            return 0.0
        }

        let width = CVPixelBufferGetWidth(currentFrame)
        let height = CVPixelBufferGetHeight(currentFrame)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(currentFrame)

        // Convert to 8-bit grayscale for analysis
        let currentPixels = currentBaseAddress.assumingMemoryBound(to: UInt8.self)
        let previousPixels = previousBaseAddress.assumingMemoryBound(to: UInt8.self)

        // Calculate bounds within the ROI
        let startX = max(0, Int(roi.origin.x))
        let startY = max(0, Int(roi.origin.y))
        let endX = min(width, Int(roi.origin.x + roi.width))
        let endY = min(height, Int(roi.origin.y + roi.height))

        guard startX < endX && startY < endY else { return 0.0 }

        var totalMotion: Double = 0
        var pixelCount = 0

        // Sample pixels in the ROI (every 4th pixel for performance)
        for rowY in stride(from: startY, to: endY, by: 4) {
            for colX in stride(from: startX, to: endX, by: 4) {
                let pixelIndex = rowY * bytesPerRow + colX
                if pixelIndex < bytesPerRow * height {
                    let currentIntensity = Double(currentPixels[pixelIndex])
                    let previousIntensity = Double(previousPixels[pixelIndex])

                    // Calculate pixel-level motion (intensity difference)
                    let pixelMotion = abs(currentIntensity - previousIntensity)
                    totalMotion += pixelMotion
                    pixelCount += 1
                }
            }
        }

        guard pixelCount > 0 else { return 0.0 }

        // Calculate average motion magnitude
        let averageMotion = totalMotion / Double(pixelCount)

        // Normalize motion magnitude (0.0 to 1.0)
        let normalizedMotion = min(averageMotion / 255.0, 1.0)

        return normalizedMotion
    }

    private func updateMotionHistory(_ motionMag: Double) {
        motionHistoryBuffer.append(motionMag)

        // Keep only the last 15 frames
        if motionHistoryBuffer.count > historyWindowSize {
            motionHistoryBuffer.removeFirst()
        }
    }

    private func checkStopCondition() {
        guard motionHistoryBuffer.count >= historyWindowSize else { return }

        // Calculate median motion over the sliding window
        let sortedMotion = motionHistoryBuffer.sorted()
        let medianMotion = sortedMotion[sortedMotion.count / 2]

        // Check if motion is below threshold
        if medianMotion < motionThreshold {
            if stopDetectionStartTime == nil {
                stopDetectionStartTime = Date()
            } else {
                // Check if we've been below threshold for the required duration
                let timeBelowThreshold = Date().timeIntervalSince(stopDetectionStartTime!)
                if timeBelowThreshold >= stopDetectionDuration {
                    Task { @MainActor in
                        self.isVehicleStopped = true
                    }
                }
            }
        } else {
            // Motion is above threshold, reset stop detection
            stopDetectionStartTime = nil
            Task { @MainActor in
                self.isVehicleStopped = false
            }
        }
    }

    // MARK: - Persistence

    private func saveMotionConfiguration() {
        let motionData = [
            "x": roiRect.origin.x,
            "y": roiRect.origin.y,
            "width": roiRect.size.width,
            "height": roiRect.size.height,
            "threshold": motionThreshold
        ]
        UserDefaults.standard.set(motionData, forKey: "motionConfiguration")
    }

    private func loadMotionConfiguration() {
        if let motionData = UserDefaults.standard.dictionary(forKey: "motionConfiguration"),
           let xValue = motionData["x"] as? CGFloat,
           let yValue = motionData["y"] as? CGFloat,
           let width = motionData["width"] as? CGFloat,
           let height = motionData["height"] as? CGFloat {
            roiRect = CGRect(x: xValue, y: yValue, width: width, height: height)
        }
    }
}
