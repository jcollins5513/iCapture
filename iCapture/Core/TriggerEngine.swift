//
//  TriggerEngine.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import Combine
import Foundation
import SwiftUI

@MainActor
class TriggerEngine: ObservableObject {
    @Published var isIntervalCaptureActive = false
    @Published var isStopCaptureActive = false
    @Published var lastCaptureTime: Date?
    @Published var captureCount = 0
    @Published var sessionStartTime: Date?

    // Configuration
    private let intervalDuration: TimeInterval = 5.0 // 5 seconds
    private let maxCapturesPerSession = 60
    private let debounceDuration: TimeInterval = 1.2 // 1.2 seconds between shots

    // Timers and state
    private var intervalTimer: Timer?
    private var lastDebounceTime: Date?

    // Dependencies
    private weak var cameraManager: CameraManager?
    private weak var roiDetector: ROIDetector?
    private weak var motionDetector: MotionDetector?
    private weak var vehicleDetector: VehicleDetector?

    // Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Will be configured with dependencies after initialization
    }

    func configure(cameraManager: CameraManager, roiDetector: ROIDetector, motionDetector: MotionDetector, vehicleDetector: VehicleDetector) {
        self.cameraManager = cameraManager
        self.roiDetector = roiDetector
        self.motionDetector = motionDetector
        self.vehicleDetector = vehicleDetector

        // Subscribe to ROI occupancy changes
        roiDetector.$isROIOccupied
            .sink { [weak self] isOccupied in
                self?.handleROIOccupancyChange(isOccupied)
            }
            .store(in: &cancellables)
        
        // Subscribe to vehicle detection changes
        vehicleDetector.$isVehicleDetected
            .sink { [weak self] isVehicleDetected in
                self?.handleVehicleDetectionChange(isVehicleDetected)
            }
            .store(in: &cancellables)

        // Subscribe to motion detector changes
        motionDetector.$isVehicleStopped
            .sink { [weak self] isStopped in
                self?.handleVehicleStopChange(isStopped)
            }
            .store(in: &cancellables)
    }

    func startSession() {
        guard !isIntervalCaptureActive && !isStopCaptureActive else { return }

        isIntervalCaptureActive = true
        isStopCaptureActive = true
        sessionStartTime = Date()
        captureCount = 0
        lastDebounceTime = nil

        print("TriggerEngine: Session started (interval + stop detection)")
    }

    func stopSession() {
        guard isIntervalCaptureActive || isStopCaptureActive else { return }

        isIntervalCaptureActive = false
        isStopCaptureActive = false
        intervalTimer?.invalidate()
        intervalTimer = nil

        print("TriggerEngine: Session stopped. Total captures: \(captureCount)")
    }

    func resetSession() {
        stopSession()
        captureCount = 0
        sessionStartTime = nil
        lastCaptureTime = nil
        lastDebounceTime = nil
        isStopCaptureActive = false
    }

    func canCapture() -> Bool {
        // Check debounce period
        if let lastDebounce = lastDebounceTime {
            let timeSinceLastCapture = Date().timeIntervalSince(lastDebounce)
            if timeSinceLastCapture < debounceDuration {
                return false
            }
        }

        // Check capture limit
        if captureCount >= maxCapturesPerSession {
            return false
        }

        return true
    }

    private func handleROIOccupancyChange(_ isOccupied: Bool) {
        guard isIntervalCaptureActive else { return }

        if isOccupied {
            startIntervalTimer()
            // Start video recording when vehicle enters ROI
            startVideoRecordingIfNeeded()
        } else {
            stopIntervalTimer()
            // Stop video recording when vehicle leaves ROI
            stopVideoRecordingIfNeeded()
        }
    }

    private func handleVehicleStopChange(_ isStopped: Bool) {
        guard isStopCaptureActive else { return }

        if isStopped {
            // Vehicle has stopped, trigger capture with additional debouncing
            // Only trigger if we haven't captured recently
            if let lastDebounce = lastDebounceTime {
                let timeSinceLastCapture = Date().timeIntervalSince(lastDebounce)
                if timeSinceLastCapture >= debounceDuration {
                    triggerStopCapture()
                } else {
                    print("TriggerEngine: Stop capture skipped - too soon after last capture")
                }
            } else {
                triggerStopCapture()
            }
        }
    }
    
    private func handleVehicleDetectionChange(_ isVehicleDetected: Bool) {
        // Handle vehicle detection changes
        if isVehicleDetected {
            print("TriggerEngine: Vehicle detected - enabling capture triggers")
            // Vehicle detected, ensure capture triggers are active
            if roiDetector?.isROIOccupied == true {
                startIntervalTimer()
            }
        } else {
            print("TriggerEngine: Vehicle lost - disabling capture triggers")
            // Vehicle lost, stop capture triggers
            stopIntervalTimer()
        }
    }

    private func startIntervalTimer() {
        // Don't start a new timer if one is already running
        guard intervalTimer == nil else { return }

        print("TriggerEngine: ROI occupied - starting interval timer")

        intervalTimer = Timer.scheduledTimer(withTimeInterval: intervalDuration, repeats: true) { _ in
            Task { @MainActor in
                self.triggerCapture()
            }
        }
    }

    private func stopIntervalTimer() {
        guard intervalTimer != nil else { return }

        print("TriggerEngine: ROI not occupied - stopping interval timer")

        intervalTimer?.invalidate()
        intervalTimer = nil
    }

    private func triggerCapture() {
        guard canCapture() else {
            print("TriggerEngine: Capture blocked (debounce or limit)")
            return
        }

        guard let roiDetector = roiDetector, roiDetector.isROIOccupied else {
            print("TriggerEngine: ROI not occupied - skipping capture")
            return
        }

        // Perform capture
        performCapture()
    }

    private func triggerStopCapture() {
        guard canCapture() else {
            print("TriggerEngine: Stop capture blocked (debounce or limit)")
            return
        }

        guard let roiDetector = roiDetector, roiDetector.isROIOccupied else {
            print("TriggerEngine: ROI not occupied - skipping stop capture")
            return
        }

        // Perform stop-based capture
        performStopCapture()
    }

    private func performCapture() {
        guard let cameraManager = cameraManager else {
            print("TriggerEngine: No camera manager available")
            return
        }

        // Check capture limit before proceeding
        if captureCount >= maxCapturesPerSession {
            print("TriggerEngine: Capture limit reached (\(maxCapturesPerSession)), stopping session")
            stopSession()
            return
        }

        print("TriggerEngine: Triggering interval capture #\(captureCount + 1)")

        // Update capture tracking
        lastCaptureTime = Date()
        lastDebounceTime = Date()
        captureCount += 1

        // Trigger the actual capture
        cameraManager.capturePhoto(triggerType: .interval)

        // Trigger capture feedback
        cameraManager.triggerCaptureFeedback()

        // Check if we've reached the capture limit after this capture
        if captureCount >= maxCapturesPerSession {
            print("TriggerEngine: Reached capture limit (\(maxCapturesPerSession))")
            stopSession()
        }
    }

    private func performStopCapture() {
        guard let cameraManager = cameraManager else {
            print("TriggerEngine: No camera manager available")
            return
        }

        // Check capture limit before proceeding
        if captureCount >= maxCapturesPerSession {
            print("TriggerEngine: Capture limit reached (\(maxCapturesPerSession)), stopping session")
            stopSession()
            return
        }

        print("TriggerEngine: Triggering stop capture #\(captureCount + 1)")

        // Update capture tracking
        lastCaptureTime = Date()
        lastDebounceTime = Date()
        captureCount += 1

        // Trigger the actual capture
        cameraManager.capturePhoto(triggerType: .stop)

        // Trigger capture feedback
        cameraManager.triggerCaptureFeedback()

        // Check if we've reached the capture limit after this capture
        if captureCount >= maxCapturesPerSession {
            print("TriggerEngine: Reached capture limit (\(maxCapturesPerSession))")
            stopSession()
        }
    }

    // MARK: - Session Statistics

    func getSessionDuration() -> TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }

    func getCaptureRate() -> Double {
        let duration = getSessionDuration()
        guard duration > 0 else { return 0 }
        return Double(captureCount) / duration
    }

    func getTimeSinceLastCapture() -> TimeInterval {
        guard let lastCapture = lastCaptureTime else { return 0 }
        return Date().timeIntervalSince(lastCapture)
    }

    func getTimeUntilNextCapture() -> TimeInterval {
        guard let lastDebounce = lastDebounceTime else { return 0 }
        let timeSinceLastCapture = Date().timeIntervalSince(lastDebounce)
        return max(0, debounceDuration - timeSinceLastCapture)
    }

    // MARK: - Configuration

    func setIntervalDuration(_ duration: TimeInterval) {
        // This would require stopping and restarting the timer if active
        // For now, we'll keep it constant as per the specification
    }

    func setMaxCapturesPerSession(_ max: Int) {
        // This would require checking against the new limit
        // For now, we'll keep it constant as per the specification
    }

    // MARK: - Video Recording During Rotation

    func startVideoRecording() {
        guard let cameraManager = cameraManager else {
            print("TriggerEngine: No camera manager available for video recording")
            return
        }

        cameraManager.startVideoRecording()
        print("TriggerEngine: Started video recording during rotation")
    }

    func stopVideoRecording() {
        guard let cameraManager = cameraManager else {
            print("TriggerEngine: No camera manager available for video recording")
            return
        }

        cameraManager.stopVideoRecording()
        print("TriggerEngine: Stopped video recording")
    }

    func isVideoRecording() -> Bool {
        return cameraManager?.isVideoRecording ?? false
    }

    // MARK: - Video Recording with Rotation Detection

    private func startVideoRecordingIfNeeded() {
        guard let cameraManager = cameraManager else { return }

        // Only start video recording if not already recording
        if !cameraManager.isVideoRecording {
            cameraManager.startVideoRecording()
            print("TriggerEngine: Auto-started video recording for rotation")
        }
    }

    private func stopVideoRecordingIfNeeded() {
        guard let cameraManager = cameraManager else { return }

        // Only stop video recording if currently recording
        if cameraManager.isVideoRecording {
            cameraManager.stopVideoRecording()
            print("TriggerEngine: Auto-stopped video recording after rotation")
        }
    }
}
