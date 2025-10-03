//
//  QATestingView.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI

struct QATestingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var performanceMonitor = PerformanceMonitor()
    @StateObject var cameraManager = CameraManager()
    @State var showingPerformanceReport = false
    @State var performanceReport = ""
    @State var isQAModeActive = false
    @State var photoCaptureResults: [PhotoCaptureResult] = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    qaModeSection
                    performanceMetricsSection
                    sessionStatisticsSection
                    systemInformationSection
                    captureTestingSection
                    thermalTestingSection
                    actionButtonsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
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
}

#Preview {
    QATestingView()
}
