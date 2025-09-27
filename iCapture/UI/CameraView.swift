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
                FrameBoxOverlay()
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
                        Text("Ready")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)

                        Spacer()

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

                        // Manual capture button
                        Button(action: {
                            // Manual capture will be implemented in future milestones
                        }, label: {
                            Image(systemName: "camera.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.yellow)
                                .clipShape(Circle())
                        })
                    }
                    .padding()

                    Spacer()
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
