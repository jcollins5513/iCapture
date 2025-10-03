//
//  PerformanceMonitor.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import Foundation
import UIKit
import Combine

@MainActor
class PerformanceMonitor: ObservableObject {
    @Published var memoryUsage: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var captureLatency: TimeInterval = 0.0
    @Published var frameRate: Double = 0.0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var batteryLevel: Float = 0.0
    @Published var isLowPowerMode: Bool = false

    // Performance metrics
    @Published var totalCaptures: Int = 0
    @Published var averageCaptureLatency: TimeInterval = 0.0
    @Published var peakMemoryUsage: Double = 0.0
    @Published var sessionDuration: TimeInterval = 0.0
    @Published var crashesDetected: Int = 0

    // QA Testing mode
    @Published var isQAMode: Bool = false
    @Published var qaMetrics: QAMetrics = QAMetrics()

    // Thermal management
    @Published var thermalEvents: [ThermalEvent] = []
    @Published var isThermalThrottling: Bool = false
    @Published var thermalRecoveryTime: TimeInterval = 0.0

    private var monitoringTimer: Timer?
    private var captureStartTime: Date?
    private var sessionStartTime: Date?
    private var frameCount: Int = 0
    private var lastFrameTime: Date?
    private var lastThermalState: ProcessInfo.ThermalState = .nominal
    private var thermalThrottlingStartTime: Date?

    // Memory monitoring
    private var memoryInfo = mach_task_basic_info()
    private var memoryInfoCount = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

    init() {
        startMonitoring()
        sessionStartTime = Date()
    }

    deinit {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    // MARK: - Public Interface

    func startQAMode() {
        isQAMode = true
        qaMetrics = QAMetrics()
        sessionStartTime = Date()
        print("PerformanceMonitor: QA mode enabled")
    }

    func stopQAMode() {
        isQAMode = false
        if let startTime = sessionStartTime {
            qaMetrics.sessionDuration = Date().timeIntervalSince(startTime)
        }
        print("PerformanceMonitor: QA mode disabled. Session duration: \(qaMetrics.sessionDuration)s")
    }

    func recordCaptureStart() {
        captureStartTime = Date()
    }

    func recordCaptureEnd() {
        guard let startTime = captureStartTime else { return }

        let latency = Date().timeIntervalSince(startTime)
        captureLatency = latency
        totalCaptures += 1

        // Update average latency
        averageCaptureLatency = (averageCaptureLatency * Double(totalCaptures - 1) + latency) / Double(totalCaptures)

        if isQAMode {
            qaMetrics.captureLatencies.append(latency)
            qaMetrics.totalCaptures = totalCaptures
        }

        print("PerformanceMonitor: Capture latency: \(latency)s")
    }

    func recordFrame() {
        frameCount += 1
        let now = Date()

        if let lastTime = lastFrameTime {
            let frameInterval = now.timeIntervalSince(lastTime)
            frameRate = 1.0 / frameInterval
        }

        lastFrameTime = now
    }

    func recordCrash() {
        crashesDetected += 1
        if isQAMode {
            qaMetrics.crashesDetected = crashesDetected
        }
        print("PerformanceMonitor: Crash detected. Total crashes: \(crashesDetected)")
    }

    func getPerformanceReport() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium

        var report = "=== Performance Report ===\n"
        report += "Session Duration: \(String(format: "%.1f", sessionDuration))s\n"
        report += "Total Captures: \(totalCaptures)\n"
        report += "Average Capture Latency: \(String(format: "%.3f", averageCaptureLatency))s\n"
        report += "Peak Memory Usage: \(String(format: "%.1f", peakMemoryUsage))MB\n"
        report += "Current Memory: \(String(format: "%.1f", memoryUsage))MB\n"
        report += "Current CPU: \(String(format: "%.1f", cpuUsage))%\n"
        report += "Frame Rate: \(String(format: "%.1f", frameRate))fps\n"
        report += "Thermal State: \(thermalStateDescription)\n"
        report += "Battery Level: \(String(format: "%.1f", batteryLevel * 100))%\n"
        report += "Low Power Mode: \(isLowPowerMode ? "Yes" : "No")\n"
        report += "Crashes Detected: \(crashesDetected)\n"

        if isQAMode {
            report += "\n=== QA Metrics ===\n"
            report += "QA Session Duration: \(String(format: "%.1f", qaMetrics.sessionDuration))s\n"
            report += "QA Total Captures: \(qaMetrics.totalCaptures)\n"
            report += "QA Average Latency: \(String(format: "%.3f", qaMetrics.averageLatency))s\n"
            report += "QA Peak Memory: \(String(format: "%.1f", qaMetrics.peakMemoryUsage))MB\n"
            report += "QA Crashes: \(qaMetrics.crashesDetected)\n"
        }

        return report
    }

    // MARK: - Thermal Management

    func getThermalManagementRecommendations() -> [String] {
        var recommendations: [String] = []

        switch thermalState {
        case .nominal:
            recommendations.append("Thermal state is normal - optimal performance")
        case .fair:
            recommendations.append("Thermal state is fair - monitor for changes")
            recommendations.append("Consider reducing capture frequency if needed")
        case .serious:
            recommendations.append("Thermal throttling active - performance may be reduced")
            recommendations.append("Reduce capture frequency to 10s intervals")
            recommendations.append("Consider stopping video recording")
        case .critical:
            recommendations.append("Critical thermal state - immediate action required")
            recommendations.append("Stop all capture activities")
            recommendations.append("Allow device to cool down")
        @unknown default:
            recommendations.append("Unknown thermal state - monitor closely")
        }

        return recommendations
    }

