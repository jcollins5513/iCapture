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
        lidarBoostState = .ready
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
        print("CameraManager: Automatic workflow temporarily disabled; manual capture only")
    }

    @MainActor
    func cancelAutomaticCaptureWorkflow() {
        shouldAutoStartTriggers = false
        autoCaptureState = .idle
        backgroundSamplingWorkItem?.cancel()
        backgroundSamplingTimeoutWorkItem?.cancel()
        backgroundSamplingTimeoutWorkItem = nil
        backgroundSamplingAttempt = 0
        roiDetector.resetBackgroundLearning()
        print("CameraManager: Automatic capture workflow cancelled")
    }

    @MainActor
    func scheduleAutomaticBackgroundSampling(delay: TimeInterval = 0.5) {
        backgroundSamplingWorkItem?.cancel()
        backgroundSamplingTimeoutWorkItem?.cancel()
        backgroundSamplingTimeoutWorkItem = nil
        guard shouldAutoStartTriggers else { return }

        let nextAttempt = backgroundSamplingAttempt + 1
        backgroundSamplingAttempt = nextAttempt

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                guard self.shouldAutoStartTriggers else { return }
                self.roiDetector.resetBackgroundLearning()
                self.roiDetector.startBackgroundSampling()
                print("CameraManager: Automatic background sampling started (attempt \(nextAttempt))")
                self.monitorBackgroundSampling(startedAt: Date(), attempt: nextAttempt)
            }
        }
        backgroundSamplingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    @objc func handleSessionDidStart(_ notification: Notification) {
        Task { @MainActor in
            if self.sessionManager?.isSessionActive == true {
                self.backgroundRemovalEnabled = true
                self.beginAutomaticCaptureWorkflow()
            }
        }
    }

    @MainActor
    private func finalizeAutomaticCaptureWorkflow(reason: String) {
        guard autoCaptureState == .waitingForBackground else { return }

        autoCaptureState = .idle
        shouldAutoStartTriggers = false
        backgroundSamplingAttempt = 0
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

    @MainActor
    private func monitorBackgroundSampling(startedAt: Date, attempt: Int) {
        backgroundSamplingTimeoutWorkItem?.cancel()

        let monitorItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self = self, self.shouldAutoStartTriggers else { return }

                let progress = self.roiDetector.backgroundSampleProgress
                let learned = self.roiDetector.isBackgroundLearned
                let elapsed = Date().timeIntervalSince(startedAt)
                let progressPct = Int(progress * 100)
                print(
                    """
                    CameraManager: Monitoring background sampling attempt \(attempt) - \
                    elapsed: \(String(format: "%.2f", elapsed))s, progress: \(progressPct)%, learned: \(learned)
                    """
                )

                if self.roiDetector.isBackgroundLearned {
                    self.finalizeAutomaticCaptureWorkflow(reason: "background sampling completed")
                    return
                }

                if elapsed >= self.backgroundSamplingTimeout {
                    let framesCollected = self.roiDetector.backgroundSampleFrameCount

                    if self.useLiDARDetection && (!self.lidarDetector.isTrackingNormal || framesCollected <= 2) {
                        print(
                            """
                            CameraManager: Background sampling collected \(framesCollected) frame(s) \
                            with limited LiDAR tracking; disabling LiDAR and retrying with Vision-only sampling
                            """
                        )
                        self.disableLiDARDetection()
                        self.scheduleAutomaticBackgroundSampling(delay: 0.3)
                        return
                    }

                    if attempt >= self.maxBackgroundSamplingAttempts {
                        print("CameraManager: Background sampling timed out after \(attempt) attempts; finalizing")
                        self.finalizeAutomaticCaptureWorkflow(reason: "background sampling timeout")
                    } else {
                        print("CameraManager: Background sampling attempt \(attempt) timed out; retrying")
                        self.scheduleAutomaticBackgroundSampling(delay: 0.5)
                    }
                    return
                }

                self.monitorBackgroundSampling(startedAt: startedAt, attempt: attempt)
            }
        }

        backgroundSamplingTimeoutWorkItem = monitorItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + backgroundSamplingMonitorInterval,
            execute: monitorItem
        )
    }
}
