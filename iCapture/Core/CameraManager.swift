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
    
    // Debug tools
    @Published var cameraDebugger = CameraDebugger()
    
    // Orientation handling
    private var lastVideoOrientation: AVCaptureVideoOrientation?
    private var orientationUpdateTimer: Timer?

    override init() {
        super.init()
        checkAuthorization()

        // Configure trigger engine with dependencies
        triggerEngine.configure(cameraManager: self, roiDetector: roiDetector, motionDetector: motionDetector)

        // Configure video recording manager
        videoRecordingManager.configure(sessionManager: sessionManager, roiDetector: roiDetector)
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

                // Create preview layer immediately (not async) to avoid timing issues
            self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            self.previewLayer?.videoGravity = .resizeAspectFill
            
            print("CameraManager: Preview layer created and configured")
            print("CameraManager: Preview layer session: \(self.previewLayer?.session != nil)")
            
            // Ensure the preview layer is properly connected
            if let previewLayer = self.previewLayer {
                print("CameraManager: Preview layer videoGravity: \(previewLayer.videoGravity)")
                print("CameraManager: Preview layer connection: \(previewLayer.connection != nil)")
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
    
    @MainActor
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
    
    @MainActor
    func getCurrentPhotoResolution() -> CGSize {
        return getMaxPhotoResolution()
    }
    
    @MainActor
    func getPhotoCaptureInfo() -> (resolution: CGSize, format: String, is48MPSupported: Bool) {
        let resolution = getCurrentPhotoResolution()
        let format = photoOutput.availablePhotoCodecTypes.contains(.hevc) ? "HEIF" : "JPEG"
        let is48MPSupported = (resolution.width >= 8000 || resolution.height >= 6000)
        
        return (resolution: resolution, format: format, is48MPSupported: is48MPSupported)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Process frame for ROI detection
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        DispatchQueue.main.async {
            // Record frame for performance monitoring
            self.performanceMonitor.recordFrame()

            self.roiDetector.processFrame(pixelBuffer)
            self.motionDetector.processFrame(pixelBuffer)
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
        DispatchQueue.main.async {
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

            // Get ROI rectangle - we'll get this on the main thread
            let roiRect = DispatchQueue.main.sync {
                return self.roiDetector.getROIRect()
            }

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
            let isSessionActive = DispatchQueue.main.sync {
                return self.sessionManager?.isSessionActive ?? false
            }
            
            if isSessionActive {
                let params = PhotoSessionParams(
                    imageData: imageData,
                    filename: filename,
                    width: Int(width),
                    height: Int(height),
                    roiRect: roiRect,
                    triggerType: triggerType
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
}
