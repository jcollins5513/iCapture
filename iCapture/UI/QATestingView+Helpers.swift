//
//  QATestingView+Helpers.swift
//  iCapture
//
//  Created by Justin Collins on 10/2/25.
//

import SwiftUI

@MainActor
extension QATestingView {
    var thermalStateDescription: String {
        switch performanceMonitor.thermalState {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }

    var thermalStateColor: Color {
        switch performanceMonitor.thermalState {
        case .nominal:
            return .green
        case .fair:
            return .yellow
        case .serious:
            return .orange
        case .critical:
            return .red
        @unknown default:
            return .gray
        }
    }

    var batteryColor: Color {
        switch performanceMonitor.batteryLevel {
        case ..<0.2:
            return .red
        case ..<0.5:
            return .orange
        default:
            return .green
        }
    }

    func exportQAMetrics() {
        guard let jsonString = performanceMonitor.qaMetrics.exportToJSON() else {
            print("Failed to export QA metrics")
            return
        }

        print("QA Metrics JSON:")
        print(jsonString)
    }

    func test48MPCapture() {
        let photoInfo = cameraManager.getPhotoCaptureInfo()
        let startTime = Date()

        cameraManager.captureTestShot()

        let result = PhotoCaptureResult(
            timestamp: startTime,
            resolution: photoInfo.resolution,
            format: photoInfo.format,
            is48MP: photoInfo.is48MPSupported,
            captureLatency: performanceMonitor.captureLatency
        )

        photoCaptureResults.append(result)
        print("QA Testing: 48MP capture test completed - \(result)")
    }

    func showThermalEvents() {
        let thermalSummary = performanceMonitor.getThermalEventSummary()
        print("QA Testing: Thermal Events Summary")
        print(thermalSummary)
    }
}
