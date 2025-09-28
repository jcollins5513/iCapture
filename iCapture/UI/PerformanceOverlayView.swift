//
//  PerformanceOverlayView.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI

struct PerformanceOverlayView: View {
    @ObservedObject var performanceMonitor: PerformanceMonitor
    @State private var isExpanded = false

    var body: some View {
        VStack {
            HStack {
                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    // Compact view when collapsed
                    if !isExpanded {
                        HStack(spacing: 16) {
                            PerformanceMetric(
                                title: "Mem",
                                value: String(format: "%.0fMB", performanceMonitor.memoryUsage),
                                color: performanceMonitor.memoryUsage > 500 ? .red : .green
                            )

                            PerformanceMetric(
                                title: "CPU",
                                value: String(format: "%.0f%%", performanceMonitor.cpuUsage),
                                color: performanceMonitor.cpuUsage > 80 ? .red : .green
                            )

                            PerformanceMetric(
                                title: "FPS",
                                value: String(format: "%.0f", performanceMonitor.frameRate),
                                color: performanceMonitor.frameRate < 20 ? .red : .green
                            )

                            PerformanceMetric(
                                title: "Lat",
                                value: String(format: "%.3fs", performanceMonitor.captureLatency),
                                color: performanceMonitor.captureLatency > 1.0 ? .red : .green
                            )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    } else {
                        // Expanded view
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Performance Monitor")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Memory: \(String(format: "%.1f", performanceMonitor.memoryUsage))MB")
                                        .font(.caption2)
                                        .foregroundColor(performanceMonitor.memoryUsage > 500 ? .red : .green)

                                    Text("CPU: \(String(format: "%.1f", performanceMonitor.cpuUsage))%")
                                        .font(.caption2)
                                        .foregroundColor(performanceMonitor.cpuUsage > 80 ? .red : .green)

                                    Text("FPS: \(String(format: "%.1f", performanceMonitor.frameRate))")
                                        .font(.caption2)
                                        .foregroundColor(performanceMonitor.frameRate < 20 ? .red : .green)
                                }

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Latency: \(String(format: "%.3f", performanceMonitor.captureLatency))s")
                                        .font(.caption2)
                                        .foregroundColor(performanceMonitor.captureLatency > 1.0 ? .red : .green)

                                    Text("Captures: \(performanceMonitor.totalCaptures)")
                                        .font(.caption2)
                                        .foregroundColor(.white)

                                    Text("Peak: \(String(format: "%.1f", performanceMonitor.peakMemoryUsage))MB")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                }
                            }

                            // System info
                            HStack(spacing: 12) {
                                Text("Thermal: \(thermalStateText)")
                                    .font(.caption2)
                                    .foregroundColor(thermalStateColor)

                                Text("Battery: \(String(format: "%.0f", performanceMonitor.batteryLevel * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(batteryColor)

                                if performanceMonitor.isLowPowerMode {
                                    Text("LPM")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                    }

                    // Toggle button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }, label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    })
                }
                .padding()
            }

            Spacer()
        }
    }

    // MARK: - Computed Properties

    private var thermalStateText: String {
        switch performanceMonitor.thermalState {
        case .nominal:
            return "Nom"
        case .fair:
            return "Fair"
        case .serious:
            return "Ser"
        case .critical:
            return "Crit"
        @unknown default:
            return "?"
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
}

struct PerformanceMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

#Preview {
    PerformanceOverlayView(performanceMonitor: PerformanceMonitor())
        .background(Color.black)
}
