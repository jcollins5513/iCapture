//
//  DeepLabSegmenter.swift
//  iCapture
//
//  Created by Codex on 11/24/24.
//

import Foundation
import Vision
import CoreML
import CoreImage
import CoreVideo

/// Helper responsible for turning DeepLabV3 semantic predictions into a refined subject mask.
/// The resulting CIImage is sized to match the requested extent and emphasizes classes that
/// correspond to subjects of interest (people and vehicles).
final class DeepLabSegmenter {
    static let shared = DeepLabSegmenter()

    private let model: VNCoreMLModel?
    private let subjectLabels: Set<Int32> = [6, 7, 14, 15] // bus, car, motorbike, person

    private init() {
        #if canImport(CoreML)
        do {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .cpuAndGPU
            let deepLabModel = try DeepLabV3(configuration: configuration)
            model = try VNCoreMLModel(for: deepLabModel.model)
        } catch {
            print("DeepLabSegmenter: Failed to load DeepLabV3 model: \(error)")
            model = nil
        }
        #else
        model = nil
        #endif
    }

    /// Generates a grayscale mask (0-1) highlighting subject pixels using DeepLabV3.
    func makeSubjectMask(
        for cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        targetExtent: CGRect
    ) -> CIImage? {
        guard let model else { return nil }

        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFit
        request.usesCPUOnly = false

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("DeepLabSegmenter: Vision request failed: \(error)")
            return nil
        }

        guard let observation = request.results?.compactMap({ $0 as? VNCoreMLFeatureValueObservation }).first,
              let multiArray = observation.featureValue.multiArrayValue else {
            return nil
        }

        guard let maskBuffer = convertToMaskBuffer(multiArray: multiArray) else { return nil }

        var maskImage = CIImage(cvPixelBuffer: maskBuffer)
        let scaleX = targetExtent.width / maskImage.extent.width
        let scaleY = targetExtent.height / maskImage.extent.height
        maskImage = maskImage
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: targetExtent)

        // Smooth slightly to avoid aliasing while keeping edges tight.
        let blur = CIFilter.gaussianBlur()
        blur.radius = 1.1
        blur.inputImage = maskImage
        if let blurred = blur.outputImage {
            maskImage = blurred.cropped(to: targetExtent)
        }

        return maskImage.applyingFilter("CIMaskToAlpha")
    }
}

private extension DeepLabSegmenter {
    func convertToMaskBuffer(multiArray: MLMultiArray) -> CVPixelBuffer? {
        let shape = multiArray.shape.map { Int(truncating: $0) }
        guard !shape.isEmpty else { return nil }

        let widthIndex = shape.count - 1
        let heightIndex = max(0, shape.count - 2)
        let width = shape[widthIndex]
        let height = shape[heightIndex]
        if width == 0 || height == 0 { return nil }

        let channelIndex = shape.count > 2 ? shape.count - 3 : -1
        let channelCount = channelIndex >= 0 ? shape[channelIndex] : 1
        let strides = multiArray.strides.map { Int(truncating: $0) }
        let strideWidth = strides[widthIndex]
        let strideHeight = heightIndex < strides.count ? strides[heightIndex] : 0
        let strideChannel = channelIndex >= 0 ? strides[channelIndex] : 0

        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent8,
            attrs as CFDictionary,
            &pixelBuffer
        ) == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let maskPointer = baseAddress.assumingMemoryBound(to: UInt8.self)

        let valueReader = MultiArrayValueReader(multiArray: multiArray)

        for row in 0..<height {
            let maskRow = maskPointer.advanced(by: row * bytesPerRow)
            for column in 0..<width {
                let baseIndex = row * strideHeight + column * strideWidth
                let label: Int32
                if channelCount <= 1 {
                    label = valueReader.label(at: baseIndex)
                } else {
                    label = valueReader.argmax(channelCount: channelCount, baseIndex: baseIndex, channelStride: strideChannel)
                }
                maskRow[column] = subjectLabels.contains(label) ? 255 : 0
            }
        }

        return buffer
    }
}

private struct MultiArrayValueReader {
    enum Storage {
        case double(UnsafePointer<Double>)
        case float32(UnsafePointer<Float32>)
        case int32(UnsafePointer<Int32>)
        case float16(UnsafeRawPointer)
        case unsupported
    }

    let storage: Storage

    init(multiArray: MLMultiArray) {
        switch multiArray.dataType {
        case .double:
            storage = .double(multiArray.dataPointer.assumingMemoryBound(to: Double.self))
        case .float32:
            storage = .float32(multiArray.dataPointer.assumingMemoryBound(to: Float32.self))
        case .float64:
            storage = .double(multiArray.dataPointer.assumingMemoryBound(to: Double.self))
        case .int32:
            storage = .int32(multiArray.dataPointer.assumingMemoryBound(to: Int32.self))
        case .float16:
            storage = .float16(UnsafeRawPointer(multiArray.dataPointer))
        default:
            storage = .unsupported
        }
    }

    func label(at index: Int) -> Int32 {
        switch storage {
        case let .double(pointer):
            return Int32(pointer[index].rounded())
        case let .float32(pointer):
            return Int32(pointer[index].rounded())
        case let .int32(pointer):
            return pointer[index]
        case let .float16(raw):
            let value = MultiArrayValueReader.float16ToFloat(raw.advanced(by: index * MemoryLayout<UInt16>.stride))
            return Int32(value.rounded())
        case .unsupported:
            return 0
        }
    }

    func argmax(channelCount: Int, baseIndex: Int, channelStride: Int) -> Int32 {
        var bestClass: Int32 = 0
        var bestScore = -Double.greatestFiniteMagnitude

        for channel in 0..<channelCount {
            let index = baseIndex + channel * channelStride
            let score = value(at: index)
            if score > bestScore {
                bestScore = score
                bestClass = Int32(channel)
            }
        }
        return bestClass
    }

    private func value(at index: Int) -> Double {
        switch storage {
        case let .double(pointer):
            return pointer[index]
        case let .float32(pointer):
            return Double(pointer[index])
        case let .int32(pointer):
            return Double(pointer[index])
        case let .float16(raw):
            let value = MultiArrayValueReader.float16ToFloat(raw.advanced(by: index * MemoryLayout<UInt16>.stride))
            return Double(value)
        case .unsupported:
            return 0
        }
    }

    private static func float16ToFloat(_ pointer: UnsafeRawPointer) -> Float {
        let rawValue = pointer.load(as: UInt16.self)
        if #available(iOS 14.0, *) {
            let float16Value = Float16(bitPattern: rawValue)
            return Float(float16Value)
        }

        // Basic fallback conversion; precision is acceptable for mask logits.
        let sign = (rawValue & 0x8000) >> 15
        var exponent = Int((rawValue & 0x7C00) >> 10)
        let mantissa = Int(rawValue & 0x03FF)

        if exponent == 0 {
            if mantissa == 0 { return sign == 0 ? 0 : -0 }
            let exp = -14
            let frac = Float(mantissa) / 1_024.0
            let magnitude = ldexpf(frac, Int32(exp))
            return sign == 0 ? magnitude : -magnitude
        }

        if exponent == 31 {
            return mantissa == 0 ? (sign == 0 ? Float.infinity : -Float.infinity) : Float.nan
        }

        exponent -= 15
        let frac = 1.0 + Float(mantissa) / 1_024.0
        let magnitude = ldexpf(frac, Int32(exponent))
        return sign == 0 ? magnitude : -magnitude
    }
}
