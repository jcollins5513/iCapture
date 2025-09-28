//
//  CameraPreviewView.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?
    
    // Helper function to get screen bounds using modern API
    private func getScreenBounds() -> CGRect {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.screen.bounds
        } else {
            // Fallback to deprecated API if needed
            return UIScreen.main.bounds
        }
    }
    
    // Custom UIView that properly handles orientation changes
    class CameraPreviewContainerView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            // Update preview layer frame whenever the view's bounds change
            if let previewLayer = previewLayer {
                previewLayer.frame = bounds
                print("CameraPreviewContainerView: Updated preview layer frame to bounds: \(bounds)")
            }
        }
    }

    func makeUIView(context: Context) -> UIView {
        let screenBounds = getScreenBounds()
        let view = CameraPreviewContainerView(frame: screenBounds)
        view.backgroundColor = .black
        print("CameraPreviewView: Creating CameraPreviewContainerView with frame: \(view.frame)")

        // Wait for preview layer to be available
        if let previewLayer = previewLayer {
            print("CameraPreviewView: Preview layer exists, adding to view")
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            
            // Store reference in container view
            view.previewLayer = previewLayer
            
            print("CameraPreviewView: Preview layer frame set to: \(previewLayer.frame)")
            print("CameraPreviewView: Preview layer session: \(previewLayer.session != nil)")
        } else {
            print("CameraPreviewView: Preview layer not ready yet - will be added in updateUIView")
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let containerView = uiView as? CameraPreviewContainerView else {
            print("CameraPreviewView: Expected CameraPreviewContainerView")
            return
        }
        
        // Ensure the view has the correct frame
        let screenBounds = getScreenBounds()
        if uiView.frame != screenBounds {
            uiView.frame = screenBounds
            print("CameraPreviewView: Updated UIView frame to: \(screenBounds)")
        }
        
        if let previewLayer = previewLayer {
            // Store reference in container view
            containerView.previewLayer = previewLayer
            
            // Ensure the preview layer is properly displayed
            if previewLayer.superlayer == nil {
                print("CameraPreviewView: Adding preview layer to view")
                uiView.layer.addSublayer(previewLayer)
            }
            
            // Set video gravity
            previewLayer.videoGravity = .resizeAspectFill
            
            print("CameraPreviewView: View bounds: \(uiView.bounds)")
            print("CameraPreviewView: Screen bounds: \(screenBounds)")
            print("CameraPreviewView: Preview layer videoGravity: \(previewLayer.videoGravity.rawValue)")
            
            // Force layout updates - this will trigger layoutSubviews in the container view
            uiView.setNeedsLayout()
            uiView.layoutIfNeeded()
            
            // Additional debug info
            print("CameraPreviewView: Preview layer superlayer: \(previewLayer.superlayer != nil)")
            print("CameraPreviewView: Preview layer isHidden: \(previewLayer.isHidden)")
            print("CameraPreviewView: Preview layer opacity: \(previewLayer.opacity)")
        } else {
            print("CameraPreviewView: Preview layer still not available in updateUIView")
        }
    }
}

#Preview {
    CameraPreviewView(previewLayer: nil)
        .ignoresSafeArea()
}
