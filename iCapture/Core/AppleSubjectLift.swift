//
//  AppleSubjectLift.swift
//  iCapture
//
//  Created by Codex on 11/24/24.
//

import Foundation
import UIKit

#if canImport(VisionKit)
import VisionKit

@available(iOS 16.0, *)
struct AppleSubjectLiftResult {
    let image: UIImage
    let subjectCount: Int
    let analysisDuration: TimeInterval
}

@available(iOS 16.0, *)
final class AppleSubjectLift {
    static let shared = AppleSubjectLift()

    private let analyzer = ImageAnalyzer()
    private init() {}

    var isSupported: Bool {
        ImageAnalyzer.isSupported
    }

    func liftSubjectSync(
        from image: UIImage,
        reason: String,
        timeout: TimeInterval = 3.0
    ) -> AppleSubjectLiftResult? {
        var liftResult: AppleSubjectLiftResult?
        let semaphore = DispatchSemaphore(value: 0)

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else {
                semaphore.signal()
                return
            }
            let result = await self.liftSubject(from: image, reason: reason)
            liftResult = result
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            print("AppleSubjectLift: Timed out (\(reason)) after \(timeout)s")
        }

        return liftResult
    }

    func liftSubject(from image: UIImage, reason: String) async -> AppleSubjectLiftResult? {
        guard ImageAnalyzer.isSupported else {
            print("AppleSubjectLift: ImageAnalyzer unsupported (\(reason))")
            return nil
        }

        do {
            let startTime = Date()
            let configuration = ImageAnalyzer.Configuration([.visualLookUp])
            let analysis = try await analyzer.analyze(image, configuration: configuration)

            let interaction = await MainActor.run { () -> ImageAnalysisInteraction in
                let instance = ImageAnalysisInteraction()
                instance.preferredInteractionTypes = [.imageSubject]
                return instance
            }

            await MainActor.run {
                interaction.analysis = analysis
            }

            let subjects = await interaction.subjects

            guard !subjects.isEmpty else {
                print("AppleSubjectLift: No subjects detected (\(reason))")
                await MainActor.run {
                    interaction.analysis = nil
                }
                return nil
            }

            let snapshot = try await interaction.image(for: subjects)

            await MainActor.run {
                interaction.analysis = nil
            }

            let duration = Date().timeIntervalSince(startTime)
            print(
                "AppleSubjectLift: Snapshot generated (\(subjects.count) subject(s), \(Int(duration * 1_000))ms) [\(reason)]"
            )

            return AppleSubjectLiftResult(
                image: snapshot,
                subjectCount: subjects.count,
                analysisDuration: duration
            )
        } catch {
            print("AppleSubjectLift: Failed (\(reason)) - \(error)")
            return nil
        }
    }
}
#endif
