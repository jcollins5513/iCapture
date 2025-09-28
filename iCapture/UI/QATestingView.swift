//
//  QATestingView.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI

struct QATestingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var performanceMonitor = PerformanceMonitor()
    @StateObject private var cameraManager = CameraManager()
    @State private var showingPerformanceReport = false
    @State private var performanceReport = ""
    @State private var isQAModeActive = false
    @State private var photoCaptureResults: [PhotoCaptureResult] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("QA Testing Tools")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Performance monitoring and testing tools for device validation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // QA Mode Toggle
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("QA Testing Mode")
                            .font(.headline)

                        Spacer()

                        Toggle("", isOn: $isQAModeActive)
                            .onChange(of: isQAModeActive) { _, isActive in
                                if isActive {
                                    performanceMonitor.startQAMode()
                                } else {
                                    performanceMonitor.stopQAMode()
                                }
                            }
                    }
                    
                    // Camera Debug Toggle
                    HStack {
                        Text("Camera Debug Mode")
                            .font(.headline)
                        
                        Spacer()
                        
                        Toggle("", isOn: $cameraManager.cameraDebugger.isDebugMode)
                            .onChange(of: cameraManager.cameraDebugger.isDebugMode) { _, isActive in
                                if isActive {
                                    cameraManager.cameraDebugger.startDebugging(cameraManager: cameraManager)
                                } else {
                                    cameraManager.cameraDebugger.stopDebugging()
                                }
                            }
                    }
                    
                    Text(isQAModeActive ?
                         "QA mode is active. Performance metrics are being recorded." :
                         "Enable QA mode to start recording performance metrics for testing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                // Performance Metrics
                VStack(alignment: .leading, spacing: 16) {
                    Text("Performance Metrics")
                        .font(.headline)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        MetricCard(
                            title: "Memory Usage",
                            value: String(format: "%.1f MB", performanceMonitor.memoryUsage),
                            color: performanceMonitor.memoryUsage > 500 ? .red : .green
                        )

                        MetricCard(
                            title: "CPU Usage",
                            value: String(format: "%.1f%%", performanceMonitor.cpuUsage),
                            color: performanceMonitor.cpuUsage > 80 ? .red : .green
                        )

                        MetricCard(
                            title: "Capture Latency",
                            value: String(format: "%.3f s", performanceMonitor.captureLatency),
                            color: performanceMonitor.captureLatency > 1.0 ? .red : .green
                        )

                        MetricCard(
                            title: "Frame Rate",
                            value: String(format: "%.1f fps", performanceMonitor.frameRate),
                            color: performanceMonitor.frameRate < 20 ? .red : .green
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                // Session Statistics
                VStack(alignment: .leading, spacing: 16) {
                    Text("Session Statistics")
                        .font(.headline)

                    VStack(spacing: 8) {
                        HStack {
                            Text("Total Captures:")
                            Spacer()
                            Text("\(performanceMonitor.totalCaptures)")
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Average Latency:")
                            Spacer()
                            Text(String(format: "%.3f s", performanceMonitor.averageCaptureLatency))
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Peak Memory:")
                            Spacer()
                            Text(String(format: "%.1f MB", performanceMonitor.peakMemoryUsage))
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Session Duration:")
                            Spacer()
                            Text(String(format: "%.1f s", performanceMonitor.sessionDuration))
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Crashes Detected:")
                            Spacer()
                            Text("\(performanceMonitor.crashesDetected)")
                                .fontWeight(.semibold)
                                .foregroundColor(performanceMonitor.crashesDetected > 0 ? .red : .green)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                // System Information
                VStack(alignment: .leading, spacing: 16) {
                    Text("System Information")
                        .font(.headline)

                    VStack(spacing: 8) {
                        HStack {
                            Text("Thermal State:")
                            Spacer()
                            Text(thermalStateDescription)
                                .fontWeight(.semibold)
                                .foregroundColor(thermalStateColor)
                        }

                        HStack {
                            Text("Battery Level:")
                            Spacer()
                            Text(String(format: "%.1f%%", performanceMonitor.batteryLevel * 100))
                                .fontWeight(.semibold)
                                .foregroundColor(batteryColor)
                        }

                        HStack {
                            Text("Low Power Mode:")
                            Spacer()
                            Text(performanceMonitor.isLowPowerMode ? "Yes" : "No")
                                .fontWeight(.semibold)
                                .foregroundColor(performanceMonitor.isLowPowerMode ? .orange : .green)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Spacer()

                // 48MP Capture Testing
                VStack(alignment: .leading, spacing: 16) {
                    Text("48MP Capture Testing")
                        .font(.headline)

                    let photoInfo = cameraManager.getPhotoCaptureInfo()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Settings:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Resolution: \(Int(photoInfo.resolution.width)) × \(Int(photoInfo.resolution.height))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Format: \(photoInfo.format)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("48MP Supported: \(photoInfo.is48MPSupported ? "Yes" : "No")")
                            .font(.caption)
                            .foregroundColor(photoInfo.is48MPSupported ? .green : .orange)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                    Button("Test 48MP Capture") {
                        test48MPCapture()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(!photoInfo.is48MPSupported)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                // Thermal Testing
                VStack(alignment: .leading, spacing: 16) {
                    Text("Thermal Testing")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Thermal State: \(thermalStateDescription)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(thermalStateColor)
                        
                        if performanceMonitor.isThermalThrottling {
                            Text("⚠️ Thermal Throttling Active")
                                .font(.caption)
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                        }
                        
                        Text("Thermal Events: \(performanceMonitor.thermalEvents.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)

                    Button("Start Thermal Stress Test") {
                        performanceMonitor.startThermalStressTest()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(performanceMonitor.isThermalThrottling)

                    Button("View Thermal Events") {
                        showThermalEvents()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                // Action Buttons
                VStack(spacing: 12) {
                    Button("Generate Performance Report") {
                        performanceReport = performanceMonitor.getPerformanceReport()
                        showingPerformanceReport = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                    Button("Export QA Metrics") {
                        exportQAMetrics()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .navigationTitle("QA Testing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPerformanceReport) {
            PerformanceReportView(report: performanceReport)
        }
    }

    // MARK: - Computed Properties

    private var thermalStateDescription: String {
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

    private var thermalStateColor: Color {
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

    private var batteryColor: Color {
        if performanceMonitor.batteryLevel < 0.2 {
            return .red
        } else if performanceMonitor.batteryLevel < 0.5 {
            return .orange
        } else {
            return .green
        }
    }

    // MARK: - Actions

    private func exportQAMetrics() {
        guard let jsonString = performanceMonitor.qaMetrics.exportToJSON() else {
            print("Failed to export QA metrics")
            return
        }

        // In a real implementation, you would save this to a file
        // or share it via the system share sheet
        print("QA Metrics JSON:")
        print(jsonString)

        // For now, we'll just show an alert
        // In a real app, you'd implement proper file sharing
    }
    
    private func test48MPCapture() {
        let photoInfo = cameraManager.getPhotoCaptureInfo()
        let startTime = Date()
        
        // Capture test photo
        cameraManager.captureTestShot()
        
        // Record test result
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
    
    private func showThermalEvents() {
        let thermalSummary = performanceMonitor.getThermalEventSummary()
        print("QA Testing: Thermal Events Summary")
        print(thermalSummary)
    }
    
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

struct PerformanceReportView: View {
    let report: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                Text(report)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Performance Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Photo Capture Result
struct PhotoCaptureResult {
    let timestamp: Date
    let resolution: CGSize
    let format: String
    let is48MP: Bool
    let captureLatency: TimeInterval
    
    var description: String {
        let resolutionText = is48MP ? "48MP" : "12MP"
        return "\(resolutionText) \(format) - \(Int(resolution.width))×\(Int(resolution.height)) - \(String(format: "%.3f", captureLatency))s"
    }
}

#Preview {
    QATestingView()
}
