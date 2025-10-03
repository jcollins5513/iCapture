//
//  QATestingView+Sections.swift
//  iCapture
//
//  Created by Justin Collins on 10/2/25.
//

import SwiftUI

extension QATestingView {
    var headerSection: some View {
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
        .padding(.top, 24)
    }

    var qaModeSection: some View {
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
    }

    var performanceMetricsSection: some View {
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
    }

    var sessionStatisticsSection: some View {
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
    }

    var systemInformationSection: some View {
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
    }

    var captureTestingSection: some View {
        let photoInfo = cameraManager.getPhotoCaptureInfo()
        return VStack(alignment: .leading, spacing: 16) {
            Text("48MP Capture Testing")
                .font(.headline)

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
    }

    var thermalTestingSection: some View {
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
    }

    var actionButtonsSection: some View {
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
}
