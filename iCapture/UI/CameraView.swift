//
//  CameraView.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var sessionManager = SessionManager()
    @ObservedObject var authManager: AuthManager
    @State private var showSetupWizard = false
    @State private var showStockNumberInput = false
    @State private var showPerformanceOverlay = false
    @State private var isAdjustingROI = false

    private var screenSize: CGSize {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.screen.bounds.size
        }
        return UIScreen.main.bounds.size
    }

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    private var layoutScale: CGFloat {
        let shortestSide = min(screenSize.width, screenSize.height)
        let compactThreshold = CGFloat(350)
        let smallThreshold = CGFloat(380)
        let mediumThreshold = CGFloat(414)

        if shortestSide < compactThreshold { return CGFloat(0.82) }
        if shortestSide < smallThreshold { return CGFloat(0.88) }
        if shortestSide < mediumThreshold { return CGFloat(0.94) }
        return CGFloat(1.0)
    }

    private var controlButtonDimension: CGFloat {
        let base: CGFloat = isCompactHeight ? 64 : 76
        return max(CGFloat(52), base * layoutScale)
    }

    private var controlIconFont: Font {
        let base: CGFloat = isCompactHeight ? 20 : 22
        return .system(size: max(CGFloat(16), base * layoutScale), weight: .semibold)
    }

    private var controlLabelFont: Font {
        let base: CGFloat = isCompactHeight ? 11 : 12
        return .system(size: max(CGFloat(9), base * layoutScale), weight: .semibold)
    }

    var body: some View {
        ZStack {
            if cameraManager.isAuthorized {
                CameraPreviewView(previewLayer: cameraManager.previewLayer)
                    .ignoresSafeArea()
                    .onAppear {
                        let hasPreviewLayer = cameraManager.previewLayer != nil
                        print("CameraView: Preview appeared; layer ready: \(hasPreviewLayer)")
                        if let previewLayer = cameraManager.previewLayer {
                            let hasSession = previewLayer.session != nil
                            print("CameraView: Preview layer session exists: \(hasSession)")
                        }
                    }

                FrameBoxOverlay(
                    roiDetector: cameraManager.roiDetector,
                    isEditing: $isAdjustingROI
                )
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
                cameraManager.backgroundRemovalEnabled = true
                cameraManager.beginAutomaticCaptureWorkflow()
            } else {
                cameraManager.backgroundRemovalEnabled = false
                cameraManager.cancelAutomaticCaptureWorkflow()
                cameraManager.triggerEngine.stopSession()
                isAdjustingROI = false
            }
        }
        .onChange(of: cameraManager.roiDetector.isBackgroundSampling) { _, isSampling in
            if !isSampling {
                isAdjustingROI = false
            }
        }
    }

    private var hudLayer: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                topOverlay
                    .padding(.horizontal, horizontalEdgePadding(for: geometry.size.width))
                    .padding(
                        .top,
                        geometry.safeAreaInsets.top + topOverlayPadding(for: geometry.size.height)
                    )

                Spacer(minLength: 0)

                if cameraManager.roiDetector.isBackgroundSampling {
                    backgroundSamplingBanner
                        .padding(.horizontal, horizontalEdgePadding(for: geometry.size.width))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                bottomOverlay
                    .padding(.horizontal, horizontalEdgePadding(for: geometry.size.width))
                    .padding(
                        .bottom,
                        geometry.safeAreaInsets.bottom + bottomOverlayPadding(for: geometry.size.height)
                    )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
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
    }

    private func horizontalEdgePadding(for width: CGFloat) -> CGFloat {
        if width < 360 { return 12 }
        if width < 390 { return 14 }
        return 16
    }

    private func topOverlayPadding(for height: CGFloat) -> CGFloat {
        if height < 700 { return 6 }
        if height < 780 { return 10 }
        return 14
    }

    private func bottomOverlayPadding(for height: CGFloat) -> CGFloat {
        if height < 700 { return 12 }
        if height < 780 { return 18 }
        return 24
    }

    private func topOverlayContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(isCompactHeight ? 12 : 16)
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
        ViewThatFits {
            HStack(spacing: 12) {
                autoStickerControl()
                adjustFrameControl()
                performanceControl()
                setupControl()
            }

            LazyVGrid(columns: quickActionColumns, spacing: 12) {
                autoStickerControl()
                adjustFrameControl()
                performanceControl()
                setupControl()
            }

            VStack(spacing: 12) {
                autoStickerControl()
                adjustFrameControl()
                performanceControl()
                setupControl()
            }
        }
    }

    private var quickActionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var sessionStatusView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if sessionManager.isSessionActive, let session = sessionManager.currentSession {
                Text("Session Active")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.green)

                infoRow(
                    icon: "number",
                    text: "Stock \(session.stockNumber)"
                )
                infoRow(
                    icon: "clock.arrow.circlepath",
                    text: "Duration \(sessionManager.getFormattedDuration())"
                )
                infoRow(
                    icon: "camera.badge.ellipsis",
                    text: "Captures \(sessionManager.getAssetCount())"
                )

                if cameraManager.isVideoRecording {
                    infoRow(
                        icon: "record.circle",
                        text: "Video \(cameraManager.getFormattedVideoDuration())",
                        color: .red
                    )
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

        chips.append(contentsOf: buildSessionChips())
        chips.append(contentsOf: buildBackgroundRemovalChips())
        chips.append(contentsOf: buildTriggerEngineChips())
        chips.append(contentsOf: buildLiDARChips())

        return chips
    }

    private func buildSessionChips() -> [StatusChip] {
        guard sessionManager.isSessionActive else { return [] }

        return [
            StatusChip(
                icon: "clock",
                text: sessionManager.getFormattedDuration(),
                color: .green
            ),
            StatusChip(
                icon: "camera.on.rectangle",
                text: "Photos \(sessionManager.getPhotosCount())",
                color: .cyan
            )
        ]
    }

    private func buildBackgroundRemovalChips() -> [StatusChip] {
        guard cameraManager.backgroundRemovalEnabled else { return [] }

        return [
            StatusChip(
                icon: "sparkles",
                text: "Stickers On",
                color: .green
            )
        ]
    }

    private func buildTriggerEngineChips() -> [StatusChip] {
        guard cameraManager.triggerEngine.isIntervalCaptureActive else { return [] }

        var chips: [StatusChip] = []

        let occupancy = cameraManager.roiDetector.occupancyPercentage
        let occupancyText = String(format: "ROI %.0f%%", occupancy)
        let color: Color = cameraManager.roiDetector.isROIOccupied ? .green : .orange
        chips.append(
            StatusChip(
                icon: "rectangle.inset.filled",
                text: occupancyText,
                color: color
            )
        )

        if cameraManager.motionDetector.isVehicleStopped {
            chips.append(
                StatusChip(
                    icon: "car.fill",
                    text: "Vehicle Stopped",
                    color: .red
                )
            )
        } else {
            let motion = cameraManager.motionDetector.motionMagnitude
            let motionText = String(format: "Motion %.3f", motion)
            chips.append(
                StatusChip(
                    icon: "speedometer",
                    text: motionText,
                    color: .yellow
                )
            )
        }

        return chips
    }

    private func buildLiDARChips() -> [StatusChip] {
        let chip: StatusChip

        switch cameraManager.lidarBoostState {
        case .unavailable, .idle:
            chip = StatusChip(
                icon: "brain.head.profile",
                text: "Vision Detect",
                color: .blue
            )
        case .scanning:
            chip = StatusChip(
                icon: "sensor.tag.radiowaves.forward",
                text: "Depth Scanning",
                color: .purple
            )
        case .ready:
            chip = StatusChip(
                icon: "sensor.tag.radiowaves.forward.fill",
                text: "Depth Ready",
                color: .purple
            )
        }

        return [chip]
    }

    private var bottomOverlay: some View {
        Group {
            if isCompactHeight {
                compactBottomOverlay
            } else {
                regularBottomOverlay
            }
        }
    }

    private var regularBottomOverlay: some View {
        VStack(spacing: max(CGFloat(12), 16 * layoutScale)) {
            statusRow

            HStack(alignment: .bottom, spacing: max(CGFloat(14), 20 * layoutScale)) {
                detectionControls(compact: false)
                Spacer()
                captureButton(compact: false)
                Spacer()
                sessionControls(compact: false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, max(CGFloat(14), 18 * layoutScale))
        .background(.ultraThinMaterial.opacity(0.9))
        .clipShape(
            RoundedRectangle(
                cornerRadius: max(CGFloat(18), 24 * layoutScale),
                style: .continuous
            )
        )
    }

    private var compactBottomOverlay: some View {
        VStack(spacing: max(CGFloat(10), 12 * layoutScale)) {
            statusRow

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: max(CGFloat(10), 12 * layoutScale)) {
                    detectionControls(compact: true)
                    captureButton(compact: true)
                    sessionControls(compact: true)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, max(CGFloat(12), 14 * layoutScale))
        .background(.ultraThinMaterial.opacity(0.94))
        .clipShape(
            RoundedRectangle(
                cornerRadius: max(CGFloat(16), 22 * layoutScale),
                style: .continuous
            )
        )
    }

    @ViewBuilder
    private func detectionControls(compact: Bool) -> some View {
        let spacingBase = CGFloat(compact ? 10 : 12)
        let spacing: CGFloat = max(CGFloat(8), spacingBase * layoutScale)

        HStack(spacing: spacing) {
            let isSampling = cameraManager.roiDetector.isBackgroundSampling
            iconControl(
                systemImage: isSampling ? "waveform" : "brain.head.profile",
                title: isSampling ? "Learning" : "Learn Background",
                isActive: isSampling,
                tint: .orange,
                isDisabled: isSampling
            ) {
                cameraManager.roiDetector.startBackgroundSampling()
            }

            if cameraManager.lidarBoostState != .unavailable {
                switch cameraManager.lidarBoostState {
                case .idle:
                    iconControl(
                        systemImage: "sensor.tag.radiowaves.forward",
                        title: "Depth Boost",
                        tint: .purple
                    ) {
                        cameraManager.startLiDARDetection()
                    }
                case .scanning:
                    iconControl(
                        systemImage: "sensor.tag.radiowaves.forward",
                        title: "Cancel Scan",
                        isActive: true,
                        tint: .purple
                    ) {
                        cameraManager.stopLiDARDetection()
                    }
                case .ready:
                    iconControl(
                        systemImage: "sensor.tag.radiowaves.forward.fill",
                        title: "Depth Ready",
                        isActive: true,
                        tint: .purple
                    ) {
                        cameraManager.startLiDARDetection()
                    }

                    iconControl(
                        systemImage: "xmark.circle",
                        title: "Clear Depth",
                        tint: .purple
                    ) {
                        cameraManager.disableLiDARDetection()
                    }
                case .unavailable:
                    EmptyView()
                }

                iconControl(
                    systemImage: "ladybug",
                    title: "LiDAR Debug",
                    tint: .orange
                ) {
                    cameraManager.lidarDetector.debugARSessionStatus()
                }
            }
        }
        .frame(maxWidth: compact ? nil : .infinity, alignment: .leading)
    }

    private func captureButton(compact: Bool) -> some View {
        Button {
            print("CameraView: Manual capture triggered")
            cameraManager.capturePhoto(triggerType: .manual)
        } label: {
            let labelSpacing = CGFloat(compact ? 6 : 8)
            VStack(spacing: labelSpacing) {
                let scale = layoutScale
                let outerBase = CGFloat(compact ? 72 : 86)
                let middleBase = CGFloat(compact ? 60 : 72)
                let innerBase = CGFloat(compact ? 52 : 64)
                let outer: CGFloat = max(CGFloat(60), outerBase * scale)
                let middle: CGFloat = max(CGFloat(48), middleBase * scale)
                let inner: CGFloat = max(CGFloat(42), innerBase * scale)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: outer, height: outer)
                    Circle()
                        .fill(Color.black)
                        .frame(width: middle, height: middle)
                    Circle()
                        .fill(cameraManager.isSessionRunning ? Color.white : Color.gray.opacity(0.6))
                        .frame(width: inner, height: inner)
                }
                Text("Capture")
                    .font(controlLabelFont)
                    .foregroundColor(cameraManager.isSessionRunning ? .white : .gray)
            }
        }
        .buttonStyle(.plain)
        .disabled(!cameraManager.isSessionRunning)
    }

    @ViewBuilder
    private func sessionControls(compact: Bool) -> some View {
        let stackBase = CGFloat(compact ? 10 : 12)
        VStack(spacing: max(CGFloat(9), stackBase * layoutScale)) {
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
        .frame(maxWidth: compact ? nil : .infinity, alignment: compact ? .leading : .trailing)
    }

    @ViewBuilder
    private func autoStickerControl() -> some View {
        iconControl(
            systemImage: cameraManager.backgroundRemovalEnabled ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack",
            title: "Auto Sticker",
            isActive: cameraManager.backgroundRemovalEnabled,
            tint: .green
        ) {
            cameraManager.backgroundRemovalEnabled.toggle()
        }
    }

    @ViewBuilder
    private func adjustFrameControl() -> some View {
        iconControl(
            systemImage: isAdjustingROI ? "rectangle.dashed.badge.record" : "rectangle.dashed",
            title: isAdjustingROI ? "Lock Frame" : "Adjust Frame",
            isActive: isAdjustingROI,
            tint: .cyan
        ) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                isAdjustingROI.toggle()
            }
        }
    }

    @ViewBuilder
    private func performanceControl() -> some View {
        iconControl(
            systemImage: "chart.line.uptrend.xyaxis",
            title: "Performance",
            isActive: showPerformanceOverlay,
            tint: .orange
        ) {
            showPerformanceOverlay.toggle()
        }
    }

    @ViewBuilder
    private func setupControl() -> some View {
        iconControl(
            systemImage: "gearshape.fill",
            title: "Setup",
            tint: .blue
        ) {
            showSetupWizard = true
        }
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
            let spacingBase: CGFloat = isCompactHeight ? 4 : 6
            VStack(spacing: max(CGFloat(3), spacingBase * layoutScale)) {
                Image(systemName: systemImage)
                    .font(controlIconFont)
                    .foregroundColor(.white)
                Text(title)
                    .font(controlLabelFont)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: controlButtonDimension, height: controlButtonDimension)
            .background((isActive ? tint : Color.black.opacity(0.55)))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: max(CGFloat(14), 18 * layoutScale),
                    style: .continuous
                )
            )
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
