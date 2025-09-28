//
//  LiDARDetector.swift
//  iCapture
//
//  Created by Justin Collins on 9/28/25.
//

import ARKit
import Combine
import UIKit

@MainActor
class LiDARDetector: NSObject, ObservableObject {
    @Published var isLiDARAvailable = false
    @Published private(set) var isSessionRunning = false
    @Published var isVehicleDetected = false
    @Published var vehicleDistance: Float = 0.0
    @Published var depthConfidence: Float = 0.0
    @Published var isBackgroundLearned = false
    @Published private(set) var hasCompletedInitialScan = false

    // LiDAR configuration
    private let minVehicleDistance: Float = 1.0  // 1 meter minimum
    private let maxVehicleDistance: Float = 10.0 // 10 meters maximum
    private let vehicleHeightThreshold: Float = 1.2 // 1.2 meters minimum vehicle height

    // ARKit session
    private var arSession: ARSession?
    @Published var depthData: ARDepthData?
    private(set) var latestDepthData: ARDepthData?

    private var depthFrameCount = 0
    private let framesRequiredForInitialScan = 12

    // Background depth reference
    private var backgroundDepthMap: CVPixelBuffer?
    private var backgroundDepthTimestamp: TimeInterval = 0

    // ROI configuration
    private var roiRect: CGRect = CGRect(x: 50, y: 200, width: 300, height: 200)

    // Timeout mechanism
    private var depthDataTimeoutTimer: Timer?
    private let depthDataTimeout: TimeInterval = 10.0 // 10 seconds timeout

    override init() {
        super.init()
        checkLiDARAvailability()
        setupARSession()
    }

    // MARK: - Public Interface

    func startLiDARDetection() {
        guard isLiDARAvailable else {
            print("LiDARDetector: LiDAR not available")
            return
        }

        guard let session = arSession else {
            print("LiDARDetector: ERROR - ARSession is nil!")
            return
        }

        // Check if device supports scene depth specifically
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            print("LiDARDetector: ERROR - Device does not support scene depth!")
            return
        }

        depthFrameCount = 0
        hasCompletedInitialScan = false
        latestDepthData = nil
        isBackgroundLearned = false
        backgroundDepthMap = nil
        backgroundDepthTimestamp = 0

        // Ensure ARSession is running with depth sensing
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics.insert(.sceneDepth) // Use insert instead of array

