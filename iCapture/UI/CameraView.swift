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
                CameraPreviewView(previewLayer: cameraManager.previewLayer)
                    .ignoresSafeArea()
                    .onAppear {
                        print("CameraView: Camera preview appeared, previewLayer exists: \(cameraManager.previewLayer != nil)")
                        if let previewLayer = cameraManager.previewLayer {
                            print("CameraView: Preview layer session exists: \(previewLayer.session != nil)")
                        }
                    }

                FrameBoxOverlay(roiDetector: cameraManager.roiDetector)
                    .ignoresSafeArea()

                hudLayer

                if cameraManager.showCaptureFlash {
                    Color.white
                        .ignoresSafeArea()
                        .opacity(0.75)
                        .transition(.opacity)
                }

                if showPerformanceOverlay {
                    PerformanceOverlayView(performanceMonitor: cameraManager.performanceMonitor)
                        .ignoresSafeArea()
                        .transition(.move(edge: .trailing))
                }
            } else {
                unauthorizedView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: cameraManager.roiDetector.isBackgroundSampling)
        .onAppear {
            print("CameraView: View appeared, starting camera session...")
            cameraManager.startSession()
            cameraManager.sessionManager = sessionManager
            cameraManager.videoRecordingManager.configure(
                sessionManager: sessionManager,
                roiDetector: cameraManager.roiDetector
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("CameraView: Checking camera session status...")
                print("CameraView: Is authorized: \(cameraManager.isAuthorized)")
                print("CameraView: Is session running: \(cameraManager.isSessionRunning)")
                print("CameraView: Preview layer exists: \(cameraManager.previewLayer != nil)")
                if let previewLayer = cameraManager.previewLayer {
                    print("CameraView: Preview layer session exists: \(previewLayer.session != nil)")
                    print("CameraView: Preview layer frame: \(previewLayer.frame)")
                }

                cameraManager.updatePreviewLayerFrame()

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if !cameraManager.checkCameraHealth() {
                        print("CameraView: Camera health check failed, restarting session...")
                        cameraManager.restartCameraSession()
                    } else {
                        cameraManager.updatePreviewLayerFrame()
                    }
                }
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            cameraManager.updateVideoOrientation()
        }
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
                cameraManager.beginAutomaticCaptureWorkflow()
            } else {
                cameraManager.cancelAutomaticCaptureWorkflow()
                cameraManager.triggerEngine.stopSession()
            }
        }
    }

    private var hudLayer: some View {
        VStack(spacing: 0) {
            topOverlay
            Spacer()
            if cameraManager.roiDetector.isBackgroundSampling {
                backgroundSamplingBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            bottomOverlay
        }
        .ignoresSafeArea(edges: [.horizontal])
    }

    private var topOverlay: some View {
        ViewThatFits {
            topOverlayContainer {
                HStack(alignment: .top, spacing: 16) {
                    userCard
                    sessionStatusView
                        .frame(maxWidth: .infinity, alignment: .leading)
                    quickActionControls
                }
            }

            topOverlayContainer {
                VStack(alignment: .leading, spacing: 16) {
                    userCard
                    sessionStatusView
                    quickActionControls
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func topOverlayContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(.ultraThinMaterial.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var userCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Signed in as")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(authManager.currentUser ?? "User")
                .font(.callout.weight(.semibold))
                .foregroundColor(.white)
            Button("Sign Out") {
                authManager.signOut()
            }
            .font(.caption2.weight(.semibold))
            .foregroundColor(.yellow)
        }
        .padding(12)
        .background(Color.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var quickActionControls: some View {
        VStack(spacing: 12) {
            iconControl(
                systemImage: cameraManager.backgroundRemovalEnabled ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack",
                title: "Auto Sticker",
                isActive: cameraManager.backgroundRemovalEnabled,
                tint: .green
            ) {
                cameraManager.backgroundRemovalEnabled.toggle()
            }

            iconControl(
                systemImage: "chart.line.uptrend.xyaxis",
                title: "Performance",
                isActive: showPerformanceOverlay,
                tint: .orange
            ) {
                showPerformanceOverlay.toggle()
            }

            iconControl(
                systemImage: "gearshape.fill",
                title: "Setup",
                tint: .blue
            ) {
                showSetupWizard = true
            }
        }
    }

    private var sessionStatusView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if sessionManager.isSessionActive, let session = sessionManager.currentSession {
                Text("Session Active")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.green)

                infoRow(icon: "number", text: "Stock \(session.stockNumber)")
                infoRow(icon: "clock.arrow.circlepath", text: "Duration \(sessionManager.getFormattedDuration())")
                infoRow(icon: "camera.badge.ellipsis", text: "Captures \(sessionManager.getAssetCount())")

                if cameraManager.isVideoRecording {
                    infoRow(icon: "record.circle", text: "Video \(cameraManager.getFormattedVideoDuration())", color: .red)
                }
            } else {
                Text("No Active Session")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.orange)
                Text("Start a session to enable auto capture and stickers.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func infoRow(icon: String, text: String, color: Color = .white) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .foregroundColor(color)
                .font(.footnote)
        }
    }

    private var statusRow: some View {
        let chips = buildStatusChips()
        return Group {
            if chips.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(chips) { chip in
                            statusChipView(chip)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private func statusChipView(_ chip: StatusChip) -> some View {
        Label {
            Text(chip.text)
                .font(.caption)
                .foregroundColor(.white)
        } icon: {
            Image(systemName: chip.icon)
                .foregroundColor(chip.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.45))
        .clipShape(Capsule())
    }

    private func buildStatusChips() -> [StatusChip] {
        var chips: [StatusChip] = []

        if sessionManager.isSessionActive {
            chips.append(StatusChip(icon: "clock", text: sessionManager.getFormattedDuration(), color: .green))
            chips.append(StatusChip(icon: "camera.on.rectangle", text: "Photos \(sessionManager.getPhotosCount())", color: .cyan))
        }

        if cameraManager.backgroundRemovalEnabled {
            chips.append(StatusChip(icon: "sparkles", text: "Stickers On", color: .green))
        }

        if cameraManager.triggerEngine.isIntervalCaptureActive {
            let occupancy = cameraManager.roiDetector.occupancyPercentage
            let occupancyText = String(format: "ROI %.0f%%", occupancy)
            let color: Color = cameraManager.roiDetector.isROIOccupied ? .green : .orange
            chips.append(StatusChip(icon: "rectangle.inset.filled", text: occupancyText, color: color))

            if cameraManager.motionDetector.isVehicleStopped {
                chips.append(StatusChip(icon: "car.fill", text: "Vehicle Stopped", color: .red))
            } else {
                let motion = cameraManager.motionDetector.motionMagnitude
                chips.append(StatusChip(icon: "speedometer", text: String(format: "Motion %.3f", motion), color: .yellow))
            }
        }

        if cameraManager.useLiDARDetection {
            let lidarColor: Color = cameraManager.lidarDetector.isSessionRunning ? .purple : .gray
            let text = cameraManager.lidarDetector.isSessionRunning ? "LiDAR Active" : "LiDAR Ready"
            chips.append(StatusChip(icon: "sensor.tag.radiowaves.forward", text: text, color: lidarColor))
        } else {
            chips.append(StatusChip(icon: "brain.head.profile", text: "Vision Detect", color: .blue))
        }

        return chips
    }

    private var bottomOverlay: some View {
        VStack(spacing: 16) {
            statusRow

            HStack(alignment: .bottom, spacing: 20) {
                detectionControls
                Spacer()
                captureButton
                Spacer()
                sessionControls
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private var detectionControls: some View {
        HStack(spacing: 12) {
            if cameraManager.useLiDARDetection {
                iconControl(
                    systemImage: "sensor.tag.radiowaves.forward",
                    title: cameraManager.lidarDetector.isSessionRunning ? "Stop LiDAR" : "Start LiDAR",
                    isActive: cameraManager.lidarDetector.isSessionRunning,
                    tint: .purple
                ) {
                    if cameraManager.lidarDetector.isSessionRunning {
                        cameraManager.stopLiDARDetection()
                    } else {
                        cameraManager.startLiDARDetection()
                    }
                }

                iconControl(
                    systemImage: "sensor.tag.radiowaves.forward.fill",
                    title: cameraManager.useLiDARDetection ? "LiDAR On" : "LiDAR Off",
                    isActive: cameraManager.useLiDARDetection,
                    tint: .purple
                ) {
                    if cameraManager.useLiDARDetection {
                        cameraManager.disableLiDARDetection()
                    } else {
                        cameraManager.enableLiDARDetection()
                    }
                }

                iconControl(
                    systemImage: "ladybug",
                    title: "LiDAR Debug",
                    tint: .orange
                ) {
                    cameraManager.lidarDetector.debugARSessionStatus()
                }
            } else {
                iconControl(
                    systemImage: cameraManager.roiDetector.isBackgroundSampling ? "waveform" : "brain.head.profile",
                    title: cameraManager.roiDetector.isBackgroundSampling ? "Learning" : "Learn Background",
                    isActive: cameraManager.roiDetector.isBackgroundSampling,
                    tint: .orange,
                    isDisabled: cameraManager.roiDetector.isBackgroundSampling
                ) {
                    cameraManager.roiDetector.startBackgroundSampling()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var captureButton: some View {
        Button {
            print("CameraView: Manual capture triggered")
            cameraManager.capturePhoto(triggerType: .manual)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 86, height: 86)
                    Circle()
                        .fill(Color.black)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(cameraManager.isSessionRunning ? Color.white : Color.gray.opacity(0.6))
                        .frame(width: 64, height: 64)
                }
                Text("Capture")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(cameraManager.isSessionRunning ? .white : .gray)
            }
        }
        .buttonStyle(.plain)
        .disabled(!cameraManager.isSessionRunning)
    }

    private var sessionControls: some View {
        VStack(spacing: 12) {
            iconControl(
                systemImage: sessionManager.isSessionActive ? "stop.circle.fill" : "play.circle.fill",
                title: sessionManager.isSessionActive ? "End Session" : "Start Session",
                isActive: sessionManager.isSessionActive,
                tint: sessionManager.isSessionActive ? .red : .green
            ) {
                if sessionManager.isSessionActive {
                    do {
                        try sessionManager.endSession()
                        cameraManager.triggerEngine.stopSession()
                    } catch {
                        print("Failed to end session: \(error)")
                    }
                } else {
                    showStockNumberInput = true
                }
            }

            if sessionManager.isSessionActive {
                iconControl(
                    systemImage: cameraManager.isVideoRecording ? "stop.circle" : "video.circle",
                    title: cameraManager.isVideoRecording ? "Stop Video" : "Record Video",
                    isActive: cameraManager.isVideoRecording,
                    tint: cameraManager.isVideoRecording ? .red : .purple
                ) {
                    if cameraManager.isVideoRecording {
                        cameraManager.stopVideoRecording()
                    } else {
                        cameraManager.startVideoRecording()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func iconControl(
        systemImage: String,
        title: String,
        isActive: Bool = false,
        tint: Color = .blue,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 76, height: 76)
            .background((isActive ? tint : Color.black.opacity(0.55)))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }

    private var backgroundSamplingBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Learning background…")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
            ProgressView(value: cameraManager.roiDetector.backgroundSampleProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
            Text("\(Int(cameraManager.roiDetector.backgroundSampleProgress * 100))% complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: 320)
        .background(.ultraThinMaterial.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.bottom, 12)
    }

    private var unauthorizedView: some View {
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

    private struct StatusChip: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
        let color: Color
    }
}

#Preview {
    CameraView(authManager: AuthManager())
}
