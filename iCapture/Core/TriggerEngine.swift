//
//  TriggerEngine.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import Combine
import Foundation

@MainActor
class TriggerEngine: ObservableObject {
    @Published var isIntervalCaptureActive = false
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

    // Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Will be configured with dependencies after initialization
    }

    func configure(cameraManager: CameraManager, roiDetector: ROIDetector) {
        self.cameraManager = cameraManager
        self.roiDetector = roiDetector

        // Subscribe to ROI occupancy changes
        roiDetector.$isROIOccupied
            .sink { [weak self] isOccupied in
                self?.handleROIOccupancyChange(isOccupied)
            }
            .store(in: &cancellables)
    }

    func startSession() {
        guard !isIntervalCaptureActive else { return }

        isIntervalCaptureActive = true
        sessionStartTime = Date()
        captureCount = 0
        lastDebounceTime = nil

        print("TriggerEngine: Session started")
    }

    func stopSession() {
        guard isIntervalCaptureActive else { return }

        isIntervalCaptureActive = false
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
        } else {
            stopIntervalTimer()
        }
    }

    private func startIntervalTimer() {
        // Don't start a new timer if one is already running
        guard intervalTimer == nil else { return }

        print("TriggerEngine: ROI occupied - starting interval timer")

        intervalTimer = Timer.scheduledTimer(withTimeInterval: intervalDuration, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.triggerCapture()
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

    private func performCapture() {
        guard let cameraManager = cameraManager else {
            print("TriggerEngine: No camera manager available")
            return
        }

        print("TriggerEngine: Triggering capture #\(captureCount + 1)")

        // Update capture tracking
        lastCaptureTime = Date()
        lastDebounceTime = Date()
        captureCount += 1

        // Trigger the actual capture
        cameraManager.captureTestShot()

        // Trigger capture feedback
        cameraManager.triggerCaptureFeedback()

        // Check if we've reached the capture limit
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
}
