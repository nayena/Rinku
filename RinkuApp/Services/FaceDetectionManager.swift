import Foundation
import Vision
import AVFoundation
import CoreImage
import UIKit
import Combine

/// Manages real-time face detection using Apple's Vision framework (free/on-device)
/// Triggers auto-recognition when a face has been stable for a threshold duration
final class FaceDetectionManager: ObservableObject {
    
    // MARK: - Published State
    
    /// Current detected face bounding boxes (normalized 0-1 coordinates)
    @Published var detectedFaces: [CGRect] = []
    
    /// Whether a face is currently detected
    @Published var hasFace: Bool = false
    
    /// How long current face has been stable (for UI feedback)
    @Published var faceStabilityProgress: Double = 0
    
    /// Whether auto-recognition is enabled
    @Published var isAutoRecognitionEnabled: Bool = true
    
    /// Whether currently processing recognition (to prevent duplicate calls)
    @Published var isRecognizing: Bool = false
    
    /// Current photo quality feedback
    @Published var qualityIssue: PhotoQualityAnalyzer.QualityIssue = .noFace
    
    /// Overall quality score (0-100)
    @Published var qualityScore: Double = 0
    
    /// Whether photo quality is good enough for recognition
    @Published var isQualityAcceptable: Bool = false
    
    // MARK: - Configuration
    
    /// Time a face must be stable before triggering recognition (seconds)
    var stabilityThreshold: TimeInterval = 1.5
    
    /// Cooldown after recognition before trying again (seconds)
    var recognitionCooldown: TimeInterval = 5.0
    
    /// Minimum confidence for face detection
    var minimumConfidence: Float = 0.7
    
    /// Whether to require good quality before recognition
    var requireGoodQuality: Bool = true
    
    // MARK: - Callbacks
    
    /// Called when face has been stable long enough to trigger recognition
    var onReadyToRecognize: ((UIImage) -> Void)?
    
    // MARK: - Private State
    
    private var faceDetectedSince: Date?
    private var lastRecognitionTime: Date?
    private var lastProcessedImage: UIImage?
    private var lastFaceObservation: VNFaceObservation?
    private var stabilityTimer: Timer?
    private let detectionQueue = DispatchQueue(label: "face.detection.queue", qos: .userInteractive)
    private let qualityAnalyzer = PhotoQualityAnalyzer.shared
    
    // MARK: - Public Methods
    
    /// Process a camera frame for face detection
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        // Skip if in cooldown
        if let lastRecognition = lastRecognitionTime,
           Date().timeIntervalSince(lastRecognition) < recognitionCooldown {
            return
        }
        
