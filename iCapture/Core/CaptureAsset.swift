//
//  CaptureAsset.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import Foundation
import UIKit

enum AssetType: String, Codable, CaseIterable {
    case photo
    case video
}

enum TriggerType: String, Codable, CaseIterable {
    case interval
    case stop
    case manual
}

struct CaptureAsset: Codable, Identifiable {
    let id: String
    let sessionId: String
    let type: AssetType
    let filename: String
    let createdAt: Date
    let width: Int
    let height: Int
    let roiRect: CGRect
    let triggerType: TriggerType
    let exposureISO: Double?
    let exposureDuration: Double?
    let focusDistance: Double?
    var stickerFilename: String?
    var cutoutFilename: String?

    // File system properties
    var fileURL: URL {
        // Use the session directory from SessionManager
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sessionPath = documentsPath.appendingPathComponent("Captures")
            .appendingPathComponent(sessionId)
        let subdirectory = type == .photo ? "photos" : "video"
        return sessionPath.appendingPathComponent(subdirectory)
            .appendingPathComponent(filename)
    }

    // Helper method to get file URL with actual session directory
    func getFileURL(with sessionDirectory: URL) -> URL {
        let subdirectory = type == .photo ? "photos" : "video"
        return sessionDirectory.appendingPathComponent(subdirectory)
            .appendingPathComponent(filename)
    }

    func getStickerURL(with sessionDirectory: URL) -> URL? {
        guard let stickerFilename = stickerFilename else { return nil }
        return sessionDirectory
            .appendingPathComponent("stickers")
            .appendingPathComponent(stickerFilename)
    }

    func getCutoutURL(with sessionDirectory: URL) -> URL? {
        guard let cutoutFilename = cutoutFilename else { return nil }
        return sessionDirectory
            .appendingPathComponent("cutouts")
            .appendingPathComponent(cutoutFilename)
    }

    var fileSize: Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    // Helper method to check if file exists with specific session directory
    func fileExists(with sessionDirectory: URL) -> Bool {
        let assetFileURL = getFileURL(with: sessionDirectory)
        return FileManager.default.fileExists(atPath: assetFileURL.path)
    }

    init(sessionId: String, type: AssetType, filename: String, width: Int, height: Int,
         roiRect: CGRect, triggerType: TriggerType, exposureISO: Double? = nil,
         exposureDuration: Double? = nil, focusDistance: Double? = nil,
         stickerFilename: String? = nil, cutoutFilename: String? = nil) {
        self.id = UUID().uuidString
        self.sessionId = sessionId
        self.type = type
        self.filename = filename
        self.createdAt = Date()
        self.width = width
        self.height = height
        self.roiRect = roiRect
        self.triggerType = triggerType
        self.exposureISO = exposureISO
        self.exposureDuration = exposureDuration
        self.focusDistance = focusDistance
        self.stickerFilename = stickerFilename
        self.cutoutFilename = cutoutFilename
    }

    // MARK: - File Operations

    func deleteFile() throws {
        if fileExists {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    func copyToExportDirectory(exportURL: URL, sessionDirectory: URL) throws {
        let destinationURL = exportURL.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: fileURL, to: destinationURL)

        if type == .photo {
            if let stickerFilename = stickerFilename,
               let stickerSourceURL = getStickerURL(with: sessionDirectory),
               FileManager.default.fileExists(atPath: stickerSourceURL.path) {
                let stickerDestination = exportURL.appendingPathComponent(stickerFilename)
                if FileManager.default.fileExists(atPath: stickerDestination.path) {
                    try FileManager.default.removeItem(at: stickerDestination)
                }
                try FileManager.default.copyItem(at: stickerSourceURL, to: stickerDestination)
            }

            if let cutoutFilename = cutoutFilename,
               let cutoutSourceURL = getCutoutURL(with: sessionDirectory),
               FileManager.default.fileExists(atPath: cutoutSourceURL.path) {
                let cutoutDestination = exportURL.appendingPathComponent(cutoutFilename)
                if FileManager.default.fileExists(atPath: cutoutDestination.path) {
                    try FileManager.default.removeItem(at: cutoutDestination)
                }
                try FileManager.default.copyItem(at: cutoutSourceURL, to: cutoutDestination)
            }
        }
    }
}

// MARK: - Asset Statistics
extension CaptureAsset {
    var formattedFileSize: String {
        guard let size = fileSize else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDimensions: String {
        "\(width) × \(height)"
    }

    var assetSummary: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return [
            type.rawValue.capitalized,
            formatter.string(from: createdAt),
            formattedFileSize,
            triggerType.rawValue.capitalized
        ].joined(separator: " | ")
    }
}

// MARK: - ROI Rectangle Codable Support
// Note: CGRect already conforms to Codable in iOS 26, so no custom extension needed
