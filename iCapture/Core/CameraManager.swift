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
import Photos
import ImageIO

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

    // Video recording manager
    @Published var videoRecordingManager = VideoRecordingManager()

    // ROI Detection, Motion Detection, Vehicle Detection and Trigger Engine
    @Published var roiDetector = ROIDetector()
    @Published var motionDetector = MotionDetector()
    @Published var vehicleDetector = VehicleDetector()
    @Published var triggerEngine = TriggerEngine()
    @Published var backgroundRemover = BackgroundRemover()

    // LiDAR-based detection (preferred when available)
    @Published var lidarDetector = LiDARDetector()
    @Published var lidarBackgroundRemover = LiDARBackgroundRemover()
    @Published var useLiDARDetection = false

    // Background removal settings
    @Published var backgroundRemovalEnabled = false

    // Session Manager reference (will be set by CameraView)
    weak var sessionManager: SessionManager?

    // Performance monitoring
    @Published var performanceMonitor = PerformanceMonitor()

    // Debug tools
    @Published var cameraDebugger = CameraDebugger()

    // Orientation handling
    private var lastVideoOrientation: AVCaptureVideoOrientation?
    private var orientationUpdateTimer: Timer?

    @available(iOS 17.0, *)
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

    @available(iOS 17.0, *)
    private var lastVideoRotationAngle: CGFloat?

    var lastLiDARProcessingState: Bool?
    enum AutoCaptureWorkflowState {
        case idle
        case waitingForLiDAR
        case waitingForBackground
    }
    var autoCaptureState: AutoCaptureWorkflowState = .idle
    var shouldAutoStartTriggers = false
    var backgroundSamplingWorkItem: DispatchWorkItem?
    var backgroundSamplingTimeoutWorkItem: DispatchWorkItem?
    private var pendingTriggerType: TriggerType = .manual

    fileprivate final class PixelBufferBox: @unchecked Sendable {
        let buffer: CVPixelBuffer
        init(_ buffer: CVPixelBuffer) {
            self.buffer = buffer
        }
    }

    override init() {
        super.init()
        checkAuthorization()

        // Configure trigger engine with dependencies
        triggerEngine.configure(
            cameraManager: self,
            roiDetector: roiDetector,
            motionDetector: motionDetector,
            vehicleDetector: vehicleDetector
        )

        // Configure video recording manager
        videoRecordingManager.configure(
            sessionManager: sessionManager,
            roiDetector: roiDetector
        )

        // Initialize LiDAR detection if available
        initializeLiDARDetection()

        // Listen for LiDAR timeout notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLiDARTimeout),
            name: NSNotification.Name("LiDARDetectionTimeout"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLiDARScanCompleted(_:)),
            name: .LiDARScanCompleted,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackgroundSamplingCompleted(_:)),
            name: .BackgroundSamplingCompleted,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionDidStart(_:)),
            name: .sessionDidStart,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension CameraManager {
    @objc private func handleLiDARTimeout() {
        print("CameraManager: LiDAR detection timeout - disabling LiDAR and switching to traditional detection")
        disableLiDARDetection()
    }

    @MainActor
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.isAuthorized = granted
                    if granted {
                        self.setupCaptureSession()
                    }
                }
            }
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            print("CameraManager: Setting up capture session...")
            self.captureSession.beginConfiguration()

            configureSessionPreset()

            guard addVideoInput() else {
                self.captureSession.commitConfiguration()
                return
            }

            self.captureSession.addInput(videoInput)
            self.captureDevice = videoDevice
            print("CameraManager: Video input added successfully")

            // Add video output for preview
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
                self.videoOutput.setSampleBufferDelegate(self, queue: self.videoDataQueue)
                print("CameraManager: Video output added successfully")
            } else {
                print("CameraManager: WARNING - Cannot add video output")
            }

            // Add photo output
            if self.captureSession.canAddOutput(self.photoOutput) {
                self.captureSession.addOutput(self.photoOutput)
                if self.photoOutput.isDepthDataDeliverySupported {
                    self.photoOutput.isDepthDataDeliveryEnabled = true
                    print("CameraManager: Depth data delivery enabled for photo output")
                } else {
                    print("CameraManager: Depth data delivery not supported")
                }

                self.photoOutput.isHighResolutionCaptureEnabled = true
                if #available(iOS 15.0, *) {
                    self.photoOutput.maxPhotoQualityPrioritization = .quality
                }

                if self.photoOutput.isLivePhotoCaptureSupported {
                    self.photoOutput.isLivePhotoCaptureEnabled = false
                }

                if self.photoOutput.isDualCameraDualPhotoDeliverySupported {
                    self.photoOutput.isDualCameraDualPhotoDeliveryEnabled = false
                }
                print("CameraManager: Photo output added successfully")
            } else {
                print("CameraManager: WARNING - Cannot add photo output")
            }

            // Add movie file output for video recording
            let movieFileOutput = DispatchQueue.main.sync {
                return self.videoRecordingManager.getMovieFileOutput()
            }
            if self.captureSession.canAddOutput(movieFileOutput) {
                self.captureSession.addOutput(movieFileOutput)
                print("CameraManager: Movie file output added successfully")
            } else {
                print("CameraManager: WARNING - Cannot add movie file output")
            }

            self.captureSession.commitConfiguration()
            print("CameraManager: Session configuration committed")

            // Configure photo output for high resolution after session is committed
            DispatchQueue.main.async {
                self.configurePhotoOutputForHighResolution()
            }

            DispatchQueue.main.async {
                self.createPreviewLayer()
            }
        }
    }

    private func configureSessionPreset() {
        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
            print("CameraManager: Session preset set to photo")
        }
    }

    private func addVideoInput() -> Bool {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            print("CameraManager: ERROR - Failed to create video input")
            return false
        }

        captureSession.addInput(videoInput)
        captureDevice = videoDevice
        print("CameraManager: Video input added successfully")
        return true
    }

    private func addVideoOutput() {
        guard captureSession.canAddOutput(videoOutput) else {
            print("CameraManager: WARNING - Cannot add video output")
            return
        }

        captureSession.addOutput(videoOutput)
        videoOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
        print("CameraManager: Video output added successfully")
    }

    private func addPhotoOutput() {
        guard captureSession.canAddOutput(photoOutput) else {
            print("CameraManager: WARNING - Cannot add photo output")
            return
        }

        captureSession.addOutput(photoOutput)
        if photoOutput.isDepthDataDeliverySupported {
            photoOutput.isDepthDataDeliveryEnabled = true
            print("CameraManager: Depth data delivery enabled for photo output")
        } else {
            print("CameraManager: Depth data delivery not supported")
        }
        print("CameraManager: Photo output added successfully")
    }

    private func addMovieOutput() {
        let movieFileOutput = DispatchQueue.main.sync {
            videoRecordingManager.getMovieFileOutput()
        }

        guard captureSession.canAddOutput(movieFileOutput) else {
            print("CameraManager: WARNING - Cannot add movie file output")
            return
        }

        captureSession.addOutput(movieFileOutput)
        print("CameraManager: Movie file output added successfully")
    }

    private func createPreviewLayer() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill

        self.previewLayer = previewLayer
        print("CameraManager: Preview layer created and configured")
        print("CameraManager: Preview layer session: \(previewLayer.session != nil)")
        print("CameraManager: Preview layer videoGravity: \(previewLayer.videoGravity)")
        print("CameraManager: Preview layer connection: \(previewLayer.connection != nil)")
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            print("CameraManager: Starting capture session")

            // Check camera hardware status before starting
            if let device = self.captureDevice {
                print("CameraManager: Camera device: \(device.localizedName)")
                print("CameraManager: Camera position: \(device.position.rawValue)")
                print("CameraManager: Camera format: \(device.activeFormat)")
            } else {
                print("CameraManager: ERROR - No camera device available!")
            }

            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
                print("CameraManager: Session running: \(self.captureSession.isRunning)")
                if let previewLayer = self.previewLayer {
                    print("CameraManager: Preview layer exists, session: \(previewLayer.session != nil)")
                    print("CameraManager: Preview layer frame: \(previewLayer.frame)")
                } else {
                    print("CameraManager: WARNING - Preview layer is nil!")
                }

                // LiDAR detection will be started manually when needed
                // Don't start it automatically to avoid camera conflicts

                // Start debugging if enabled
                if self.cameraDebugger.isDebugMode {
                    self.cameraDebugger.startDebugging(cameraManager: self)
                }

                // Set initial video orientation
                self.updateVideoOrientation()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning

                // Stop LiDAR detection
                if self.useLiDARDetection {
                    self.lidarDetector.stopLiDARDetection()
                }

                // Stop debugging
                self.cameraDebugger.stopDebugging()

                // Clean up orientation timer
                self.orientationUpdateTimer?.invalidate()
                self.orientationUpdateTimer = nil
            }
        }
    }

    func captureTestShot() {
        capturePhoto(triggerType: .manual)
    }

    func capturePhoto(triggerType: TriggerType) {
        // Record capture start for performance monitoring
        performanceMonitor.recordCaptureStart()

        pendingTriggerType = triggerType

        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }

            let photoSettings: AVCapturePhotoSettings

            // Configure for high quality with 48MP support
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                photoSettings = AVCapturePhotoSettings()
            }

            photoSettings.isHighResolutionPhotoEnabled = true
            if #available(iOS 15.0, *) {
                photoSettings.photoQualityPrioritization = .quality
            }

            photoSettings.isAutoStillImageStabilizationEnabled = true
            photoSettings.isAutoDualCameraFusionEnabled = true

            // Enable high resolution capture if supported
            if #available(iOS 16.0, *) {
                if let device = self.captureDevice,
                   let maxDimensions = device.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }),
                   maxDimensions.width >= 8000 {
                    if self.photoOutput.isDepthDataDeliveryEnabled && !(self.useLiDARDetection && self.lidarDetector.isSessionRunning) {
                        print("CameraManager: Depth data enabled - using standard resolution for compatibility")
                    } else if self.photoOutput.maxPhotoDimensions.width >= maxDimensions.width {
                        photoSettings.maxPhotoDimensions = maxDimensions
                        print("CameraManager: Capturing 48MP high-resolution photo")
                    } else {
                        print("CameraManager: Photo output doesn't support 48MP, using standard resolution")
                    }
                } else {
                    print("CameraManager: Capturing standard resolution photo")
                }
            }

            // Note: Custom metadata keys are not allowed by AVFoundation
            // We'll store trigger info in session data instead

            if self.photoOutput.isDepthDataDeliveryEnabled {
                let shouldCaptureDepth = !(self.useLiDARDetection && self.lidarDetector.isSessionRunning)
                photoSettings.isDepthDataDeliveryEnabled = shouldCaptureDepth
                if shouldCaptureDepth, #available(iOS 16.0, *) {
                    photoSettings.isDepthDataFiltered = true
                }
            }

            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }

    @MainActor
    func triggerCaptureFeedback() {
        // Visual flash feedback
        showCaptureFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.showCaptureFlash = false
        }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Sound feedback
        AudioServicesPlaySystemSound(1_108) // Camera shutter sound
    }

    // MARK: - Video Recording Methods

    func startVideoRecording() {
        videoRecordingManager.startVideoRecording()
    }

    func stopVideoRecording() {
        videoRecordingManager.stopVideoRecording()
    }

    var isVideoRecording: Bool {
        videoRecordingManager.isVideoRecording
    }

    var videoRecordingDuration: TimeInterval {
        videoRecordingManager.videoRecordingDuration
    }

    func getFormattedVideoDuration() -> String {
        videoRecordingManager.getFormattedVideoDuration()
    }

    // MARK: - High-Resolution Photo Configuration

    @MainActor
    private func configurePhotoOutputForHighResolution() {
        // Check if device supports 48MP capture (iPhone 15 Pro and Pro Max)
        _ = UIDevice.current.model
        _ = UIDevice.current.systemVersion

        // Configure photo settings for maximum resolution
        var photoSettings: AVCapturePhotoSettings

        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            // Use HEVC/HEIF format for better compression
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            // Fallback to standard format
            photoSettings = AVCapturePhotoSettings()
        }

        // Check if 48MP is available but don't set maxPhotoDimensions here
        // We'll set it per capture to avoid conflicts
        if #available(iOS 16.0, *) {
            if let device = captureDevice,
               let maxDimensions = device.activeFormat.supportedMaxPhotoDimensions
                .max(by: { lhs, rhs in
                    (lhs.width * lhs.height) < (rhs.width * rhs.height)
                }),
               maxDimensions.width >= 8_000 {
                print("CameraManager: 48MP high-resolution capture supported")
            } else {
                print("CameraManager: 48MP capture not available, using standard resolution")
            }
        }

        // Set up prepared photo settings for optimal performance
        photoOutput.setPreparedPhotoSettingsArray([photoSettings])

        print("CameraManager: Photo output configured for high-resolution capture")
    }

    @MainActor
    func getMaxPhotoResolution() -> CGSize {
        guard let device = captureDevice else {
            return CGSize(width: 4_032, height: 3_024) // Default 12MP
        }

        // Return the maximum supported resolution
        if #available(iOS 16.0, *),
           let maxDimensions = device.activeFormat.supportedMaxPhotoDimensions
            .max(by: { lhs, rhs in
                (lhs.width * lhs.height) < (rhs.width * rhs.height)
            }),
           maxDimensions.width >= 8_000 {
            return CGSize(width: 8_064, height: 6_048) // 48MP
        } else {
            return CGSize(width: 4_032, height: 3_024) // 12MP
        }
    }

    @MainActor
    func getCurrentPhotoResolution() -> CGSize {
        getMaxPhotoResolution()
    }

    @MainActor
    func getPhotoCaptureInfo() -> PhotoCaptureInfo {
        let resolution = getCurrentPhotoResolution()
        let format = photoOutput.availablePhotoCodecTypes.contains(.hevc) ? "HEIF" : "JPEG"
        let is48MPSupported = (resolution.width >= 8_000 || resolution.height >= 6_000)

        return PhotoCaptureInfo(
            resolution: resolution,
            format: format,
            is48MPSupported: is48MPSupported
        )
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Process frame for ROI detection
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pixelBufferBox = PixelBufferBox(pixelBuffer)

        DispatchQueue.main.async { [weak self, pixelBufferBox] in
            guard let self = self else { return }
            // Record frame for performance monitoring
            self.performanceMonitor.recordFrame()

            let lidarReady = self.useLiDARDetection
                && self.lidarDetector.isLiDARAvailable
                && self.lidarDetector.isSessionRunning
                && self.lidarDetector.depthData != nil

            // Use LiDAR detection if it's ready, otherwise fallback to traditional methods
            if lidarReady {
                if self.lastLiDARProcessingState != true {
                    print("CameraManager: Switching to LiDAR-based frame processing")
                    print("CameraManager: - LiDAR session running: \(self.lidarDetector.isSessionRunning)")
                }
                self.lastLiDARProcessingState = true
            } else {
                if self.lastLiDARProcessingState != false {
                    print("CameraManager: Using traditional frame processing")
                    if self.useLiDARDetection && self.lidarDetector.isLiDARAvailable {
                        print("CameraManager: - LiDAR session running: \(self.lidarDetector.isSessionRunning)")
                        print("CameraManager: - Depth data available: \(self.lidarDetector.depthData != nil)")
                    }
                }
                self.lastLiDARProcessingState = false
                // Traditional frame processing
                let buffer = pixelBufferBox.buffer
                self.roiDetector.processFrame(buffer)
                self.motionDetector.processFrame(buffer)
                self.vehicleDetector.processFrame(buffer)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }

        // Record capture end for performance monitoring
        DispatchQueue.main.async {
            self.performanceMonitor.recordCaptureEnd()
        }

        // Save photo to appropriate directory
        photoQueue.async { [weak self] in
            guard let self = self else { return }
            let triggerType = self.pendingTriggerType
            defer { self.pendingTriggerType = .manual }

            guard let imageData = photo.fileDataRepresentation() else {
                print("Failed to get image data")
                return
            }

            let width = photo.resolvedSettings.photoDimensions.width
            let height = photo.resolvedSettings.photoDimensions.height

            let roiRect = DispatchQueue.main.sync {
                self.roiDetector.getROIRect()
            }

            var depthData = photo.depthData?.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
            if let orientationValue = photo.metadata[kCGImagePropertyOrientation as String] as? UInt32,
               let orientation = CGImagePropertyOrientation(rawValue: orientationValue) {
                depthData = depthData?.applyingExifOrientation(orientation)
            }

            let timestamp = Date().timeIntervalSince1970
            let resolutionSuffix = (width >= 8_000 || height >= 6_000) ? "_48MP" : "_12MP"
            let filename = "photo_\(Int(timestamp))\(resolutionSuffix).heic"

            let fileSizeMB = Double(imageData.count) / (1_024 * 1_024)
            let isHighResolution = (width >= 8_000 || height >= 6_000)
            let maxSizeMB = isHighResolution ? 15.0 : 5.0

            print("CameraManager: Captured photo - Resolution: \(width)x\(height), Size: \(String(format: "%.2f", fileSizeMB))MB")

            if fileSizeMB > maxSizeMB {
                print("CameraManager: WARNING - Photo size (\(String(format: "%.2f", fileSizeMB))MB) exceeds target (\(maxSizeMB)MB)")
            } else {
                print("CameraManager: Photo size within target limits")
            }

            let isSessionActive = DispatchQueue.main.sync {
                self.sessionManager?.isSessionActive ?? false
            }

            if isSessionActive {
                let params = PhotoSessionParams(
                    imageData: imageData,
                    filename: filename,
                    width: Int(width),
                    height: Int(height),
                    roiRect: roiRect,
                    triggerType: triggerType,
                    depthData: depthData
                )
                DispatchQueue.main.async {
                    self.savePhotoToSession(params)
                }
            } else {
                DispatchQueue.main.async {
                    self.saveTestShot(imageData: imageData, filename: filename)
                }
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
        let depthData: AVDepthData?
    }

    @MainActor
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

            // Ensure the file was written successfully
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("CameraManager: Failed to write photo file: \(fileURL.path)")
                return
            }

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

            // Process background removal if enabled
            if self.backgroundRemovalEnabled {
                self.processBackgroundRemoval(
                    imageData: params.imageData,
                    filename: params.filename,
                    depthData: params.depthData,
                    sessionFileURL: fileURL
                )
            } else {
                // Also save to photo library if user has granted permission
                self.saveToPhotoLibrary(imageData: params.imageData)
            }

            DispatchQueue.main.async {
                self.testShotCaptured = true
            }
        } catch {
            print("Failed to save photo to session: \(error)")
        }
    }

    @MainActor
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

    // MARK: - Camera Health Check
    @MainActor
    func checkCameraHealth() -> Bool {
        guard let device = captureDevice else {
            print("CameraManager: Health check failed - No camera device")
            return false
        }

        let isAvailable = device.isConnected && !device.isSuspended
        print("CameraManager: Camera health check - Available: \(isAvailable)")

        if !isAvailable {
            print("CameraManager: Camera not available - Connected: \(device.isConnected), Suspended: \(device.isSuspended)")
        }

        return isAvailable
    }

    @MainActor
    func restartCameraSession() {
        print("CameraManager: Restarting camera session...")
        stopSession()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.setupCaptureSession()
            self?.startSession()
        }
    }

    @MainActor
    func updatePreviewLayerFrame() {
        guard previewLayer != nil else {
            print("CameraManager: Cannot update frame - preview layer is nil")
            return
        }

        // Don't update the preview layer frame here - let CameraPreviewView handle it
        // The preview layer frame should be managed by the UIView that contains it
        print("CameraManager: Preview layer frame update requested - delegating to CameraPreviewView")
    }

    func updateVideoOrientation() {
        // Debounce rapid orientation changes
        orientationUpdateTimer?.invalidate()
        orientationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.performVideoOrientationUpdate()
        }
    }

    private func performVideoOrientationUpdate() {
        guard let previewLayer = previewLayer,
              let connection = previewLayer.connection else {
            print("CameraManager: Cannot update video orientation - no preview layer or connection")
            return
        }

        if #available(iOS 17.0, *) {
            // Lazily create the rotation coordinator if needed
            if rotationCoordinator == nil, let device = captureDevice {
                rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
            }

            guard let coordinator = rotationCoordinator else {
                print("CameraManager: No rotation coordinator available")
                return
            }

            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            if connection.isVideoRotationAngleSupported(angle) {
                if let lastAngle = lastVideoRotationAngle, lastAngle == angle {
                    print("CameraManager: Video rotation angle unchanged: \(angle)")
                } else {
                    print("CameraManager: Applying video rotation angle: \(angle)")
                    connection.videoRotationAngle = angle
                    lastVideoRotationAngle = angle
                    print("CameraManager: Video rotation angle set successfully")
                }
            } else {
                print("CameraManager: Video rotation angle \(angle) not supported on this connection")
            }
            return
        }

        // iOS < 17 fallback using deprecated orientation API (isolated in a legacy helper to avoid deprecation warnings on iOS 17+)
        legacyPerformVideoOrientationUpdate(connection: connection)
    }

    @available(iOS, introduced: 13.0, deprecated: 17.0)
    private func legacyPerformVideoOrientationUpdate(connection: AVCaptureConnection) {
        // Use device orientation instead of interface orientation for more reliable detection
        let deviceOrientation = UIDevice.current.orientation

        // Only update if device orientation is valid
        guard deviceOrientation != .unknown && deviceOrientation != .faceUp && deviceOrientation != .faceDown else {
            print("CameraManager: Skipping orientation update - invalid device orientation: \(orientationString(deviceOrientation))")
            return
        }

        // Convert device orientation to video orientation
        // Note: Landscape orientations are mapped in reverse due to device sensor alignment
        let videoOrientation: AVCaptureVideoOrientation
        switch deviceOrientation {
        case .portrait:
            videoOrientation = .portrait
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        case .landscapeLeft:
            videoOrientation = .landscapeRight  // Reversed!
        case .landscapeRight:
            videoOrientation = .landscapeLeft   // Reversed!
        default:
            videoOrientation = .portrait
        }

        // Only update if orientation actually changed
        if lastVideoOrientation == videoOrientation {
            print("CameraManager: Video orientation unchanged: \(videoOrientationString(videoOrientation))")
            return
        }

        // Debug logging
        print("CameraManager: Device orientation: \(deviceOrientation.rawValue) (\(orientationString(deviceOrientation)))")
        print("CameraManager: Mapped to video orientation: \(videoOrientation.rawValue) (\(videoOrientationString(videoOrientation)))")
        print("CameraManager: Applying video orientation to connection...")

        // Set the video orientation to keep camera image upright
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
            lastVideoOrientation = videoOrientation
            print("CameraManager: Video orientation set successfully")
        } else {
            print("CameraManager: Video orientation not supported on this connection")
        }
    }

    private func orientationString(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait Upside Down"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .faceUp: return "Face Up"
        case .faceDown: return "Face Down"
        default: return "Unknown"
        }
    }

    private func interfaceOrientationString(_ orientation: UIInterfaceOrientation) -> String {
        switch orientation {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait Upside Down"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        default: return "Unknown"
        }
    }

    private func videoOrientationString(_ orientation: AVCaptureVideoOrientation) -> String {
        switch orientation {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait Upside Down"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        }
    }

    // Helper function to get screen bounds using modern API
    private func getScreenBounds() -> CGRect {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.screen.bounds
        } else {
            // Fallback to deprecated API if needed
            return UIScreen.main.bounds
        }
    }

    func saveToPhotoLibrary(imageData: Data) {
        // Check photo library authorization status
        let status = PHPhotoLibrary.authorizationStatus()

        switch status {
        case .authorized, .limited:
            // Save to photo library using PhotoKit
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
            }, completionHandler: { success, error in
                if success {
                    print("CameraManager: Photo saved to photo library using PhotoKit")
                } else {
                    print("CameraManager: Failed to save photo to photo library: \(error?.localizedDescription ?? "Unknown error")")
                }
            })
        case .notDetermined:
            // Request permission
            PHPhotoLibrary.requestAuthorization { [weak self] newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    DispatchQueue.main.async {
                        self?.saveToPhotoLibrary(imageData: imageData)
                    }
                } else {
                    print("CameraManager: Photo library permission denied")
                }
            }
        case .denied, .restricted:
            print("CameraManager: Photo library access denied or restricted")
        @unknown default:
            print("CameraManager: Unknown photo library authorization status")
        }
    }

    // MARK: - LiDAR Initialization

    func initializeLiDARDetection() {
        print("CameraManager: Initializing LiDAR detection...")
        print("CameraManager: - LiDAR available: \(lidarDetector.isLiDARAvailable)")

        // Check if LiDAR is available but don't start it automatically
        if lidarDetector.isLiDARAvailable {
            useLiDARDetection = true
            print("CameraManager: LiDAR detection available (will start on demand)")
            print("CameraManager: - useLiDARDetection set to: \(useLiDARDetection)")
        } else {
            useLiDARDetection = false
            print("CameraManager: LiDAR not available, using traditional detection")
            print("CameraManager: - useLiDARDetection set to: \(useLiDARDetection)")
        }
    }

    // MARK: - Manual LiDAR Control

    func startLiDARDetection() {
        guard lidarDetector.isLiDARAvailable else {
            print("CameraManager: LiDAR not available")
            return
        }

        guard !lidarDetector.isSessionRunning else {
            print("CameraManager: LiDAR session already running")
            return
        }

        // Stop the camera session temporarily to avoid conflicts
        print("CameraManager: Temporarily stopping camera session for LiDAR...")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                print("CameraManager: Camera session stopped for LiDAR")
            }

            // Start LiDAR detection
            DispatchQueue.main.async {
                self.lidarDetector.startLiDARDetection()
                self.useLiDARDetection = true
                self.lastLiDARProcessingState = nil
                print("CameraManager: LiDAR detection started manually")
            }
        }
    }

    func stopLiDARDetection() {
        guard lidarDetector.isSessionRunning else {
            print("CameraManager: LiDAR session already stopped")
            return
        }

        lidarDetector.stopLiDARDetection()
        lastLiDARProcessingState = nil
        print("CameraManager: LiDAR detection stopped")

        restartCaptureSessionIfNeeded()
    }

    func disableLiDARDetection() {
        if lidarDetector.isSessionRunning {
            stopLiDARDetection()
        }
        if useLiDARDetection {
            useLiDARDetection = false
            lastLiDARProcessingState = nil
            print("CameraManager: LiDAR detection disabled - switching to traditional detection")
        }
    }

    func enableLiDARDetection() {
        guard lidarDetector.isLiDARAvailable else {
            print("CameraManager: Cannot enable LiDAR - not available on this device")
            return
        }
        if lidarDetector.isSessionRunning {
            useLiDARDetection = true
            lastLiDARProcessingState = nil
            print("CameraManager: LiDAR detection enabled")
        } else {
            startLiDARDetection()
        }
    }

    // MARK: - Automatic Capture Workflow

    func restartCaptureSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                print("CameraManager: Camera session restarted")

                DispatchQueue.main.async {
                    self.isSessionRunning = self.captureSession.isRunning
                }
            }
        }
    }
}
