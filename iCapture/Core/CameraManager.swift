//
//  CameraManager.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

@preconcurrency import AVFoundation
import Combine
import SwiftUI
import AudioToolbox

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isSessionRunning = false
    @Published var testShotCaptured = false
    @Published var showCaptureFlash = false

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureDevice: AVCaptureDevice?

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoDataQueue = DispatchQueue(label: "camera.video.data.queue")
    private let photoQueue = DispatchQueue(label: "camera.photo.queue")

    // ROI Detection, Motion Detection and Trigger Engine
    @Published var roiDetector = ROIDetector()
    @Published var motionDetector = MotionDetector()
    @Published var triggerEngine = TriggerEngine()

    // Session Manager reference (will be set by CameraView)
    weak var sessionManager: SessionManager?

    override init() {
        super.init()
        checkAuthorization()

        // Configure trigger engine with dependencies
        triggerEngine.configure(cameraManager: self, roiDetector: roiDetector, motionDetector: motionDetector)
    }

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCaptureSession()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        @unknown default:
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        }
    }

    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.captureSession.beginConfiguration()

            // Configure session preset for high quality
            if self.captureSession.canSetSessionPreset(.photo) {
                self.captureSession.sessionPreset = .photo
            }

            // Add video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                            for: .video,
                                                            position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.captureSession.canAddInput(videoInput) else {
                self.captureSession.commitConfiguration()
                return
            }

            self.captureSession.addInput(videoInput)
            self.captureDevice = videoDevice

            // Add video output for preview
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
                self.videoOutput.setSampleBufferDelegate(self, queue: self.videoDataQueue)
            }

            // Add photo output
            if self.captureSession.canAddOutput(self.photoOutput) {
                self.captureSession.addOutput(self.photoOutput)
                // Configure for high quality photos
                if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    self.photoOutput.setPreparedPhotoSettingsArray([
                        AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                    ])
                }
            }

            self.captureSession.commitConfiguration()

            // Create preview layer
            DispatchQueue.main.async {
                self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                self.previewLayer?.videoGravity = .resizeAspectFill
            }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
            }
        }
    }

    func captureTestShot() {
        capturePhoto(triggerType: .manual)
    }

    func capturePhoto(triggerType: TriggerType) {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }

            let photoSettings: AVCapturePhotoSettings

            // Configure for high quality
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                photoSettings = AVCapturePhotoSettings()
            }

            // Add metadata
            photoSettings.metadata = [
                "com.icapture.trigger": triggerType.rawValue,
                "com.icapture.timestamp": Date().timeIntervalSince1970
            ]

            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }

    func triggerCaptureFeedback() {
        // Visual flash feedback
        showCaptureFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showCaptureFlash = false
        }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Sound feedback
        AudioServicesPlaySystemSound(1108) // Camera shutter sound
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Process frame for ROI detection
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        Task { @MainActor in
            roiDetector.processFrame(pixelBuffer)
            motionDetector.processFrame(pixelBuffer)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }

        // Save photo to appropriate directory
        photoQueue.async { [weak self] in
            guard let self = self else { return }

            guard let imageData = photo.fileDataRepresentation() else {
                print("Failed to get image data")
                return
            }

            // Determine trigger type from metadata
            let triggerType: TriggerType
            let metadata = photo.metadata
            if let triggerString = metadata["com.icapture.trigger"] as? String,
               let trigger = TriggerType(rawValue: triggerString) {
                triggerType = trigger
            } else {
                triggerType = .manual
            }

            // Get image dimensions
            let width = photo.resolvedSettings.photoDimensions.width
            let height = photo.resolvedSettings.photoDimensions.height

            // Get ROI rectangle
            let roiRect = self.roiDetector.getROIRect()

            // Create filename with timestamp
            let timestamp = Date().timeIntervalSince1970
            let filename = "photo_\(Int(timestamp)).heic"

            // Save to session directory if session is active, otherwise to test shots
            if let sessionManager = self.sessionManager, sessionManager.isSessionActive {
                let params = PhotoSessionParams(
                    imageData: imageData,
                    filename: filename,
                    width: Int(width),
                    height: Int(height),
                    roiRect: roiRect,
                    triggerType: triggerType
                )
                self.savePhotoToSession(params)
            } else {
                self.saveTestShot(imageData: imageData, filename: filename)
            }
        }
    }

    private struct PhotoSessionParams {
        let imageData: Data
        let filename: String
        let width: Int
        let height: Int
        let roiRect: CGRect
        let triggerType: TriggerType
    }

    private func savePhotoToSession(_ params: PhotoSessionParams) {
        guard let sessionManager = sessionManager,
              let session = sessionManager.currentSession,
              let sessionURL = sessionManager.sessionDirectory else {
            print("No active session - saving as test shot")
            saveTestShot(imageData: params.imageData, filename: params.filename)
            return
        }

        do {
            // Save to photos subdirectory
            let photosURL = sessionURL.appendingPathComponent("photos")
            let fileURL = photosURL.appendingPathComponent(params.filename)
            try params.imageData.write(to: fileURL)

            // Create capture asset
            let asset = CaptureAsset(
                sessionId: session.id,
                type: .photo,
                filename: params.filename,
                width: params.width,
                height: params.height,
                roiRect: params.roiRect,
                triggerType: params.triggerType
            )

            // Add asset to session
            try sessionManager.addAsset(asset)

            print("Photo saved to session: \(params.filename)")

            DispatchQueue.main.async {
                self.testShotCaptured = true
            }
        } catch {
            print("Failed to save photo to session: \(error)")
        }
    }

    private func saveTestShot(imageData: Data, filename: String) {
        // Create test shots directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let testShotsDirectory = documentsPath.appendingPathComponent("TestShots")

        try? FileManager.default.createDirectory(at: testShotsDirectory, withIntermediateDirectories: true)

        // Save with timestamp
        let fileURL = testShotsDirectory.appendingPathComponent(filename)

        do {
            try imageData.write(to: fileURL)
            print("Test shot saved: \(fileURL)")

            DispatchQueue.main.async {
                self.testShotCaptured = true
            }
        } catch {
            print("Failed to save test shot: \(error)")
        }
    }
}
