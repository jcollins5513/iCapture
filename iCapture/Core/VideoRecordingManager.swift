//
//  VideoRecordingManager.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

@preconcurrency import AVFoundation
import Combine
import Foundation
import SwiftUI

@MainActor
class VideoRecordingManager: NSObject, ObservableObject {
    @Published var isVideoRecording = false
    @Published var videoRecordingDuration: TimeInterval = 0
    @Published var videoRecordingStartTime: Date?

    private let movieFileOutput = AVCaptureMovieFileOutput()
    private let videoQueue = DispatchQueue(label: "camera.video.queue")
    private var videoRecordingTimer: Timer?

    // Dependencies
    weak var sessionManager: SessionManager?
    weak var roiDetector: ROIDetector?

    override init() {
        super.init()
        setupMovieFileOutput()
    }

    private func setupMovieFileOutput() {
        // Configure video recording settings for 1080p30 H.264
        if let connection = movieFileOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }

            // Set video dimensions to 1080p
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }

        // Configure movie file output settings
        // 5 minutes max duration
        movieFileOutput.maxRecordedDuration = CMTime(seconds: 300, preferredTimescale: 600)
        movieFileOutput.maxRecordedFileSize = 100 * 1024 * 1024 // 100MB max
    }

    func configure(sessionManager: SessionManager?, roiDetector: ROIDetector?) {
        self.sessionManager = sessionManager
        self.roiDetector = roiDetector
    }

    func getMovieFileOutput() -> AVCaptureMovieFileOutput {
        return movieFileOutput
    }

    func startVideoRecording() {
        guard !isVideoRecording,
              let sessionManager = sessionManager,
              sessionManager.isSessionActive else {
            print("Cannot start video recording: already recording or no active session")
            return
        }

        guard let sessionURL = sessionManager.sessionDirectory else {
            print("Cannot start video recording: no session directory")
            return
        }

        videoQueue.async { [weak self] in
            guard let self = self else { return }

            // Create video file URL
            let videoURL = sessionURL
                .appendingPathComponent("video")
                .appendingPathComponent("turn.MOV")

            // Start recording with configured settings
            self.movieFileOutput.startRecording(to: videoURL, recordingDelegate: self)

            DispatchQueue.main.async {
                self.isVideoRecording = true
                self.videoRecordingStartTime = Date()
                self.videoRecordingDuration = 0
                self.startVideoRecordingTimer()
            }

            print("VideoRecordingManager: Started video recording to \(videoURL.path)")
        }
    }

    func stopVideoRecording() {
        guard isVideoRecording else {
            print("Cannot stop video recording: not currently recording")
            return
        }

        videoQueue.async { [weak self] in
            guard let self = self else { return }

            self.movieFileOutput.stopRecording()

            DispatchQueue.main.async {
                self.isVideoRecording = false
                self.stopVideoRecordingTimer()
                self.videoRecordingStartTime = nil
                self.videoRecordingDuration = 0
            }

            print("VideoRecordingManager: Stopped video recording")
        }
    }

    private func startVideoRecordingTimer() {
        videoRecordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.videoRecordingStartTime else { return }
            self.videoRecordingDuration = Date().timeIntervalSince(startTime)
        }
    }

    private func stopVideoRecordingTimer() {
        videoRecordingTimer?.invalidate()
        videoRecordingTimer = nil
    }

    func getFormattedVideoDuration() -> String {
        let minutes = Int(videoRecordingDuration) / 60
        let seconds = Int(videoRecordingDuration) % 60
        let milliseconds = Int((videoRecordingDuration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, milliseconds)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension VideoRecordingManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection],
                                error: Error?) {
        if let error = error {
            print("Error recording video: \(error)")
            return
        }

        print("Video recording completed: \(outputFileURL.path)")

        // Save video to session if active
        videoQueue.async { [weak self] in
            guard let self = self else { return }

            if let sessionManager = self.sessionManager, sessionManager.isSessionActive {
                self.saveVideoToSession(fileURL: outputFileURL)
            }
        }
    }

    private func saveVideoToSession(fileURL: URL) {
        guard let sessionManager = sessionManager,
              let session = sessionManager.currentSession else {
            print("No active session - cannot save video")
            return
        }

        do {
            // Verify the file exists at the expected location
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("Video file not found at: \(fileURL.path)")
                return
            }

            // Get video file attributes
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            _ = attributes[.size] as? Int64 ?? 0

            // Create video asset with correct file path
            let asset = CaptureAsset(
                sessionId: session.id,
                type: .video,
                filename: fileURL.lastPathComponent, // Use actual filename
                width: 1920, // 1080p width
                height: 1080, // 1080p height
                roiRect: roiDetector?.getROIRect() ?? CGRect.zero,
                triggerType: .manual
            )

            // Add asset to session
            try sessionManager.addAsset(asset)

            print("Video saved to session: \(fileURL.lastPathComponent)")

        } catch {
            print("Failed to save video to session: \(error)")
        }
    }
}
