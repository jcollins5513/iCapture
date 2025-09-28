//
//  CameraDebugger.swift
//  iCapture
//
//  Created by Justin Collins on 9/28/25.
//

import AVFoundation
import UIKit
import Combine

@MainActor
class CameraDebugger: ObservableObject {
    @Published var debugInfo: [String] = []
    @Published var isDebugMode = false
    
    private var cameraManager: CameraManager?
    private var debugTimer: Timer?
    
    // Helper function to get screen bounds using modern API
    private func getScreenBounds() -> CGRect {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.screen.bounds
        } else {
            // Fallback to deprecated API if needed
            return UIScreen.main.bounds
        }
    }
    
    func startDebugging(cameraManager: CameraManager) {
        self.cameraManager = cameraManager
        self.isDebugMode = true
        
        // Clear previous debug info
        debugInfo.removeAll()
        
        // Add initial debug info
        addDebugInfo("🔍 Camera Debugging Started")
        addDebugInfo("📱 Device: \(UIDevice.current.model)")
        addDebugInfo("📱 System: iOS \(UIDevice.current.systemVersion)")
        addDebugInfo("📱 Orientation: \(UIDevice.current.orientation.rawValue)")
        
        // Start periodic debugging
        debugTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.collectDebugInfo()
            }
        }
    }
    
    func stopDebugging() {
        isDebugMode = false
        debugTimer?.invalidate()
        debugTimer = nil
        addDebugInfo("🔍 Camera Debugging Stopped")
    }
    
    private func addDebugInfo(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let debugMessage = "[\(timestamp)] \(message)"
        debugInfo.append(debugMessage)
        
        // Keep only last 50 debug messages
        if debugInfo.count > 50 {
            debugInfo.removeFirst()
        }
        
        print("CameraDebugger: \(debugMessage)")
    }
    
    private func collectDebugInfo() {
        guard let cameraManager = cameraManager else { return }
        
        // Device orientation info
        let deviceOrientation = UIDevice.current.orientation
        let interfaceOrientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.effectiveGeometry.interfaceOrientation ?? .unknown
        
        addDebugInfo("📱 Device Orientation: \(orientationString(deviceOrientation))")
        addDebugInfo("📱 Interface Orientation: \(interfaceOrientationString(interfaceOrientation))")
        
        // Camera session info
        addDebugInfo("📹 Session Running: \(cameraManager.isSessionRunning)")
        addDebugInfo("📹 Authorized: \(cameraManager.isAuthorized)")
        
        // Preview layer info
        if let previewLayer = cameraManager.previewLayer {
            addDebugInfo("📹 Preview Layer Frame: \(previewLayer.frame)")
            addDebugInfo("📹 Preview Layer Bounds: \(previewLayer.bounds)")
            addDebugInfo("📹 Preview Layer Video Gravity: \(previewLayer.videoGravity.rawValue)")
            addDebugInfo("📹 Preview Layer Session: \(previewLayer.session != nil)")
            
            if let connection = previewLayer.connection {
                if #available(iOS 17.0, *) {
                    addDebugInfo("📹 Connection Video Rotation Angle: \(connection.videoRotationAngle)")
                    addDebugInfo("📹 Connection Is Video Rotation Angle Supported: \(String(describing: connection.isVideoRotationAngleSupported))")
                } else {
                    addDebugInfo("📹 Connection Video Orientation: \(connection.videoOrientation.rawValue)")
                    addDebugInfo("📹 Connection Is Video Orientation Supported: \(connection.isVideoOrientationSupported)")
                }
                addDebugInfo("📹 Connection Is Video Mirroring Supported: \(connection.isVideoMirroringSupported)")
            }
        } else {
            addDebugInfo("❌ Preview Layer: nil")
        }
        
        // Screen bounds info
        let screenBounds = getScreenBounds()
        addDebugInfo("📱 Screen Bounds: \(screenBounds)")
        
        // Camera device info
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            addDebugInfo("📹 Camera Device Connected: \(device.isConnected)")
            addDebugInfo("📹 Camera Device Suspended: \(device.isSuspended)")
            addDebugInfo("📹 Camera Device Position: \(device.position.rawValue)")
        }
        
        addDebugInfo("---") // Separator
    }
    
    private func orientationString(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait Upside Down"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .faceUp: return "Face Up"
        case .faceDown: return "Face Down"
        default: return "Unknown"
        }
    }
    
    private func interfaceOrientationString(_ orientation: UIInterfaceOrientation) -> String {
        switch orientation {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait Upside Down"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        default: return "Unknown"
        }
    }
    
    func testOrientationChanges() {
        addDebugInfo("🔄 Testing orientation changes...")
        
        // Force device orientation change
        let currentOrientation = UIDevice.current.orientation
        let testOrientation: UIDeviceOrientation = (currentOrientation == .portrait) ? .landscapeLeft : .portrait
        
        addDebugInfo("🔄 Current: \(orientationString(currentOrientation))")
        addDebugInfo("🔄 Testing: \(orientationString(testOrientation))")
        
        // Post orientation change notification
        NotificationCenter.default.post(name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    func analyzePreviewLayerFrame() {
        guard let previewLayer = cameraManager?.previewLayer else {
            addDebugInfo("❌ Cannot analyze - Preview layer is nil")
            return
        }
        
        let screenBounds = getScreenBounds()
        let layerFrame = previewLayer.frame
        let layerBounds = previewLayer.bounds
        
        addDebugInfo("🔍 Preview Layer Analysis:")
        addDebugInfo("🔍 Screen Bounds: \(screenBounds)")
        addDebugInfo("🔍 Layer Frame: \(layerFrame)")
        addDebugInfo("🔍 Layer Bounds: \(layerBounds)")
        
        // Check if frame matches screen bounds
        if layerFrame == screenBounds {
            addDebugInfo("✅ Frame matches screen bounds")
        } else {
            addDebugInfo("❌ Frame does NOT match screen bounds")
            let diffX = screenBounds.origin.x - layerFrame.origin.x
            let diffY = screenBounds.origin.y - layerFrame.origin.y
            let diffWidth = screenBounds.width - layerFrame.width
            let diffHeight = screenBounds.height - layerFrame.height
            addDebugInfo("❌ Difference: x=\(diffX), y=\(diffY), w=\(diffWidth), h=\(diffHeight)")
        }
        
        // Check if frame is zero
        if layerFrame.width == 0 || layerFrame.height == 0 {
            addDebugInfo("❌ WARNING: Preview layer frame has zero dimensions!")
        }
    }
    
    func exportDebugLog() -> String {
        return debugInfo.joined(separator: "\n")
    }
    
    func clearDebugLog() {
        debugInfo.removeAll()
    }
}
