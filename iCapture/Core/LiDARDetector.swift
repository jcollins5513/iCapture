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
    @Published var isVehicleDetected = false
    @Published var vehicleDistance: Float = 0.0
    @Published var depthConfidence: Float = 0.0
    @Published var isBackgroundLearned = false
    
    // LiDAR configuration
    private let minVehicleDistance: Float = 1.0  // 1 meter minimum
    private let maxVehicleDistance: Float = 10.0 // 10 meters maximum
    private let vehicleHeightThreshold: Float = 1.2 // 1.2 meters minimum vehicle height
    
    // ARKit session
    private var arSession: ARSession?
    @Published var depthData: ARDepthData?
    
    // Background depth reference
    private var backgroundDepthMap: CVPixelBuffer?
    private var backgroundDepthTimestamp: TimeInterval = 0
    
    // ROI configuration
    private var roiRect: CGRect = CGRect(x: 50, y: 200, width: 300, height: 200)
    
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
        
        arSession?.run(ARWorldTrackingConfiguration())
        print("LiDARDetector: Started LiDAR detection")
    }
    
    func stopLiDARDetection() {
        arSession?.pause()
        print("LiDARDetector: Stopped LiDAR detection")
    }
    
    func learnBackground() {
        guard let depthData = depthData else {
            print("LiDARDetector: No depth data available for background learning")
            return
        }
        
        backgroundDepthMap = depthData.depthMap
        backgroundDepthTimestamp = Date().timeIntervalSince1970
        isBackgroundLearned = true
        
        print("LiDARDetector: Background learned using LiDAR depth data")
    }
    
    func updateROIRect(_ rect: CGRect) {
        roiRect = rect
    }
    
    func getROIRect() -> CGRect {
        return roiRect
    }
    
    // MARK: - Private Methods
    
    private func checkLiDARAvailability() {
        // Check if device supports LiDAR
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            isLiDARAvailable = true
            print("LiDARDetector: LiDAR is available on this device")
        } else {
            isLiDARAvailable = false
            print("LiDARDetector: LiDAR not available on this device")
        }
    }
    
    private func setupARSession() {
        guard isLiDARAvailable else { return }
        
        arSession = ARSession()
        arSession?.delegate = self
        
        // Configure for depth sensing
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = [.sceneDepth]
        arSession?.run(configuration)
    }
    
    private func processDepthData(_ depthData: ARDepthData) {
        self.depthData = depthData
        
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
            return UIScreen.main.bounds
        }
    }
}

// MARK: - ARSessionDelegate

extension LiDARDetector: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthData = frame.sceneDepth else { return }
        
        Task { @MainActor in
            self.processDepthData(depthData)
        }
    }
    
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        print("LiDARDetector: ARSession failed with error: \(error)")
    }
}

// MARK: - Supporting Types

struct VehicleInfo {
    let distance: Float
    let confidence: Float
    let isVehiclePresent: Bool
}
