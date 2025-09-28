//
//  CameraView.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @ObservedObject var authManager: AuthManager
    @State private var showSetupWizard = false

    var body: some View {
        ZStack {
            if cameraManager.isAuthorized {
                // Camera preview
                CameraPreviewView(previewLayer: cameraManager.previewLayer)
                    .ignoresSafeArea()

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
                            Text(cameraManager.triggerEngine.isIntervalCaptureActive ? "Recording" : "Ready")
                                .foregroundColor(cameraManager.triggerEngine.isIntervalCaptureActive ? .green : .white)
                                .fontWeight(.semibold)

                            if cameraManager.triggerEngine.isIntervalCaptureActive {
                                Text("Captures: \(cameraManager.triggerEngine.captureCount)")
                                    .font(.caption)
                                    .foregroundColor(.white)

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

                        // Session control button
                        Button(action: {
                            if cameraManager.triggerEngine.isIntervalCaptureActive {
                                cameraManager.triggerEngine.stopSession()
                            } else {
                                cameraManager.triggerEngine.startSession()
                            }
                        }, label: {
                            Image(systemName: cameraManager.triggerEngine.isIntervalCaptureActive ?
                                  "stop.circle.fill" : "play.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(cameraManager.triggerEngine.isIntervalCaptureActive ?
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
                }

                // Capture flash overlay
                if cameraManager.showCaptureFlash {
                    Color.white
                        .ignoresSafeArea()
                        .opacity(0.8)
                        .animation(.easeOut(duration: 0.1), value: cameraManager.showCaptureFlash)
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
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showSetupWizard) {
            FrameBoxSetupWizard(isPresented: $showSetupWizard)
        }
    }
}

#Preview {
    CameraView(authManager: AuthManager())
}