        // Add additional configuration for better depth data
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
            print("LiDARDetector: Using smoothed scene depth for better quality")
        }

        print("LiDARDetector: Starting ARSession with depth sensing...")
        print("LiDARDetector: Configuration frame semantics: \(configuration.frameSemantics)")
        let supportsSceneDepth = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        print("LiDARDetector: Scene depth supported: \(supportsSceneDepth)")

        guard !isSessionRunning else {
            print("LiDARDetector: ARSession already running")
            return
        }

        // Actually start the ARSession
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
        print("LiDARDetector: ARSession started successfully")

        // Start timeout timer
        startDepthDataTimeout()

        // Add a timer to check if we're getting frames
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.checkARSessionStatus()
        }
    }

    private func checkARSessionStatus() {
        guard arSession != nil else {
            print("LiDARDetector: ARSession status check failed - session is nil")
            return
        }

        print("LiDARDetector: ARSession status check:")
        print("LiDARDetector: - Session exists: true")
        print("LiDARDetector: - Session running: \(isSessionRunning)")
        print("LiDARDetector: - Depth data available: \(depthData != nil)")
        print("LiDARDetector: - Background learned: \(isBackgroundLearned)")
        print("LiDARDetector: - Vehicle detected: \(isVehicleDetected)")

        if let depth = depthData {
            let width = CVPixelBufferGetWidth(depth.depthMap)
            let height = CVPixelBufferGetHeight(depth.depthMap)
            print("LiDARDetector: - Depth map size: \(width)x\(height)")
        } else {
            print("LiDARDetector: - No depth data received yet")
        }
    }

    func stopLiDARDetection() {
        guard isSessionRunning else {
            print("LiDARDetector: stop requested but session not running")
            return
        }

        arSession?.pause()
        isSessionRunning = false
        depthData = latestDepthData
        stopDepthDataTimeout()
        print("LiDARDetector: Stopped LiDAR detection")
    }

    private func startDepthDataTimeout() {
        stopDepthDataTimeout() // Clear any existing timer

        depthDataTimeoutTimer = Timer.scheduledTimer(
            withTimeInterval: depthDataTimeout,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleDepthDataTimeout()
            }
        }
        print("LiDARDetector: Started depth data timeout timer (\(depthDataTimeout)s)")
    }

    private func stopDepthDataTimeout() {
        depthDataTimeoutTimer?.invalidate()
        depthDataTimeoutTimer = nil
    }

    private func handleDepthDataTimeout() async {
        print("LiDARDetector: WARNING - No depth data received within timeout period")
        print("LiDARDetector: This may indicate a device compatibility issue")
        print("LiDARDetector: Consider disabling LiDAR detection and using traditional methods")

        // Notify CameraManager to disable LiDAR detection
        NotificationCenter.default.post(name: NSNotification.Name("LiDARDetectionTimeout"), object: nil)
    }

    private func completeInitialScan(with depthData: ARDepthData) {
        guard !hasCompletedInitialScan else { return }

        hasCompletedInitialScan = true
        stopDepthDataTimeout()
        print("LiDARDetector: Initial environment scan completed after \(depthFrameCount) depth frames")

        learnBackground()

        NotificationCenter.default.post(
            name: .LiDARScanCompleted,
            object: self,
            userInfo: ["depthData": depthData]
        )
    }

    func learnBackground() {
        guard let depthData = depthData else {
            print("LiDARDetector: No depth data available for background learning")
            print("LiDARDetector: ARSession exists: \(arSession != nil)")
            print("LiDARDetector: LiDAR available: \(isLiDARAvailable)")
            return
        }

        backgroundDepthMap = depthData.depthMap
        backgroundDepthTimestamp = Date().timeIntervalSince1970
        isBackgroundLearned = true

        print("LiDARDetector: Background learned using LiDAR depth data")
        let depthWidth = CVPixelBufferGetWidth(depthData.depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthData.depthMap)
        print("LiDARDetector: Depth map size: \(depthWidth)x\(depthHeight)")
    }

    func updateROIRect(_ rect: CGRect) {
        roiRect = rect
    }

    func getROIRect() -> CGRect {
        return roiRect
    }

    func debugARSessionStatus() {
        print("LiDARDetector: === ARSession Debug Status ===")
        print("LiDARDetector: - isLiDARAvailable: \(isLiDARAvailable)")
        print("LiDARDetector: - ARSession exists: \(arSession != nil)")
        print("LiDARDetector: - ARSession delegate: \(arSession?.delegate != nil)")
        print("LiDARDetector: - Session running: \(isSessionRunning)")
        print("LiDARDetector: - Depth data available: \(depthData != nil)")
        print("LiDARDetector: - Background learned: \(isBackgroundLearned)")
        print("LiDARDetector: - Vehicle detected: \(isVehicleDetected)")

        // Check device capabilities
        let supportsSceneDepth = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        let supportsSmoothedDepth = ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth)
        print("LiDARDetector: - Scene depth supported: \(supportsSceneDepth)")
        print("LiDARDetector: - Smoothed depth supported: \(supportsSmoothedDepth)")

        if let depth = depthData {
            let width = CVPixelBufferGetWidth(depth.depthMap)
            let height = CVPixelBufferGetHeight(depth.depthMap)
            print("LiDARDetector: - Current depth map size: \(width)x\(height)")
        } else {
            print("LiDARDetector: - No depth data currently available")
        }
        print("LiDARDetector: === End Debug Status ===")
    }

    // MARK: - Private Methods

    private func checkLiDARAvailability() {
        // Check if device supports scene depth specifically (not just LiDAR)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            isLiDARAvailable = true
            print("LiDARDetector: Scene depth is available on this device")
            let supportsSmoothedDepth = ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth)
            print("LiDARDetector: Smoothed scene depth available: \(supportsSmoothedDepth)")
        } else {
            isLiDARAvailable = false
            print("LiDARDetector: Scene depth not available on this device")
            print("LiDARDetector: This device may have LiDAR but not support scene depth")
        }
    }

    private func setupARSession() {
        guard isLiDARAvailable else {
            print("LiDARDetector: Skipping ARSession setup - LiDAR not available")
            return
        }

        print("LiDARDetector: Setting up ARSession...")
        arSession = ARSession()
        arSession?.delegate = self

        print("LiDARDetector: ARSession created with delegate")
        print("LiDARDetector: ARSession delegate set: \(arSession?.delegate != nil)")

        // Don't start the ARSession immediately - wait for explicit start
        print("LiDARDetector: ARSession created but not started yet")
    }

    private func processDepthData(_ depthData: ARDepthData) {
        self.depthData = depthData
        latestDepthData = depthData
        depthFrameCount += 1

        // Reset timeout since we received depth data
        stopDepthDataTimeout()
        print("LiDARDetector: Depth data received - timeout reset")

        if !hasCompletedInitialScan && depthFrameCount >= framesRequiredForInitialScan {
            completeInitialScan(with: depthData)
        }

        // Convert depth data to vehicle detection
        let vehicleDetected = detectVehicleInDepthData(depthData)

        if vehicleDetected != isVehicleDetected {
            isVehicleDetected = vehicleDetected
            print("LiDARDetector: Vehicle detection changed: \(vehicleDetected)")
        }
    }

    private func detectVehicleInDepthData(_ depthData: ARDepthData) -> Bool {
        let depthMap = depthData.depthMap

        // Convert ROI to depth map coordinates
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)

        let roiInDepth = convertROIToDepthCoordinates(
            roiRect: roiRect,
            depthWidth: depthWidth,
            depthHeight: depthHeight
        )

        // Analyze depth data in ROI
        let vehicleInfo = analyzeDepthInROI(depthMap, roi: roiInDepth)

        // Update vehicle distance and confidence
        vehicleDistance = vehicleInfo.distance
        depthConfidence = vehicleInfo.confidence

        // Determine if vehicle is present
        return vehicleInfo.isVehiclePresent
    }

    private func convertROIToDepthCoordinates(roiRect: CGRect, depthWidth: Int, depthHeight: Int) -> CGRect {
        // Convert screen coordinates to depth map coordinates
        let screenBounds = getScreenBounds()

        return CGRect(
            x: roiRect.origin.x * CGFloat(depthWidth) / screenBounds.width,
            y: roiRect.origin.y * CGFloat(depthHeight) / screenBounds.height,
            width: roiRect.width * CGFloat(depthWidth) / screenBounds.width,
            height: roiRect.height * CGFloat(depthHeight) / screenBounds.height
        )
    }

    private func analyzeDepthInROI(_ depthMap: CVPixelBuffer, roi: CGRect) -> VehicleInfo {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return VehicleInfo(distance: 0, confidence: 0, isVehiclePresent: false)
        }

        let depthData = baseAddress.assumingMemoryBound(to: Float32.self)
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        // Calculate bounds within the ROI
        let startX = max(0, Int(roi.origin.x))
        let startY = max(0, Int(roi.origin.y))
        let endX = min(width, Int(roi.origin.x + roi.width))
        let endY = min(height, Int(roi.origin.y + roi.height))

        guard startX < endX && startY < endY else {
            return VehicleInfo(distance: 0, confidence: 0, isVehiclePresent: false)
        }

        var validDepths: [Float] = []
        var totalDepth: Float = 0
        var validPixelCount = 0

        // Sample depth data in ROI
        for rowY in startY..<endY {
            for colX in startX..<endX {
                let pixelIndex = rowY * width + colX
                let depth = depthData[pixelIndex]

                // Filter out invalid depth values
                if depth > 0 && depth < 100.0 { // Valid depth range
                    validDepths.append(depth)
                    totalDepth += depth
                    validPixelCount += 1
                }
            }
        }

        guard validPixelCount > 0 else {
            return VehicleInfo(distance: 0, confidence: 0, isVehiclePresent: false)
        }

        let averageDepth = totalDepth / Float(validPixelCount)
        let confidence = Float(validPixelCount) / Float((endX - startX) * (endY - startY))

        // Determine if vehicle is present based on depth characteristics
        let isVehiclePresent = isVehiclePresentInDepthData(validDepths, averageDepth: averageDepth)

        return VehicleInfo(
            distance: averageDepth,
            confidence: confidence,
            isVehiclePresent: isVehiclePresent
        )
    }

    private func isVehiclePresentInDepthData(_ depths: [Float], averageDepth: Float) -> Bool {
        // Check if depth is within vehicle range
        guard averageDepth >= minVehicleDistance && averageDepth <= maxVehicleDistance else {
            return false
        }

        // Check for depth variation that indicates a vehicle (not flat background)
        let depthVariance = calculateDepthVariance(depths, average: averageDepth)
        let hasSignificantVariation = depthVariance > 0.5 // Threshold for vehicle presence

        return hasSignificantVariation
    }

    private func calculateDepthVariance(_ depths: [Float], average: Float) -> Float {
        guard !depths.isEmpty else { return 0 }

        let sumSquaredDiffs = depths.reduce(0.0) { sum, depth in
            let diff = depth - average
            return sum + Double(diff * diff)
        }

        return Float(sumSquaredDiffs / Double(depths.count))
    }

    private func getScreenBounds() -> CGRect {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.screen.bounds
        } else {
            // Fallback to deprecated API if needed
            #if swift(>=5.9)
            if #available(iOS 26.0, *) {
                // Use the modern approach
                return CGRect(x: 0, y: 0, width: 400, height: 800) // Default fallback
            } else {
                return UIScreen.main.bounds
            }
            #else
            return UIScreen.main.bounds
            #endif
        }
    }
}

