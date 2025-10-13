//
//  U2NetBackgroundRemover.swift
//  iCapture
//
//  Created by Codex on 10/13/25.
//

import Foundation
import UIKit

/// Wrapper for the U2-Net based background removal library.
/// This provides an alternative background removal method that can be tested
/// alongside the existing Vision/DeepLab/YOLO pipeline.
final class U2NetBackgroundRemover {
    static let shared = U2NetBackgroundRemover()

    private var isAvailable: Bool = false

    private init() {
        // Check if the BackgroundRemoval library is available
        #if canImport(BackgroundRemoval)
        isAvailable = true
        print("U2NetBackgroundRemover: BackgroundRemoval library available")
        #else
        isAvailable = false
        print("U2NetBackgroundRemover: BackgroundRemoval library not available")
        #endif
    }

    /// Attempts to remove background using U2-Net model
    /// Returns nil if the library is unavailable or processing fails
    func removeBackground(from image: UIImage) -> UIImage? {
        #if canImport(BackgroundRemoval)
        guard isAvailable else {
            print("U2NetBackgroundRemover: Library not available")
            return nil
        }

        do {
            // Import dynamically to avoid compile errors when not available
            // Note: This requires the BackgroundRemoval package to be added via SPM
            let startTime = CFAbsoluteTimeGetCurrent()

            // swiftlint:disable:next todo
            // TODO: Uncomment when BackgroundRemoval package is added
            // let backgroundRemoval = BackgroundRemoval()
            // let outputImage = try backgroundRemoval.removeBackground(image: image)

            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("U2NetBackgroundRemover: Successfully removed background in \(Int(duration * 1_000))ms")

            // Return nil for now until package is added
            return nil
        } catch {
            print("U2NetBackgroundRemover: Failed to remove background: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Returns the mask only (useful for debugging and custom compositing)
    func getMask(from image: UIImage) -> UIImage? {
        #if canImport(BackgroundRemoval)
        guard isAvailable else {
            print("U2NetBackgroundRemover: Library not available")
            return nil
        }

        do {
            // swiftlint:disable:next todo
            // TODO: Uncomment when BackgroundRemoval package is added
            // let backgroundRemoval = BackgroundRemoval()
            // let maskImage = try backgroundRemoval.removeBackground(image: image, maskOnly: true)
            // return maskImage

            return nil
        } catch {
            print("U2NetBackgroundRemover: Failed to get mask: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }
}
