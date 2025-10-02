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

    // ROI Detection integration
    @ObservedObject var roiDetector: ROIDetector
    @Binding var isEditing: Bool

    private let minSize: CGFloat = 100
    private let cornerSize: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                overlayMask

                frameOutline
                    .frame(width: frameRect.width, height: frameRect.height)
                    .position(x: frameRect.midX, y: frameRect.midY)

                if isEditing {
                    ForEach(0..<4, id: \.self) { corner in
                        cornerHandle(at: corner, geometry: geometry)
                            .position(cornerPosition(for: corner))
                    }
                } else {
                    cornerGuides
                        .frame(width: frameRect.width, height: frameRect.height)
                        .position(x: frameRect.midX, y: frameRect.midY)
                }
            }
            .compositingGroup()
            .allowsHitTesting(isEditing)
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
            // Sync with ROI detector
            roiDetector.updateROIRect(frameRect)
        }
        .onChange(of: isEditing) { _, editing in
            if !editing {
                showVisualFeedback = false
                saveFrameRect()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }

    private var overlayMask: some View {
        ZStack {
            if isEditing {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)

                Rectangle()
                    .fill(Color.clear)
                    .frame(width: frameRect.width, height: frameRect.height)
                    .position(x: frameRect.midX, y: frameRect.midY)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
    }

    private var frameOutline: some View {
        let highlightColor: Color = roiDetector.isROIOccupied ? .green : .yellow
        let inactiveColor = Color.white.opacity(0.65)

        let gradientColors: [Color] = isEditing
            ? [highlightColor, .orange, highlightColor]
            : [inactiveColor, Color.white.opacity(0.35), inactiveColor]

        return RoundedRectangle(cornerRadius: 28, style: .continuous)
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(colors: gradientColors),
                    center: .center
                ),
                lineWidth: isEditing ? 3.5 : 2
            )
            .shadow(color: (isEditing ? highlightColor : inactiveColor).opacity(0.45), radius: isEditing ? 10 : 6)
            .opacity(isEditing ? 1.0 : 0.85)
    }

    private var cornerGuides: some View {
        let guideColor = roiDetector.isROIOccupied ? Color.green : Color.white.opacity(0.9)
        let size = CGSize(width: cornerSize + 8, height: cornerSize + 8)

        return ZStack {
            guideCorner(path: .topLeading, size: size, color: guideColor)
                .offset(offset(for: .topLeading, guideSize: size))
            guideCorner(path: .topTrailing, size: size, color: guideColor)
                .offset(offset(for: .topTrailing, guideSize: size))
            guideCorner(path: .bottomLeading, size: size, color: guideColor)
                .offset(offset(for: .bottomLeading, guideSize: size))
            guideCorner(path: .bottomTrailing, size: size, color: guideColor)
                .offset(offset(for: .bottomTrailing, guideSize: size))
        }
    }

    private func guideCorner(path: Corner, size: CGSize, color: Color) -> some View {
        let strokeStyle = StrokeStyle(lineWidth: 4, lineCap: .round)
        return Path { pathBuilder in
            switch path {
            case .topLeading:
                pathBuilder.move(to: CGPoint(x: 0, y: size.height))
                pathBuilder.addLine(to: CGPoint(x: 0, y: 0))
                pathBuilder.addLine(to: CGPoint(x: size.width, y: 0))
            case .topTrailing:
                pathBuilder.move(to: CGPoint(x: size.width, y: size.height))
                pathBuilder.addLine(to: CGPoint(x: size.width, y: 0))
                pathBuilder.addLine(to: CGPoint(x: 0, y: 0))
            case .bottomLeading:
                pathBuilder.move(to: CGPoint(x: 0, y: 0))
                pathBuilder.addLine(to: CGPoint(x: 0, y: size.height))
                pathBuilder.addLine(to: CGPoint(x: size.width, y: size.height))
            case .bottomTrailing:
                pathBuilder.move(to: CGPoint(x: size.width, y: 0))
                pathBuilder.addLine(to: CGPoint(x: size.width, y: size.height))
                pathBuilder.addLine(to: CGPoint(x: 0, y: size.height))
            }
        }
        .stroke(color.opacity(0.9), style: strokeStyle)
        .frame(width: size.width, height: size.height)
    }

    private func offset(for corner: Corner, guideSize: CGSize) -> CGSize {
        let halfWidth = frameRect.width / 2
        let halfHeight = frameRect.height / 2
        let dx = guideSize.width / 2
        let dy = guideSize.height / 2

        switch corner {
        case .topLeading: return CGSize(width: -halfWidth + dx, height: -halfHeight + dy)
        case .topTrailing: return CGSize(width: halfWidth - dx, height: -halfHeight + dy)
        case .bottomLeading: return CGSize(width: -halfWidth + dx, height: halfHeight - dy)
        case .bottomTrailing: return CGSize(width: halfWidth - dx, height: halfHeight - dy)
        }
    }

    private enum Corner {
        case topLeading
        case topTrailing
        case bottomLeading
        case bottomTrailing
    }

    private func cornerHandle(at index: Int, geometry: GeometryProxy) -> some View {
        let accent = roiDetector.isROIOccupied ? Color.green : Color.cyan

        return Circle()
            .fill(accent.opacity(showVisualFeedback ? 0.95 : 0.75))
            .frame(width: cornerSize, height: cornerSize)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
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

        // Update ROI detector
        roiDetector.updateROIRect(frameRect)
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
    FrameBoxOverlayPreview()
}

private struct FrameBoxOverlayPreview: View {
    @State private var isEditing = true

    var body: some View {
        FrameBoxOverlay(roiDetector: ROIDetector(), isEditing: $isEditing)
            .ignoresSafeArea()
            .background(Color.black)
    }
}
