//
//  PerformanceReportView.swift
//  iCapture
//
//  Created by Justin Collins on 10/2/25.
//

import SwiftUI

struct PerformanceReportView: View {
    let report: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                Text(report)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
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

#Preview {
    PerformanceReportView(
        report: """
        Sample report contents...
        Line 2
        Line 3
        """
    )
}
