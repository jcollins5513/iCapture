//
//  YOLOSubjectDetector.swift
//  iCapture
//
//  Created by Codex on 11/24/24.
//

import Foundation
import Vision
import CoreML
import CoreImage

/// Runs YOLOv3 via Vision and produces bounding-box driven subject masks that
/// help constrain background removal to relevant regions.
final class YOLOSubjectDetector {
    static let shared = YOLOSubjectDetector()

    private let model: VNCoreMLModel?
    private let subjectIdentifiers: Set<String> = [
        "person", "car", "truck", "bus", "motorbike", "bicycle", "boat"
    ]
    private let minimumConfidence: VNConfidence = 0.15

    private init() {
        #if canImport(CoreML)
        do {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .cpuAndGPU
            model = try VNCoreMLModel(for: YOLOv3(configuration: configuration).model)
            model?.featureProvider = nil
        } catch {
            print("YOLOSubjectDetector: Failed to load YOLOv3 model: \(error)")
            model = nil
        }
        #else
        model = nil
        #endif
    }

    /// Returns a CIImage mask sized to `targetExtent` covering YOLO-detected subjects.
    func subjectBoundingMask(
        for cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        targetExtent: CGRect
    ) -> CIImage? {
        guard let model else { return nil }

        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFit

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("YOLOSubjectDetector: Vision request failed: \(error)")
            return nil
        }

        let results = request.results ?? []
        let detections = results.compactMap { $0 as? VNRecognizedObjectObservation }
            .filter { observation in
                guard observation.confidence >= minimumConfidence else { return false }
                guard let identifier = observation.labels.first?.identifier.lowercased() else { return false }
                return subjectIdentifiers.contains(identifier)
            }

        guard !detections.isEmpty else { return nil }

        var unionMask: CIImage?

        for detection in detections {
            let bbox = detection.boundingBox
            let rect = denormalized(rect: bbox, in: targetExtent)
            let expanded = rect.insetBy(
                dx: -max(rect.width * 0.12, targetExtent.width * 0.015),
                dy: -max(rect.height * 0.15, targetExtent.height * 0.02)
            ).intersection(targetExtent)

            guard !expanded.isNull && !expanded.isEmpty else { continue }

            // Generate a solid rectangle mask for the detection
            let rectMask = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)).cropped(to: expanded)
            if let unionMaskUnwrapped = unionMask {
                let maximum = CIFilter.maximumCompositing()
                maximum.inputImage = rectMask
                maximum.backgroundImage = unionMaskUnwrapped
                unionMask = maximum.outputImage ?? rectMask.composited(over: unionMaskUnwrapped)
            } else {
                unionMask = rectMask
            }
        }

        guard var mask = unionMask else { return nil }
        mask = mask.cropped(to: targetExtent)

        // Slight blur to soften hard rectangle edges before use as a weight map.
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = mask
        blur.radius = 4.0
        if let blurred = blur.outputImage {
            mask = blurred.cropped(to: targetExtent)
        }

        return mask.applyingFilter("CIMaskToAlpha")
    }

    private func denormalized(rect: CGRect, in extent: CGRect) -> CGRect {
        let width = rect.width * extent.width
        let height = rect.height * extent.height
        let originX = rect.minX * extent.width
        // Vision coordinates origin bottom-left; CI origin bottom-left -> we can use same if consistent.
        let originY = rect.minY * extent.height
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}
