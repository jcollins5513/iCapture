//
//  VehicleDetector.swift
//  iCapture
//
//  Created by Justin Collins on 9/28/25.
//

import AVFoundation
import Vision
import Combine
import UIKit

@MainActor
class VehicleDetector: ObservableObject {
    @Published var isVehicleDetected = false
    @Published var vehicleConfidence: Float = 0.0
    @Published var vehicleBoundingBox: CGRect = .zero
    @Published var detectionCount: Int = 0
    
    private var vehicleDetectionRequest: VNClassifyImageRequest?
    private let processingQueue = DispatchQueue(label: "vehicle.detection.queue", qos: .userInitiated)
    
    // Detection parameters
    private let confidenceThreshold: Float = 0.6
    private let detectionHistorySize = 10
    private var detectionHistory: [Bool] = []
    
    init() {
        setupVehicleDetection()
    }
    
    // MARK: - Public Interface
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        processingQueue.async { [weak self] in
            Task { @MainActor in
                await self?.performVehicleDetection(pixelBuffer)
            }
        }
    }
    
    func resetDetectionHistory() {
        detectionHistory.removeAll()
        Task { @MainActor in
            self.isVehicleDetected = false
            self.vehicleConfidence = 0.0
            self.vehicleBoundingBox = .zero
            self.detectionCount = 0
        }
    }
    
    // MARK: - Private Methods
    
    private func setupVehicleDetection() {
        // Use VNClassifyImageRequest for general object detection
        // This will detect cars, trucks, buses, etc.
        let request = VNClassifyImageRequest { [weak self] request, error in
            if let error = error {
                print("VehicleDetector: Error in vehicle detection: \(error)")
                return
            }
            
            self?.handleVehicleDetectionResults(request.results)
        }
        
        vehicleDetectionRequest = request
    }
    
    private func performVehicleDetection(_ pixelBuffer: CVPixelBuffer) async {
        guard let request = vehicleDetectionRequest else {
            // Fallback to basic object detection if custom model fails
            await performBasicVehicleDetection(pixelBuffer)
            return
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("VehicleDetector: Failed to perform vehicle detection: \(error)")
            // Fallback to basic detection
            await performBasicVehicleDetection(pixelBuffer)
        }
    }
    
    private func performBasicVehicleDetection(_ pixelBuffer: CVPixelBuffer) async {
        // Fallback detection using VNClassifyImageRequest without custom model
        let request = VNClassifyImageRequest { [weak self] request, error in
            if let error = error {
                print("VehicleDetector: Error in basic vehicle detection: \(error)")
                return
            }
            
            self?.handleVehicleDetectionResults(request.results)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("VehicleDetector: Failed to perform basic vehicle detection: \(error)")
        }
    }
    
    private func handleVehicleDetectionResults(_ results: [Any]?) {
        guard let observations = results as? [VNClassificationObservation] else {
            Task { @MainActor in
                self.updateVehicleDetection(detected: false, confidence: 0.0, boundingBox: .zero)
            }
            return
        }
        
        // Look for vehicle-related classifications
        var bestVehicleDetection: (confidence: Float, boundingBox: CGRect) = (0.0, .zero)
        
        for observation in observations {
            // Check if the classification indicates a vehicle
            let labelText = observation.identifier.lowercased()
            let isVehicle = labelText.contains("car") || 
                           labelText.contains("truck") || 
                           labelText.contains("bus") || 
                           labelText.contains("vehicle") ||
                           labelText.contains("automobile") ||
                           labelText.contains("suv") ||
                           labelText.contains("van") ||
                           labelText.contains("motorcycle")
            
            if isVehicle {
                let confidence = observation.confidence
                if confidence > bestVehicleDetection.confidence {
                    bestVehicleDetection = (confidence, .zero) // VNClassifyImageRequest doesn't provide bounding boxes
                }
            }
        }
        
        let isDetected = bestVehicleDetection.confidence >= confidenceThreshold
        
        Task { @MainActor in
            self.updateVehicleDetection(
                detected: isDetected,
                confidence: bestVehicleDetection.confidence,
                boundingBox: bestVehicleDetection.boundingBox
            )
        }
    }
    
    private func updateVehicleDetection(detected: Bool, confidence: Float, boundingBox: CGRect) {
        // Add to detection history
        detectionHistory.append(detected)
        if detectionHistory.count > detectionHistorySize {
            detectionHistory.removeFirst()
        }
        
        // Use majority voting to reduce false positives
        let positiveDetections = detectionHistory.filter { $0 }.count
        let finalDetection = positiveDetections > detectionHistory.count / 2
        
        if finalDetection != isVehicleDetected {
            isVehicleDetected = finalDetection
            if finalDetection {
                detectionCount += 1
                print("VehicleDetector: Vehicle detected! Confidence: \(String(format: "%.2f", confidence)), Count: \(detectionCount)")
            } else {
                print("VehicleDetector: Vehicle lost")
            }
        }
        
        vehicleConfidence = confidence
        vehicleBoundingBox = boundingBox
    }
}

// MARK: - Vehicle Detection Summary
// This implementation uses Vision framework's built-in VNClassifyImageRequest
// to detect vehicles in the camera feed. It looks for vehicle-related classifications
// like "car", "truck", "bus", etc. and uses majority voting to reduce false positives.
