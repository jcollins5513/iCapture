import Foundation

extension CameraManager {
    @objc func handleLiDARScanCompleted(_ notification: Notification) {
        Task { @MainActor in
            self.onLiDARScanCompleted()
        }
    }

    @MainActor
    func onLiDARScanCompleted() {
        print("CameraManager: LiDAR environment scan completed - resuming camera capture workflow")

        if lidarDetector.isSessionRunning {
            stopLiDARDetection()
        } else {
            restartCaptureSessionIfNeeded()
        }

        useLiDARDetection = true
        lastLiDARProcessingState = nil
        print("CameraManager: LiDAR depth data cached for background removal")

        if shouldAutoStartTriggers && autoCaptureState == .waitingForLiDAR {
            autoCaptureState = .waitingForBackground
            scheduleAutomaticBackgroundSampling()
        }
    }

    @objc func handleBackgroundSamplingCompleted(_ notification: Notification) {
        Task { @MainActor in
            self.onBackgroundSamplingCompleted()
        }
    }

    @MainActor
    func onBackgroundSamplingCompleted() {
        guard shouldAutoStartTriggers else { return }
        finalizeAutomaticCaptureWorkflow(reason: "background sampling completed")
    }

    @MainActor
    func beginAutomaticCaptureWorkflow() {
        guard autoCaptureState == .idle else {
            print("CameraManager: Automatic capture workflow already in progress")
            return
        }

        guard sessionManager?.isSessionActive == true else {
            print("CameraManager: Cannot begin automatic workflow without active session")
            return
        }

        print("CameraManager: Beginning automatic capture workflow")

        shouldAutoStartTriggers = true
        triggerEngine.stopSession()
        triggerEngine.resetSession()
        roiDetector.resetBackgroundLearning()

        if lidarDetector.isLiDARAvailable {
            autoCaptureState = .waitingForLiDAR
            startLiDARDetection()
        } else {
            autoCaptureState = .waitingForBackground
            scheduleAutomaticBackgroundSampling(delay: 0.2)
        }
    }

    @MainActor
    func cancelAutomaticCaptureWorkflow() {
        shouldAutoStartTriggers = false
        autoCaptureState = .idle
        backgroundSamplingWorkItem?.cancel()
        backgroundSamplingTimeoutWorkItem?.cancel()
        backgroundSamplingTimeoutWorkItem = nil
        roiDetector.resetBackgroundLearning()
        print("CameraManager: Automatic capture workflow cancelled")
    }

    @MainActor
    func scheduleAutomaticBackgroundSampling(delay: TimeInterval = 0.5) {
        backgroundSamplingWorkItem?.cancel()
        backgroundSamplingTimeoutWorkItem?.cancel()
        backgroundSamplingTimeoutWorkItem = nil
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.roiDetector.resetBackgroundLearning()
                self.roiDetector.startBackgroundSampling()
                print("CameraManager: Automatic background sampling started")
            }
        }
        backgroundSamplingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)

        let timeoutItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self = self, self.shouldAutoStartTriggers else { return }
                print("CameraManager: Automatic background sampling timed out - proceeding with capture workflow")
                self.finalizeAutomaticCaptureWorkflow(reason: "background sampling timeout")
            }
        }
        backgroundSamplingTimeoutWorkItem = timeoutItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 2.0, execute: timeoutItem)
    }

    @objc func handleSessionDidStart(_ notification: Notification) {
        Task { @MainActor in
            if self.sessionManager?.isSessionActive == true {
                self.beginAutomaticCaptureWorkflow()
            }
        }
    }

    @MainActor
    private func finalizeAutomaticCaptureWorkflow(reason: String) {
        guard autoCaptureState == .waitingForBackground else { return }

        autoCaptureState = .idle
        shouldAutoStartTriggers = false
        backgroundSamplingWorkItem?.cancel()
        backgroundSamplingTimeoutWorkItem?.cancel()
        backgroundSamplingTimeoutWorkItem = nil

        if sessionManager?.isSessionActive == true {
            triggerEngine.resetSession()
            triggerEngine.startSession()
            print("CameraManager: Automatic capture workflow completed (\(reason)) - triggers started")
        } else {
            print("CameraManager: Background sampling finished but session inactive")
        }
    }
}
