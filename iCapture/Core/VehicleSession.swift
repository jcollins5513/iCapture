//
//  VehicleSession.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import Foundation
import UIKit

struct VehicleSession: Codable, Identifiable {
    let id: String
    let stockNumber: String
    let startedAt: Date
    var endedAt: Date?
    let deviceModel: String
    let iosVersion: String
    var notes: String?

    // Computed properties
    var duration: TimeInterval? {
        guard let endedAt = endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    var isActive: Bool {
        return endedAt == nil
    }

    init(stockNumber: String, notes: String? = nil) {
        self.id = UUID().uuidString
        self.stockNumber = stockNumber
        self.startedAt = Date()
        self.endedAt = nil
        self.deviceModel = UIDevice.current.model
        self.iosVersion = UIDevice.current.systemVersion
        self.notes = notes
    }

    mutating func endSession() {
        self.endedAt = Date()
    }

    mutating func updateNotes(_ notes: String) {
        self.notes = notes
    }
}

// MARK: - Session Statistics
extension VehicleSession {
    var sessionSummary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let startTime = formatter.string(from: startedAt)
        let durationText = duration != nil ? formatDuration(duration!) : "Active"

        return "Stock: \(stockNumber) | Started: \(startTime) | Duration: \(durationText)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
