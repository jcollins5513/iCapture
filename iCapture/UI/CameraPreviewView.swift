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

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        print("CameraPreviewView: Creating UIView with frame: \(view.frame)")

        if let previewLayer = previewLayer {
            print("CameraPreviewView: Preview layer exists, adding to view")
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            
            // Don't set any orientation - let it work like native camera
            
            view.layer.addSublayer(previewLayer)
            print("CameraPreviewView: Preview layer frame set to: \(previewLayer.frame)")
            print("CameraPreviewView: Preview layer session: \(previewLayer.session != nil)")
        } else {
            print("CameraPreviewView: WARNING - Preview layer is nil!")
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Ensure the view has the correct frame
        let screenBounds = UIScreen.main.bounds
        if uiView.frame != screenBounds {
            uiView.frame = screenBounds
            print("CameraPreviewView: Updated UIView frame to: \(screenBounds)")
        }
        
        if let previewLayer = previewLayer {
            let newFrame = uiView.bounds
            print("CameraPreviewView: Updating frame to: \(newFrame)")
            previewLayer.frame = newFrame
            previewLayer.videoGravity = .resizeAspectFill
            print("CameraPreviewView: Preview layer frame updated to: \(previewLayer.frame)")
            
            // Don't mess with orientation - let AVFoundation handle it naturally like native camera
            
            // Ensure the preview layer is properly displayed
            if previewLayer.superlayer == nil {
                print("CameraPreviewView: Adding preview layer to view")
                uiView.layer.addSublayer(previewLayer)
            }
            
            // Force layout update
            uiView.setNeedsLayout()
            uiView.layoutIfNeeded()
        }
    }
}

#Preview {
    CameraPreviewView(previewLayer: nil)
        .ignoresSafeArea()
}