        // Skip if already recognizing
        guard !isRecognizing else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Convert to UIImage for later use
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)
        
        // Run face detection
        detectionQueue.async { [weak self] in
            self?.detectFaces(in: pixelBuffer, image: image)
        }
    }
    
    /// Process a UIImage directly for face detection (used for glasses camera)
    func processImage(_ image: UIImage) {
        // Skip if in cooldown
        if let lastRecognition = lastRecognitionTime,
           Date().timeIntervalSince(lastRecognition) < recognitionCooldown {
            return
        }
        
        // Skip if already recognizing
        guard !isRecognizing else { return }
        
        // Run face detection on the image
        detectionQueue.async { [weak self] in
            self?.detectFacesInImage(image)
        }
    }
    
    private func detectFacesInImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            DispatchQueue.main.async {
                self.handleNoFace()
            }
            return
        }
        
        let minConfidence = self.minimumConfidence
        
        // Use landmarks request to get yaw/roll for quality analysis
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Face detection error: \(error)")
                DispatchQueue.main.async {
                    self.handleNoFace()
                }
                return
            }
            
            guard let results = request.results as? [VNFaceObservation] else {
                DispatchQueue.main.async {
                    self.handleNoFace()
                }
                return
            }
            
            // Filter by confidence
            let confidentFaces = results.filter { $0.confidence >= minConfidence }
            
            DispatchQueue.main.async {
                if confidentFaces.isEmpty {
                    self.handleNoFace()
                } else {
                    self.handleFacesDetected(confidentFaces, image: image)
                }
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    /// Reset state (call when view disappears)
    func reset() {
        detectedFaces = []
        hasFace = false
        faceStabilityProgress = 0
        faceDetectedSince = nil
        lastProcessedImage = nil
        lastFaceObservation = nil
        stabilityTimer?.invalidate()
        stabilityTimer = nil
        qualityIssue = .noFace
        qualityScore = 0
        isQualityAcceptable = false
    }
    
    /// Mark recognition as complete (resets cooldown)
    func recognitionCompleted() {
        isRecognizing = false
        lastRecognitionTime = Date()
        faceDetectedSince = nil
        faceStabilityProgress = 0
    }
    
    /// Cancel current recognition attempt
    func cancelRecognition() {
        isRecognizing = false
        faceDetectedSince = nil
        faceStabilityProgress = 0
    }
    
    // MARK: - Private Methods
    
    private func detectFaces(in pixelBuffer: CVPixelBuffer, image: UIImage) {
        let minConfidence = self.minimumConfidence
        
        // Use landmarks request to get yaw/roll for quality analysis
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Face detection error: \(error)")
                DispatchQueue.main.async {
                    self.handleNoFace()
                }
                return
            }
            
            guard let results = request.results as? [VNFaceObservation] else {
                DispatchQueue.main.async {
                    self.handleNoFace()
                }
                return
            }
            
            // Filter by confidence
            let confidentFaces = results.filter { $0.confidence >= minConfidence }
            
            DispatchQueue.main.async {
                if confidentFaces.isEmpty {
                    self.handleNoFace()
                } else {
                    self.handleFacesDetected(confidentFaces, image: image)
                }
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
    
    private func handleNoFace() {
        detectedFaces = []
        hasFace = false
        faceDetectedSince = nil
        faceStabilityProgress = 0
        lastProcessedImage = nil
        lastFaceObservation = nil
        qualityIssue = .noFace
        qualityScore = 0
        isQualityAcceptable = false
    }
    
    private func handleFacesDetected(_ faces: [VNFaceObservation], image: UIImage) {
        // Update detected face boxes
        detectedFaces = faces.map { $0.boundingBox }
        hasFace = true
        lastProcessedImage = image
        lastFaceObservation = faces.first
        
        // Check for multiple faces
        if let faceCountIssue = qualityAnalyzer.checkFaceCount(faces) {
            qualityIssue = faceCountIssue
            qualityScore = 0
            isQualityAcceptable = false
            faceDetectedSince = nil
            faceStabilityProgress = 0
            return
        }
        
        // Analyze photo quality
        let qualityResult = qualityAnalyzer.analyze(image: image, faceObservation: faces.first)
        qualityIssue = qualityResult.primaryIssue
        qualityScore = qualityResult.overallScore
        isQualityAcceptable = qualityResult.isAcceptable
        
        // Only track stability if quality is acceptable (or if we don't require good quality)
        let shouldTrackStability = !requireGoodQuality || qualityResult.isAcceptable
        
        if shouldTrackStability {
            // Track stability
            if faceDetectedSince == nil {
                faceDetectedSince = Date()
            }
            
            // Calculate stability progress
            if let startTime = faceDetectedSince {
                let elapsed = Date().timeIntervalSince(startTime)
                faceStabilityProgress = min(elapsed / stabilityThreshold, 1.0)
                
                // Check if ready to recognize
                if elapsed >= stabilityThreshold && isAutoRecognitionEnabled && !isRecognizing {
                    triggerRecognition()
                }
            }
        } else {
            // Quality not acceptable - reset stability
            faceDetectedSince = nil
            faceStabilityProgress = 0
        }
    }
    
    private func triggerRecognition() {
        guard let image = lastProcessedImage else { return }
        
        isRecognizing = true
        faceStabilityProgress = 1.0
        
        // Notify callback
        onReadyToRecognize?(image)
    }
}
