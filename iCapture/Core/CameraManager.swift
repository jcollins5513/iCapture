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

    // Video recording manager
    @Published var videoRecordingManager = VideoRecordingManager()

    // ROI Detection, Motion Detection and Trigger Engine
    @Published var roiDetector = ROIDetector()
    @Published var motionDetector = MotionDetector()
    @Published var triggerEngine = TriggerEngine()

    // Session Manager reference (will be set by CameraView)
    weak var sessionManager: SessionManager?

    // Performance monitoring
    @Published var performanceMonitor = PerformanceMonitor()

    override init() {
        super.init()
        checkAuthorization()

        // Configure trigger engine with dependencies
        triggerEngine.configure(cameraManager: self, roiDetector: roiDetector, motionDetector: motionDetector)

        // Configure video recording manager
        videoRecordingManager.configure(sessionManager: sessionManager, roiDetector: roiDetector)
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

            print("CameraManager: Setting up capture session...")
            self.captureSession.beginConfiguration()

            // Configure session preset for high quality
            if self.captureSession.canSetSessionPreset(.photo) {
                self.captureSession.sessionPreset = .photo
                print("CameraManager: Session preset set to photo")
            }

            // Add video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                            for: .video,
                                                            position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.captureSession.canAddInput(videoInput) else {
                print("CameraManager: ERROR - Failed to create video input")
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
                // Configure for high quality photos with 48MP support
                self.configurePhotoOutputForHighResolution()
                print("CameraManager: Photo output added successfully")
            } else {
                print("CameraManager: WARNING - Cannot add photo output")
            }

            // Add movie file output for video recording
            if self.captureSession.canAddOutput(self.videoRecordingManager.getMovieFileOutput()) {
                self.captureSession.addOutput(self.videoRecordingManager.getMovieFileOutput())
                print("CameraManager: Movie file output added successfully")
            } else {
                print("CameraManager: WARNING - Cannot add movie file output")
            }

            self.captureSession.commitConfiguration()
            print("CameraManager: Session configuration committed")

                // Create preview layer on main thread
                DispatchQueue.main.async {
                    self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                    self.previewLayer?.videoGravity = .resizeAspectFill
                    
                    // Set initial frame size
                    let screenBounds = UIScreen.main.bounds
                    self.previewLayer?.frame = screenBounds
                    
                    // Don't configure orientation - let AVFoundation handle it naturally like native camera
                    
                    print("CameraManager: Preview layer created and configured")
                    print("CameraManager: Preview layer session: \(self.previewLayer?.session != nil)")
                    print("CameraManager: Preview layer frame: \(self.previewLayer?.frame ?? .zero)")
                    print("CameraManager: Screen bounds: \(screenBounds)")
                    
                    // Ensure the preview layer is properly connected
                    if let previewLayer = self.previewLayer {
                        print("CameraManager: Preview layer videoGravity: \(previewLayer.videoGravity)")
                        print("CameraManager: Preview layer connection: \(previewLayer.connection != nil)")
                    }
                }
        }
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
        // Record capture start for performance monitoring
        performanceMonitor.recordCaptureStart()

        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }

            let photoSettings: AVCapturePhotoSettings

            // Configure for high quality with 48MP support
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                photoSettings = AVCapturePhotoSettings()
            }
            
            // Enable high resolution capture if supported
        if #available(iOS 16.0, *) {
            if let device = self.captureDevice, 
               let maxDimensions = device.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }),
               maxDimensions.width >= 8000 {
                // Check if the photo output supports this resolution
                if self.photoOutput.maxPhotoDimensions.width >= maxDimensions.width {
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

    // MARK: - Video Recording Methods

    func startVideoRecording() {
        videoRecordingManager.startVideoRecording()
    }

    func stopVideoRecording() {
        videoRecordingManager.stopVideoRecording()
    }

    var isVideoRecording: Bool {
        return videoRecordingManager.isVideoRecording
    }

    var videoRecordingDuration: TimeInterval {
        return videoRecordingManager.videoRecordingDuration
    }

    func getFormattedVideoDuration() -> String {
        return videoRecordingManager.getFormattedVideoDuration()
    }

    // MARK: - High-Resolution Photo Configuration

    private func configurePhotoOutputForHighResolution() {
        // Check if device supports 48MP capture (iPhone 15 Pro and Pro Max)
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        
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
               let maxDimensions = device.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }),
               maxDimensions.width >= 8000 {
                print("CameraManager: 48MP high-resolution capture supported")
            } else {
                print("CameraManager: 48MP capture not available, using standard resolution")
            }
        }
        
        // Set up prepared photo settings for optimal performance
        photoOutput.setPreparedPhotoSettingsArray([photoSettings])
        
        print("CameraManager: Photo output configured for high-resolution capture")
    }
    
    func getMaxPhotoResolution() -> CGSize {
        guard let device = captureDevice else {
            return CGSize(width: 4032, height: 3024) // Default 12MP
        }
        
        // Return the maximum supported resolution
        if #available(iOS 16.0, *), 
           let maxDimensions = device.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }),
           maxDimensions.width >= 8000 {
            return CGSize(width: 8064, height: 6048) // 48MP
        } else {
            return CGSize(width: 4032, height: 3024) // 12MP
        }
    }
    
    func getCurrentPhotoResolution() -> CGSize {
        return getMaxPhotoResolution()
    }
    
    func getPhotoCaptureInfo() -> (resolution: CGSize, format: String, is48MPSupported: Bool) {
        let resolution = getCurrentPhotoResolution()
        let format = photoOutput.availablePhotoCodecTypes.contains(.hevc) ? "HEIF" : "JPEG"
        let is48MPSupported = (resolution.width >= 8000 || resolution.height >= 6000)
        
        return (resolution: resolution, format: format, is48MPSupported: is48MPSupported)
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
            // Record frame for performance monitoring
            performanceMonitor.recordFrame()

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

        // Record capture end for performance monitoring
        Task { @MainActor in
            self.performanceMonitor.recordCaptureEnd()
        }

        // Save photo to appropriate directory
        photoQueue.async { [weak self] in
            guard let self = self else { return }

            guard let imageData = photo.fileDataRepresentation() else {
                print("Failed to get image data")
                return
            }

            // Use manual trigger type since custom metadata is not supported
            let triggerType: TriggerType = .manual

            // Get image dimensions
            let width = photo.resolvedSettings.photoDimensions.width
            let height = photo.resolvedSettings.photoDimensions.height

            // Get ROI rectangle
            let roiRect = self.roiDetector.getROIRect()

            // Create filename with timestamp and resolution info
            let timestamp = Date().timeIntervalSince1970
            let resolutionSuffix = (width >= 8000 || height >= 6000) ? "_48MP" : "_12MP"
            let filename = "photo_\(Int(timestamp))\(resolutionSuffix).heic"
            
            // Log photo capture details and validate file size
            let fileSizeMB = Double(imageData.count) / (1024 * 1024)
            let isHighResolution = (width >= 8000 || height >= 6000)
            let maxSizeMB = isHighResolution ? 15.0 : 5.0
            
            print("CameraManager: Captured photo - Resolution: \(width)x\(height), Size: \(String(format: "%.2f", fileSizeMB))MB")
            
            if fileSizeMB > maxSizeMB {
                print("CameraManager: WARNING - Photo size (\(String(format: "%.2f", fileSizeMB))MB) exceeds target (\(maxSizeMB)MB)")
            } else {
                print("CameraManager: Photo size within target limits")
            }

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
    
    // MARK: - Camera Health Check
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
    
    func restartCameraSession() {
        print("CameraManager: Restarting camera session...")
        stopSession()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.setupCaptureSession()
            self.startSession()
        }
    }
    
    func updatePreviewLayerFrame() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let previewLayer = self.previewLayer else { return }
            
            let screenBounds = UIScreen.main.bounds
            if previewLayer.frame != screenBounds {
                print("CameraManager: Updating preview layer frame from \(previewLayer.frame) to \(screenBounds)")
                previewLayer.frame = screenBounds
            }
        }
    }
    
    func updateVideoOrientation() {
        // Don't update orientation - let AVFoundation handle it naturally like native camera
        print("CameraManager: Letting AVFoundation handle orientation naturally")
    }
}
