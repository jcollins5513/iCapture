//
//  CameraDebugView.swift
//  iCapture
//
//  Created by Justin Collins on 9/28/25.
//

import SwiftUI

struct CameraDebugView: View {
    @ObservedObject var cameraDebugger: CameraDebugger
    @State private var isExpanded = false
    @State private var showExportSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Debug Header
            HStack {
                Image(systemName: "ladybug.fill")
                    .foregroundColor(.red)

                Text("Camera Debug")
                    .font(.headline)
                    .foregroundColor(.red)

                Spacer()

                Button(
                    action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    },
                    label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.red)
                    }
                )

                Button("Clear") {
                    cameraDebugger.clearDebugLog()
                }
                .foregroundColor(.red)
                .font(.caption)

                Button("Export") {
                    showExportSheet = true
                }
                .foregroundColor(.red)
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)

            // Debug Content
            if isExpanded {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(cameraDebugger.debugInfo.indices, id: \.self) { index in
                            Text(cameraDebugger.debugInfo[index])
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 2)
                                .background(
                                    index % 2 == 0 ?
                                    Color.black.opacity(0.3) :
                                    Color.clear
                                )
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                .padding(.horizontal, 12)
            }

            // Debug Controls
            if isExpanded {
                HStack(spacing: 12) {
                    Button("Test Orientation") {
                        cameraDebugger.testOrientationChanges()
                    }
                    .buttonStyle(DebugButtonStyle())

                    Button("Analyze Frame") {
                        cameraDebugger.analyzePreviewLayerFrame()
                    }
                    .buttonStyle(DebugButtonStyle())

                    Spacer()
                }
                .padding(.horizontal, 12)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            DebugExportSheet(debugLog: cameraDebugger.exportDebugLog())
        }
    }
}

struct DebugButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red.opacity(configuration.isPressed ? 0.8 : 0.6))
            .cornerRadius(6)
    }
}

struct DebugExportSheet: View {
    let debugLog: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                Text(debugLog)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Debug Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Copy") {
                        UIPasteboard.general.string = debugLog
                    }
                }
            }
        }
    }
}

#Preview {
    CameraDebugView(cameraDebugger: CameraDebugger())
}
