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

        if autoCaptureState == .waitingForBackground {
            autoCaptureState = .idle
            shouldAutoStartTriggers = false
            backgroundSamplingWorkItem?.cancel()

            if sessionManager?.isSessionActive == true {
                triggerEngine.resetSession()
                triggerEngine.startSession()
                print("CameraManager: Automatic capture workflow completed - triggers started")
            } else {
                print("CameraManager: Background sampling completed but session inactive")
            }
        }
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
        roiDetector.resetBackgroundLearning()
        print("CameraManager: Automatic capture workflow cancelled")
    }

    @MainActor
    func scheduleAutomaticBackgroundSampling(delay: TimeInterval = 0.5) {
        backgroundSamplingWorkItem?.cancel()
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
    }

    @objc func handleSessionDidStart(_ notification: Notification) {
        Task { @MainActor in
            if self.sessionManager?.isSessionActive == true {
                self.beginAutomaticCaptureWorkflow()
            }
        }
    }
}
