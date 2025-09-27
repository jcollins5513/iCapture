//
//  FrameBoxSetupWizard.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI

struct FrameBoxSetupWizard: View {
    @Binding var isPresented: Bool
    @StateObject private var cameraManager = CameraManager()
    @State private var currentStep = 0
    @State private var frameRect = CGRect(x: 50, y: 200, width: 300, height: 200)
    @State private var testShotTaken = false

    private let steps = [
        "Position Frame Box",
        "Test Shot",
        "Complete Setup"
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Progress indicator
                HStack {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? Color.yellow : Color.gray)
                            .frame(width: 12, height: 12)

                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(index < currentStep ? Color.yellow : Color.gray)
                                .frame(height: 2)
                        }
                    }
                }
                .padding()

                // Step content
                VStack(spacing: 20) {
                    Text(steps[currentStep])
                        .font(.title2)
                        .fontWeight(.semibold)

                    switch currentStep {
                    case 0:
                        positionFrameBoxStep
                    case 1:
                        testShotStep
                    case 2:
                        completeSetupStep
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    Button(currentStep == steps.count - 1 ? "Finish" : "Next") {
                        if currentStep == steps.count - 1 {
                            completeSetup()
                        } else {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentStep == 1 && !testShotTaken)
                }
                .padding()
            }
            .navigationTitle("Frame Box Setup")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            loadCurrentFrameRect()
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }

    private var positionFrameBoxStep: some View {
        VStack(spacing: 16) {
            Text("Position and resize the yellow frame box to capture the vehicle area.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Text("• Drag the frame box to move it")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("• Drag the corner handles to resize")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("• The frame box will be saved automatically")
                .font(.caption)
                .foregroundColor(.secondary)

            // Frame box preview (simplified version)
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 300, height: 200)

                Rectangle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 280, height: 180)

                Text("Frame Box Preview")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
            .cornerRadius(8)
        }
    }

    private var testShotStep: some View {
        VStack(spacing: 16) {
            if testShotTaken {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Test Shot Successful!")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("The frame box is properly positioned for capturing vehicles.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)

                Text("Take a Test Shot")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Position a test object in the frame box and take a test shot to verify the setup.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Button("Take Test Shot") {
                    takeTestShot()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
        }
    }

    private var completeSetupStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Setup Complete!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your frame box is configured and ready for vehicle capture sessions.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Frame box positioned")
                }
                .font(.caption)

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Test shot completed")
                }
                .font(.caption)

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Settings saved")
                }
                .font(.caption)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func loadCurrentFrameRect() {
        if let rectData = UserDefaults.standard.dictionary(forKey: "frameBoxRect"),
           let xValue = rectData["x"] as? CGFloat,
           let yValue = rectData["y"] as? CGFloat,
           let width = rectData["width"] as? CGFloat,
           let height = rectData["height"] as? CGFloat {
            frameRect = CGRect(x: xValue, y: yValue, width: width, height: height)
        }
    }

    private func takeTestShot() {
        cameraManager.captureTestShot()

        // Watch for test shot completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if cameraManager.testShotCaptured {
                withAnimation {
                    testShotTaken = true
                }
            } else {
                // Try again after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if cameraManager.testShotCaptured {
                        withAnimation {
                            testShotTaken = true
                        }
                    }
                }
            }
        }
    }

    private func completeSetup() {
        // Mark setup as completed
        UserDefaults.standard.set(true, forKey: "frameBoxSetupCompleted")
        isPresented = false
    }
}

#Preview {
    FrameBoxSetupWizard(isPresented: .constant(true))
}