// MARK: - ARSessionDelegate

extension LiDARDetector: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        print("LiDARDetector: ARSession didUpdate frame - Timestamp: \(frame.timestamp)")
        print("LiDARDetector: Frame has scene depth: \(frame.sceneDepth != nil)")
        print("LiDARDetector: Frame has scene depth confidence: \(frame.sceneDepth?.confidenceMap != nil)")

        // Check if we're getting any frames at all
        print("LiDARDetector: Frame camera tracking state: \(frame.camera.trackingState)")

        // Check if we're getting frames with proper tracking
        if frame.camera.trackingState != .normal {
            print("LiDARDetector: Camera tracking state is not normal: \(frame.camera.trackingState)")
        }

        guard let depthData = frame.sceneDepth else {
            print("LiDARDetector: No scene depth data in frame")
            print("LiDARDetector: This could be due to:")
            print("LiDARDetector: - Device doesn't support scene depth")
            print("LiDARDetector: - Poor lighting conditions")
            print("LiDARDetector: - ARSession not properly configured")
            print("LiDARDetector: - Tracking issues")
            return
        }

        let width = CVPixelBufferGetWidth(depthData.depthMap)
        let height = CVPixelBufferGetHeight(depthData.depthMap)
        print("LiDARDetector: Received depth data - Size: \(width)x\(height)")

        Task { @MainActor in
            self.processDepthData(depthData)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        print("LiDARDetector: ARSession failed with error: \(error)")
        print("LiDARDetector: Error domain: \(error._domain)")
        print("LiDARDetector: Error code: \(error._code)")
    }

    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        print("LiDARDetector: Camera tracking state changed: \(camera.trackingState)")
        print("LiDARDetector: Camera tracking state: \(camera.trackingState)")
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        print("LiDARDetector: ARSession was interrupted")
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        print("LiDARDetector: ARSession interruption ended")
    }
}

// MARK: - Supporting Types

struct VehicleInfo {
    let distance: Float
    let confidence: Float
    let isVehiclePresent: Bool
}

extension Notification.Name {
    static let LiDARScanCompleted = Notification.Name("LiDARScanCompleted")
    static let BackgroundSamplingCompleted = Notification.Name("BackgroundSamplingCompleted")
}
