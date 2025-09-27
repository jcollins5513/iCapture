//
//  FrameBoxOverlay.swift
//  iCapture
//
//  Created by Justin Collins on 9/27/25.
//

import SwiftUI

struct FrameBoxOverlay: View {
    @State private var frameRect = CGRect(x: 50, y: 200, width: 300, height: 200)
    @State private var isDragging = false
    @State private var isResizing = false
    @State private var dragOffset = CGSize.zero
    @State private var resizeCorner: Int?
    @State private var initialFrameRect = CGRect.zero
    @State private var showVisualFeedback = false

    private let minSize: CGFloat = 100
    private let cornerSize: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent overlay
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                // Clear area for frame box
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: frameRect.width, height: frameRect.height)
                    .position(x: frameRect.midX, y: frameRect.midY)
                    .blendMode(.destinationOut)

                // Frame box border with visual feedback
                Rectangle()
                    .stroke(showVisualFeedback ? Color.orange : Color.yellow, lineWidth: showVisualFeedback ? 3 : 2)
                    .frame(width: frameRect.width, height: frameRect.height)
                    .position(x: frameRect.midX, y: frameRect.midY)
                    .animation(.easeInOut(duration: 0.2), value: showVisualFeedback)

                // Corner handles for resizing
                ForEach(0..<4, id: \.self) { corner in
                    cornerHandle(at: corner, geometry: geometry)
                        .position(cornerPosition(for: corner))
                }
            }
            .compositingGroup()
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDragGesture(value: value, geometry: geometry)
                    }
                    .onEnded { _ in
                        handleDragEnd()
                    }
            )
        }
        .onAppear {
            loadFrameRect()
        }
    }

    private func cornerHandle(at index: Int, geometry: GeometryProxy) -> some View {
        Circle()
            .fill(showVisualFeedback ? Color.orange : Color.yellow)
            .frame(width: cornerSize, height: cornerSize)
            .overlay(
                Circle()
                    .stroke(Color.black, lineWidth: 1)
            )
            .scaleEffect(showVisualFeedback ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: showVisualFeedback)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if resizeCorner == nil {
                            resizeCorner = index
                            isResizing = true
                            initialFrameRect = frameRect
                            showVisualFeedback = true
                        }
                        handleResizeGesture(value: value, geometry: geometry)
                    }
                    .onEnded { _ in
                        isResizing = false
                        resizeCorner = nil
                        showVisualFeedback = false
                        saveFrameRect()
                    }
            )
    }

    private func cornerPosition(for index: Int) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: frameRect.minX, y: frameRect.minY) // Top-left
        case 1: return CGPoint(x: frameRect.maxX, y: frameRect.minY) // Top-right
        case 2: return CGPoint(x: frameRect.minX, y: frameRect.maxY) // Bottom-left
        case 3: return CGPoint(x: frameRect.maxX, y: frameRect.maxY) // Bottom-right
        default: return .zero
        }
    }

    private func saveFrameRect() {
        // Save to UserDefaults for persistence
        let rectData = [
            "x": frameRect.origin.x,
            "y": frameRect.origin.y,
            "width": frameRect.size.width,
            "height": frameRect.size.height
        ]
        UserDefaults.standard.set(rectData, forKey: "frameBoxRect")
    }

    private func loadFrameRect() {
        if let rectData = UserDefaults.standard.dictionary(forKey: "frameBoxRect"),
           let xValue = rectData["x"] as? CGFloat,
           let yValue = rectData["y"] as? CGFloat,
           let width = rectData["width"] as? CGFloat,
           let height = rectData["height"] as? CGFloat {
            frameRect = CGRect(x: xValue, y: yValue, width: width, height: height)
        }
    }

    func getFrameRect() -> CGRect {
        return frameRect
    }

    // MARK: - Gesture Handling

    private func handleDragGesture(value: DragGesture.Value, geometry: GeometryProxy) {
        if isResizing {
            return // Don't handle dragging if we're resizing
        }

        if !isDragging {
            isDragging = true
            dragOffset = CGSize.zero
            showVisualFeedback = true
        }

        let newOrigin = CGPoint(
            x: max(0, min(geometry.size.width - frameRect.width,
                        frameRect.origin.x + value.translation.width - dragOffset.width)),
            y: max(0, min(geometry.size.height - frameRect.height,
                        frameRect.origin.y + value.translation.height - dragOffset.height))
        )

        frameRect.origin = newOrigin
        dragOffset = value.translation
    }

    private func handleDragEnd() {
        isDragging = false
        dragOffset = .zero
        showVisualFeedback = false
        saveFrameRect()
    }

    private func handleResizeGesture(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let corner = resizeCorner else { return }

        let translation = value.translation
        var newRect = initialFrameRect

        switch corner {
        case 0: // Top-left
            newRect.origin.x = max(0, min(initialFrameRect.maxX - minSize,
                                        initialFrameRect.origin.x + translation.width))
            newRect.origin.y = max(0, min(initialFrameRect.maxY - minSize,
                                        initialFrameRect.origin.y + translation.height))
            newRect.size.width = initialFrameRect.maxX - newRect.origin.x
            newRect.size.height = initialFrameRect.maxY - newRect.origin.y
        case 1: // Top-right
            newRect.origin.y = max(0, min(initialFrameRect.maxY - minSize,
                                        initialFrameRect.origin.y + translation.height))
            newRect.size.width = max(minSize, initialFrameRect.width + translation.width)
            newRect.size.height = initialFrameRect.maxY - newRect.origin.y
        case 2: // Bottom-left
            newRect.origin.x = max(0, min(initialFrameRect.maxX - minSize,
                                        initialFrameRect.origin.x + translation.width))
            newRect.size.width = initialFrameRect.maxX - newRect.origin.x
            newRect.size.height = max(minSize, initialFrameRect.height + translation.height)
        case 3: // Bottom-right
            newRect.size.width = max(minSize, initialFrameRect.width + translation.width)
            newRect.size.height = max(minSize, initialFrameRect.height + translation.height)
        default:
            break
        }

        // Ensure the frame stays within bounds
        if newRect.maxX > geometry.size.width {
            newRect.size.width = geometry.size.width - newRect.origin.x
        }
        if newRect.maxY > geometry.size.height {
            newRect.size.height = geometry.size.height - newRect.origin.y
        }

        frameRect = newRect
    }
}

#Preview {
    FrameBoxOverlay()
        .ignoresSafeArea()
}
