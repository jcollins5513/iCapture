//
//  PhotoCaptureResult.swift
//  iCapture
//
//  Created by Justin Collins on 10/2/25.
//

import Foundation
import CoreGraphics

struct PhotoCaptureResult: CustomStringConvertible {
    let timestamp: Date
    let resolution: CGSize
    let format: String
    let is48MP: Bool
    let captureLatency: TimeInterval

    var description: String {
        let resolutionText = is48MP ? "48MP" : "12MP"
        let sizeText = "\(Int(resolution.width))×\(Int(resolution.height))"
        let latencyText = String(format: "%.3f", captureLatency)
        return "\(resolutionText) \(format) - \(sizeText) - \(latencyText)s"
    }
}
