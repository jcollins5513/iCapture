//
//  SessionManager.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class SessionManager: ObservableObject {
    @Published var currentSession: VehicleSession?
    @Published var sessionAssets: [CaptureAsset] = []
    @Published var isSessionActive = false
    @Published var sessionDirectory: URL?

    // Session statistics
    @Published var totalCaptures = 0
    @Published var photoCount = 0
    @Published var videoCount = 0
    @Published var sessionDuration: TimeInterval = 0
    
    // Storage management
    @Published var currentStorageUsage: Int64 = 0
    @Published var maxStorageLimit: Int64 = 60 * 15 * 1024 * 1024 // 60 photos * 15MB = 900MB
    @Published var storageWarningThreshold: Int64 = 80 * 15 * 1024 * 1024 // 80% of limit

    private let fileManager = FileManager.default
    private let documentsPath: URL

    // Timer for session duration updates
    private var sessionTimer: Timer?

    init() {
        self.documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        loadCurrentSession()
    }

    // MARK: - Session Management

    func startSession(stockNumber: String, notes: String? = nil) throws {
        guard !isSessionActive else {
            throw SessionError.sessionAlreadyActive
        }

        // Validate stock number
        guard !stockNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SessionError.invalidStockNumber
        }

        // Create new session
        var session = VehicleSession(stockNumber: stockNumber, notes: notes)

        // Create session directory structure
        let sessionURL = try createSessionDirectory(for: session)

        // Update session with directory info
        self.currentSession = session
        self.sessionDirectory = sessionURL
        self.isSessionActive = true
        self.sessionAssets.removeAll()
        self.totalCaptures = 0
        self.photoCount = 0
        self.videoCount = 0
        self.sessionDuration = 0

        // Start session timer
        startSessionTimer()

        // Save session metadata
        try saveSessionMetadata()
        
        // Cleanup old sessions to manage storage
        try cleanupOldSessions()

        print("SessionManager: Started session for stock \(stockNumber)")
        NotificationCenter.default.post(name: .sessionDidStart, object: self)
    }

    func endSession() throws {
        guard let session = currentSession, isSessionActive else {
            throw SessionError.noActiveSession
        }

        // Stop session timer
        stopSessionTimer()

        // Update session end time
        var updatedSession = session
        updatedSession.endSession()
        self.currentSession = updatedSession

        // Save final session metadata
        try saveSessionMetadata()

        // Create export bundle
        try createExportBundle()

        // Clear current session
        self.isSessionActive = false
        self.sessionDirectory = nil

        print("SessionManager: Ended session for stock \(session.stockNumber). Total captures: \(totalCaptures)")
        NotificationCenter.default.post(name: .sessionDidEnd, object: self)
    }

    func cancelSession() throws {
        guard let session = currentSession, isSessionActive else {
            throw SessionError.noActiveSession
        }

        // Stop session timer
        stopSessionTimer()

        // Remove session directory and all files
        if let sessionURL = sessionDirectory {
            try? fileManager.removeItem(at: sessionURL)
        }

        // Clear current session
        self.currentSession = nil
        self.isSessionActive = false
        self.sessionDirectory = nil
        self.sessionAssets.removeAll()
        self.totalCaptures = 0
        self.photoCount = 0
        self.videoCount = 0
        self.sessionDuration = 0

        print("SessionManager: Cancelled session for stock \(session.stockNumber)")
    }

    // MARK: - Asset Management

    func addAsset(_ asset: CaptureAsset) throws {
        guard isSessionActive, let session = currentSession, let sessionURL = sessionDirectory else {
            throw SessionError.noActiveSession
        }

        // Check if asset file exists using the correct session directory
        let assetFileURL = asset.getFileURL(with: sessionURL)
        guard FileManager.default.fileExists(atPath: assetFileURL.path) else {
            print("SessionManager: Asset file not found at: \(assetFileURL.path)")
            throw SessionError.assetFileNotFound
        }

        // Add asset to collection
        sessionAssets.append(asset)

        // Update statistics
        updateSessionStatistics()

        // Save updated session metadata
        try saveSessionMetadata()

        print("SessionManager: Added \(asset.type.rawValue) asset: \(asset.filename)")
    }

    func removeAsset(_ asset: CaptureAsset) throws {
        // Remove from collection
        sessionAssets.removeAll { $0.id == asset.id }

        // Delete file
        try asset.deleteFile()

        // Update statistics
        updateSessionStatistics()

        // Save updated session metadata
        try saveSessionMetadata()

        print("SessionManager: Removed asset: \(asset.filename)")
    }

    // MARK: - Directory Management

    private func createSessionDirectory(for session: VehicleSession) throws -> URL {
        let capturesPath = documentsPath.appendingPathComponent("Captures")
        let sessionPath = capturesPath.appendingPathComponent(session.stockNumber)

        // Create main session directory
        try fileManager.createDirectory(at: sessionPath, withIntermediateDirectories: true)

        // Create photos subdirectory
        let photosPath = sessionPath.appendingPathComponent("photos")
        try fileManager.createDirectory(at: photosPath, withIntermediateDirectories: true)

        // Create video subdirectory
        let videoPath = sessionPath.appendingPathComponent("video")
        try fileManager.createDirectory(at: videoPath, withIntermediateDirectories: true)

        // Create stickers subdirectory for background-removed assets
        let stickersPath = sessionPath.appendingPathComponent("stickers")
        try fileManager.createDirectory(at: stickersPath, withIntermediateDirectories: true)

        // Create cutouts subdirectory for full-resolution transparent renders
        let cutoutsPath = sessionPath.appendingPathComponent("cutouts")
        try fileManager.createDirectory(at: cutoutsPath, withIntermediateDirectories: true)

        return sessionPath
    }

    private func saveSessionMetadata() throws {
        guard let session = currentSession, let sessionURL = sessionDirectory else {
            throw SessionError.noActiveSession
        }

        let sessionData = SessionJSON(
            session: session,
            assets: sessionAssets,
            createdAt: Date(),
            version: "1.1"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let jsonData = try encoder.encode(sessionData)
        let jsonURL = sessionURL.appendingPathComponent("session.json")
        try jsonData.write(to: jsonURL)
    }

    private func createExportBundle() throws {
        guard let session = currentSession, let sessionURL = sessionDirectory else {
            throw SessionError.noActiveSession
        }

        // Create export bundle directory
        let exportPath = documentsPath.appendingPathComponent("Exports")
        try fileManager.createDirectory(
            at: exportPath,
            withIntermediateDirectories: true
        )

        let exportURL = exportPath.appendingPathComponent(
            "\(session.stockNumber)_\(session.id)"
        )
        
        // Remove existing export directory if it exists
        if fileManager.fileExists(atPath: exportURL.path) {
            try fileManager.removeItem(at: exportURL)
        }
        
        try fileManager.createDirectory(
            at: exportURL,
            withIntermediateDirectories: true
        )

        // Copy session.json
        let sessionJSONURL = sessionURL.appendingPathComponent("session.json")
        let exportSessionJSONURL = exportURL.appendingPathComponent("session.json")
        
        if fileManager.fileExists(atPath: sessionJSONURL.path) {
            try fileManager.copyItem(at: sessionJSONURL, to: exportSessionJSONURL)
        } else {
            print("SessionManager: Warning - session.json not found at \(sessionJSONURL.path)")
        }

        // Copy all assets
        for asset in sessionAssets {
            do {
                try asset.copyToExportDirectory(
                    exportURL: exportURL,
                    sessionDirectory: sessionURL
                )
            } catch {
                print("SessionManager: Failed to copy asset \(asset.filename): \(error)")
                // Continue with other assets even if one fails
            }
        }

        print("SessionManager: Created export bundle at \(exportURL.path)")
    }

    // MARK: - Session Statistics

    @MainActor
    private func updateSessionStatistics() {
        totalCaptures = sessionAssets.count
        photoCount = sessionAssets.filter { $0.type == .photo }.count
        videoCount = sessionAssets.filter { $0.type == .video }.count
    }

    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let session = self.currentSession else { return }
                self.sessionDuration = Date().timeIntervalSince(session.startedAt)
            }
        }
    }

    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    // MARK: - Session Recovery

    private func loadCurrentSession() {
        // Check for existing session in UserDefaults
        if let sessionData = UserDefaults.standard.data(forKey: "currentSession"),
           let session = try? JSONDecoder().decode(VehicleSession.self, from: sessionData) {
            self.currentSession = session
            self.isSessionActive = session.isActive

            if isSessionActive {
                // Try to load session directory
                let sessionURL = documentsPath
                    .appendingPathComponent("Captures")
                    .appendingPathComponent(session.stockNumber)
                if fileManager.fileExists(atPath: sessionURL.path) {
                    self.sessionDirectory = sessionURL
                    loadSessionAssets()
                }
            }
        }
    }

    private func loadSessionAssets() {
        guard let sessionURL = sessionDirectory else { return }

        // Load session.json to get asset list
        let sessionJSONURL = sessionURL.appendingPathComponent("session.json")
        if let data = try? Data(contentsOf: sessionJSONURL),
           let sessionJSON = try? JSONDecoder().decode(SessionJSON.self, from: data) {
            self.sessionAssets = sessionJSON.assets
            updateSessionStatistics()
        }
    }

    // MARK: - Public Getters

    func getSessionSummary() -> String? {
        return currentSession?.sessionSummary
    }

    func getAssetCount() -> Int {
        return sessionAssets.count
    }

    func getPhotosCount() -> Int {
        return photoCount
    }

    func getVideosCount() -> Int {
        return videoCount
    }

    func attachSticker(toOriginalFilename originalFilename: String, stickerFilename: String) {
        guard let index = sessionAssets.firstIndex(where: { asset in
            asset.filename == originalFilename && asset.type == .photo
        }) else {
            return
        }

        sessionAssets[index].stickerFilename = stickerFilename

        do {
            try saveSessionMetadata()
        } catch {
            print("SessionManager: Failed to persist sticker metadata: \(error)")
        }
    }

    func attachCutout(toOriginalFilename originalFilename: String, cutoutFilename: String) {
        guard let index = sessionAssets.firstIndex(where: { asset in
            asset.filename == originalFilename && asset.type == .photo
        }) else {
            return
        }

        sessionAssets[index].cutoutFilename = cutoutFilename

        do {
            try saveSessionMetadata()
        } catch {
            print("SessionManager: Failed to persist cutout metadata: \(error)")
        }
    }

    func getFormattedDuration() -> String {
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Storage Management
    
    func getStorageUsage() -> Int64 {
        guard let sessionURL = sessionDirectory else { return 0 }
        
        var totalSize: Int64 = 0
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: sessionURL, includingPropertiesForKeys: [.fileSizeKey])
            for url in contents {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }
        } catch {
            print("Failed to calculate storage usage: \(error)")
        }
        
        currentStorageUsage = totalSize
        return totalSize
    }
    
    func getFormattedStorageUsage() -> String {
        let usage = getStorageUsage()
        return ByteCountFormatter.string(fromByteCount: usage, countStyle: .file)
    }
    
    func isStorageLimitReached() -> Bool {
        return getStorageUsage() >= maxStorageLimit
    }
    
    func isStorageWarningThresholdReached() -> Bool {
        return getStorageUsage() >= storageWarningThreshold
    }
    
    func cleanupOldSessions() throws {
        let capturesPath = documentsPath.appendingPathComponent("Captures")
        
        guard fileManager.fileExists(atPath: capturesPath.path) else { return }
        
        let contents = try fileManager.contentsOfDirectory(at: capturesPath, includingPropertiesForKeys: [.creationDateKey])
        
        // Sort by creation date (oldest first)
        let sortedContents = contents.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 < date2
        }
        
        // Keep only the 10 most recent sessions
        let sessionsToDelete = sortedContents.dropLast(10)
        
        for sessionURL in sessionsToDelete {
            try fileManager.removeItem(at: sessionURL)
            print("SessionManager: Cleaned up old session: \(sessionURL.lastPathComponent)")
        }
    }
    
    func getStorageStatus() -> String {
        let usage = getStorageUsage()
        let limit = maxStorageLimit
        let percentage = Double(usage) / Double(limit) * 100
        
        let usageString = ByteCountFormatter.string(fromByteCount: usage, countStyle: .file)
        let limitString = ByteCountFormatter.string(fromByteCount: limit, countStyle: .file)
        
        return "Storage: \(usageString) / \(limitString) (\(String(format: "%.1f", percentage))%)"
    }
}

// MARK: - Session JSON Structure
struct SessionJSON: Codable {
    let session: VehicleSession
    let assets: [CaptureAsset]
    let createdAt: Date
    let version: String
}

// MARK: - Session Errors
enum SessionError: LocalizedError {
    case sessionAlreadyActive
    case noActiveSession
    case invalidStockNumber
    case assetFileNotFound
    case directoryCreationFailed
    case fileOperationFailed

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "A session is already active"
        case .noActiveSession:
            return "No active session found"
        case .invalidStockNumber:
            return "Invalid stock number provided"
        case .assetFileNotFound:
            return "Asset file not found"
        case .directoryCreationFailed:
            return "Failed to create session directory"
        case .fileOperationFailed:
            return "File operation failed"
        }
    }
}

extension Notification.Name {
    static let sessionDidStart = Notification.Name("SessionDidStart")
    static let sessionDidEnd = Notification.Name("SessionDidEnd")
}

