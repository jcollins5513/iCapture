//
//  CameraView.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var sessionManager = SessionManager()
    @ObservedObject var authManager: AuthManager
    @State private var showSetupWizard = false
    @State private var showStockNumberInput = false
    @State private var showPerformanceOverlay = false

    var body: some View {
        ZStack {
            if cameraManager.isAuthorized {
                // Camera preview
                CameraPreviewView(previewLayer: cameraManager.previewLayer)
                    .ignoresSafeArea()
                    .onAppear {
                        print("CameraView: Camera preview appeared, previewLayer exists: \(cameraManager.previewLayer != nil)")
                        if let previewLayer = cameraManager.previewLayer {
                            print("CameraView: Preview layer session exists: \(previewLayer.session != nil)")
                        }
                    }

                // Frame box overlay
                FrameBoxOverlay(roiDetector: cameraManager.roiDetector)
                    .ignoresSafeArea()

                // Capture HUD
                VStack {
                    HStack {
                        // User info and sign out
                        VStack(alignment: .leading) {
                            Text("Welcome, \(authManager.currentUser ?? "User")")
                                .font(.caption)
                                .foregroundColor(.white)

                            Button(action: {
                                authManager.signOut()
                            }, label: {
                                Text("Sign Out")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            })
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)

                        Spacer()

                        // Session status
                        VStack(alignment: .leading, spacing: 4) {
                            if sessionManager.isSessionActive {
                                Text("Session Active")
                                    .foregroundColor(.green)
                                    .fontWeight(.semibold)

                                if let session = sessionManager.currentSession {
                                    Text("Stock: \(session.stockNumber)")
                                        .font(.caption)
                                        .foregroundColor(.white)

                                    Text("Duration: \(sessionManager.getFormattedDuration())")
                                        .font(.caption)
                                        .foregroundColor(.white)

                                    Text("Captures: \(sessionManager.getAssetCount())")
                                        .font(.caption)
                                        .foregroundColor(.white)

                                    // Video recording status
                                    if cameraManager.isVideoRecording {
                                        Text("Video: Recording (\(cameraManager.getFormattedVideoDuration()))")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .fontWeight(.semibold)
                                    } else {
                                        Text("Video: Ready")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }
                                }
                            } else {
                                Text("No Session")
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }

                            if cameraManager.triggerEngine.isIntervalCaptureActive {
                                if cameraManager.roiDetector.isROIOccupied {
                                    let occupancy = cameraManager.roiDetector.occupancyPercentage
                                    let occupancyText = String(format: "%.1f", occupancy)
                                    Text("ROI: Occupied (\(occupancyText)%)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text("ROI: Clear")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }

                                // Motion detection status
                                if cameraManager.motionDetector.isVehicleStopped {
                                    Text("Vehicle: STOPPED")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .fontWeight(.bold)
                                } else {
                                    let motion = cameraManager.motionDetector.motionMagnitude
                                    let motionText = String(format: "%.3f", motion)
                                    Text("Motion: \(motionText)")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                }
                                
                                // Photo capture info
                                let photoInfo = cameraManager.getPhotoCaptureInfo()
                                let resolutionText = photoInfo.is48MPSupported ? "48MP" : "12MP"
                                Text("Photo: \(resolutionText) \(photoInfo.format)")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)

                        Spacer()

                        // Background sampling button
                        Button(action: {
                            cameraManager.roiDetector.startBackgroundSampling()
                        }, label: {
                            Image(systemName: cameraManager.roiDetector.isBackgroundSampling ?
                                  "waveform" : "brain.head.profile")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(cameraManager.roiDetector.isBackgroundSampling ?
                                           Color.orange : Color.blue)
                                .clipShape(Circle())
                        })
                        .disabled(cameraManager.roiDetector.isBackgroundSampling)

                        // Setup button
                        Button(action: {
                            showSetupWizard = true
                        }, label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .clipShape(Circle())
                        })

                        // Video recording toggle button
                        if sessionManager.isSessionActive {
                            Button(action: {
                                if cameraManager.isVideoRecording {
                                    cameraManager.stopVideoRecording()
                                } else {
                                    cameraManager.startVideoRecording()
                                }
                            }, label: {
                                Image(systemName: cameraManager.isVideoRecording ?
                                      "stop.circle.fill" : "video.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(cameraManager.isVideoRecording ?
                                               Color.red : Color.purple)
                                    .clipShape(Circle())
                            })
                        }

                        // Performance overlay toggle
                        Button(action: {
                            showPerformanceOverlay.toggle()
                        }, label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(showPerformanceOverlay ? Color.orange : Color.blue)
                                .clipShape(Circle())
                        })

                        // Session control button
                        Button(action: {
                            if sessionManager.isSessionActive {
                                // End session
                                do {
                                    try sessionManager.endSession()
                                    cameraManager.triggerEngine.stopSession()
                                } catch {
                                    print("Failed to end session: \(error)")
                                }
                            } else {
                                // Start new session
                                showStockNumberInput = true
                            }
                        }, label: {
                            Image(systemName: sessionManager.isSessionActive ?
                                  "stop.circle.fill" : "play.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(sessionManager.isSessionActive ?
                                           Color.red : Color.green)
                                .clipShape(Circle())
                        })
                    }
                    .padding()

                    // Background sampling progress
                    if cameraManager.roiDetector.isBackgroundSampling {
                        VStack(spacing: 8) {
                            Text("Learning Background...")
                                .foregroundColor(.white)
                                .font(.headline)

                            ProgressView(value: cameraManager.roiDetector.backgroundSampleProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                                .frame(width: 200)

                            Text("\(Int(cameraManager.roiDetector.backgroundSampleProgress * 100))%")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .padding(.bottom, 100)
                    }

                    Spacer()
                    
                    // Manual capture button
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            print("CameraView: Manual capture triggered")
                            cameraManager.capturePhoto(triggerType: .manual)
                        }, label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 70, height: 70)
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                            }
                        })
                        .disabled(!cameraManager.isSessionRunning)
                        
                        Spacer()
                    }
                    .padding(.bottom, 50)
                }

                // Capture flash overlay
                if cameraManager.showCaptureFlash {
                    Color.white
                        .ignoresSafeArea()
                        .opacity(0.8)
                        .animation(.easeOut(duration: 0.1), value: cameraManager.showCaptureFlash)
                }

                // Performance overlay
                if showPerformanceOverlay {
                    PerformanceOverlayView(performanceMonitor: cameraManager.performanceMonitor)
                        .ignoresSafeArea()
                }
            } else {
                // Camera not authorized
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("Camera Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("iCapture needs camera access to capture vehicle photos during rotation sessions.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    Button("Grant Camera Access") {
                        cameraManager.checkAuthorization()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .onAppear {
            print("CameraView: View appeared, starting camera session...")
            cameraManager.startSession()
            // Connect session manager to camera manager
            cameraManager.sessionManager = sessionManager
            // Connect session manager to video recording manager
            cameraManager.videoRecordingManager.configure(
                sessionManager: sessionManager,
                roiDetector: cameraManager.roiDetector
            )
            
            // Ensure camera session is properly set up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("CameraView: Checking camera session status...")
                print("CameraView: Is authorized: \(cameraManager.isAuthorized)")
                print("CameraView: Is session running: \(cameraManager.isSessionRunning)")
                print("CameraView: Preview layer exists: \(cameraManager.previewLayer != nil)")
                if let previewLayer = cameraManager.previewLayer {
                    print("CameraView: Preview layer session exists: \(previewLayer.session != nil)")
                    print("CameraView: Preview layer frame: \(previewLayer.frame)")
                }
                
                // Force preview layer frame update
                cameraManager.updatePreviewLayerFrame()
                
                // Check camera health and restart if needed
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if !cameraManager.checkCameraHealth() {
                        print("CameraView: Camera health check failed, restarting session...")
                        cameraManager.restartCameraSession()
                    } else {
                        // Force another frame update after health check
                        cameraManager.updatePreviewLayerFrame()
                    }
                }
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // Update video orientation when device rotates
            // Preview layer frame is handled by CameraPreviewView
            cameraManager.updateVideoOrientation()
        }
        
        // Debug overlay (only show in debug builds or when enabled)
        .overlay(alignment: .topLeading) {
            if cameraManager.cameraDebugger.isDebugMode {
                CameraDebugView(cameraDebugger: cameraManager.cameraDebugger)
                    .padding(.top, 50)
                    .padding(.leading, 16)
            }
        }
        .sheet(isPresented: $showSetupWizard) {
            FrameBoxSetupWizard(isPresented: $showSetupWizard)
        }
        .sheet(isPresented: $showStockNumberInput) {
            StockNumberInputView(sessionManager: sessionManager, isPresented: $showStockNumberInput)
        }
        .onChange(of: sessionManager.isSessionActive) { _, isActive in
            if isActive {
                // Start trigger engine when session becomes active
                cameraManager.triggerEngine.startSession()
            } else {
                // Stop trigger engine when session ends
                cameraManager.triggerEngine.stopSession()
            }
        }
    }
}

#Preview {
    CameraView(authManager: AuthManager())
}