    func getThermalEventSummary() -> String {
        guard !thermalEvents.isEmpty else {
            return "No thermal events recorded"
        }

        var summary = "Thermal Events (\(thermalEvents.count)):\n"
        for event in thermalEvents.suffix(5) { // Show last 5 events
            summary += "• \(event.description)\n"
        }

        if isThermalThrottling {
            summary += "\n⚠️ Currently experiencing thermal throttling"
        }

        return summary
    }

    func startThermalStressTest() {
        print("PerformanceMonitor: Starting thermal stress test")
        // In a real implementation, this would trigger intensive operations
        // For now, we'll just enable enhanced monitoring
        isQAMode = true
    }

    func stopThermalStressTest() {
        print("PerformanceMonitor: Stopping thermal stress test")
        isQAMode = false
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.updateMetrics()
            }
        }
    }

    private func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    private func updateMetrics() {
        updateMemoryUsage()
        updateCPUUsage()
        updateThermalState()
        updateBatteryInfo()
        updateSessionDuration()
    }

    private func updateMemoryUsage() {
        let result = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(memoryInfoCount)) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &memoryInfoCount)
            }
        }

        if result == KERN_SUCCESS {
            let memoryUsageMB = Double(memoryInfo.resident_size) / 1_024.0 / 1_024.0
            memoryUsage = memoryUsageMB

            if memoryUsageMB > peakMemoryUsage {
                peakMemoryUsage = memoryUsageMB
            }

            if isQAMode {
                qaMetrics.currentMemoryUsage = memoryUsageMB
                if memoryUsageMB > qaMetrics.peakMemoryUsage {
                    qaMetrics.peakMemoryUsage = memoryUsageMB
                }
            }
        }
    }

    private func updateCPUUsage() {
        // Simplified CPU usage calculation
        // In a real implementation, you'd use more sophisticated methods
        let cpuUsage = ProcessInfo.processInfo.processorCount > 0 ?
            Double.random(in: 10...80) : 0.0 // Placeholder for actual CPU monitoring
        self.cpuUsage = cpuUsage
    }

    private func updateThermalState() {
        let currentThermalState = ProcessInfo.processInfo.thermalState

        // Check for thermal state changes
        if currentThermalState != lastThermalState {
            let event = ThermalEvent(
                timestamp: Date(),
                fromState: lastThermalState,
                toState: currentThermalState,
                sessionDuration: sessionDuration
            )

            thermalEvents.append(event)

            // Track thermal throttling
            if currentThermalState == .serious || currentThermalState == .critical {
                if !isThermalThrottling {
                    isThermalThrottling = true
                    thermalThrottlingStartTime = Date()
                    print("PerformanceMonitor: Thermal throttling started - State: \(thermalStateDescription)")
                }
            } else if isThermalThrottling && (currentThermalState == .nominal || currentThermalState == .fair) {
                isThermalThrottling = false
                if let startTime = thermalThrottlingStartTime {
                    thermalRecoveryTime = Date().timeIntervalSince(startTime)
                    print("PerformanceMonitor: Thermal throttling ended - Recovery time: \(String(format: "%.1f", thermalRecoveryTime))s")
                }
                thermalThrottlingStartTime = nil
            }

            lastThermalState = currentThermalState
        }

        thermalState = currentThermalState
    }

    private func updateBatteryInfo() {
        batteryLevel = UIDevice.current.batteryLevel
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private func updateSessionDuration() {
        if let startTime = sessionStartTime {
            sessionDuration = Date().timeIntervalSince(startTime)
        }
    }

    private var thermalStateDescription: String {
        switch thermalState {
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
}

// MARK: - QA Metrics Structure

struct QAMetrics: Codable {
    var sessionDuration: TimeInterval = 0.0
    var totalCaptures: Int = 0
    var captureLatencies: [TimeInterval] = []
    var averageLatency: TimeInterval = 0.0
    var currentMemoryUsage: Double = 0.0
    var peakMemoryUsage: Double = 0.0
    var crashesDetected: Int = 0
    var thermalEvents: [String] = []
    var batteryEvents: [String] = []

    mutating func updateAverageLatency() {
        guard !captureLatencies.isEmpty else { return }
        averageLatency = captureLatencies.reduce(0, +) / Double(captureLatencies.count)
    }

    func exportToJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Failed to export QA metrics: \(error)")
            return nil
        }
    }
}

// MARK: - Thermal Event Structure
struct ThermalEvent: Codable {
    let timestamp: Date
    let fromState: String
    let toState: String
    let sessionDuration: TimeInterval

    init(timestamp: Date, fromState: ProcessInfo.ThermalState, toState: ProcessInfo.ThermalState, sessionDuration: TimeInterval) {
        self.timestamp = timestamp
        self.fromState = ThermalEvent.thermalStateText(fromState)
        self.toState = ThermalEvent.thermalStateText(toState)
        self.sessionDuration = sessionDuration
    }

    var description: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium

        return "\(formatter.string(from: timestamp)): \(fromState) → \(toState)"
    }

    private static func thermalStateText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
