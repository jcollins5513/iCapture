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

    // File system properties
    var fileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sessionPath = documentsPath.appendingPathComponent("Captures")
            .appendingPathComponent(sessionId)
        let subdirectory = type == .photo ? "photos" : "video"
        return sessionPath.appendingPathComponent(subdirectory)
            .appendingPathComponent(filename)
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
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    init(sessionId: String, type: AssetType, filename: String, width: Int, height: Int,
         roiRect: CGRect, triggerType: TriggerType, exposureISO: Double? = nil,
         exposureDuration: Double? = nil, focusDistance: Double? = nil) {
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
    }

    // MARK: - File Operations

    func deleteFile() throws {
        if fileExists {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    func copyToExportDirectory(exportURL: URL) throws {
        let destinationURL = exportURL.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: fileURL, to: destinationURL)
    }
}

// MARK: - Asset Statistics
extension CaptureAsset {
    var formattedFileSize: String {
        guard let size = fileSize else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDimensions: String {
        return "\(width) × \(height)"
    }

    var assetSummary: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium

        let timeString = formatter.string(from: createdAt)
        let sizeString = formattedFileSize

        return "\(type.rawValue.capitalized) | \(timeString) | \(sizeString) | \(triggerType.rawValue.capitalized)"
    }
}

// MARK: - ROI Rectangle Codable Support
extension CGRect: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let xCoordinate = try container.decode(CGFloat.self, forKey: .xCoordinate)
        let yCoordinate = try container.decode(CGFloat.self, forKey: .yCoordinate)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(x: xCoordinate, y: yCoordinate, width: width, height: height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin.x, forKey: .xCoordinate)
        try container.encode(origin.y, forKey: .yCoordinate)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
    }

    private enum CodingKeys: String, CodingKey {
        case xCoordinate
        case yCoordinate
        case width
        case height
    }
}
