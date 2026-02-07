import Foundation
import UIKit
import Vision
import CoreImage
import Accelerate

/// Analyzes photo quality for face recognition
/// Provides real-time feedback to help users take better photos
final class PhotoQualityAnalyzer {
    
    // MARK: - Types
    
    enum QualityIssue: Equatable {
        case noFace
        case multipleFaces(count: Int)
        case tooDark
        case tooBright
        case tooFar
        case tooClose
        case offCenter
        case notFacingCamera
        case blurry
        case perfect
        
        var message: String {
            switch self {
            case .noFace:
                return "No face detected"
            case .multipleFaces(let count):
                return "Only one face please (\(count) detected)"
            case .tooDark:
                return "Too dark - find better lighting"
            case .tooBright:
                return "Too bright - reduce lighting"
            case .tooFar:
                return "Move closer"
            case .tooClose:
                return "Move back a bit"
            case .offCenter:
                return "Center your face"
            case .notFacingCamera:
                return "Look at the camera"
            case .blurry:
                return "Hold still"
            case .perfect:
                return "Perfect! Hold steady"
            }
        }
        
        var icon: String {
            switch self {
            case .noFace:
                return "face.dashed"
            case .multipleFaces:
                return "person.2.fill"
            case .tooDark:
                return "sun.min"
            case .tooBright:
                return "sun.max.fill"
            case .tooFar:
                return "arrow.up.left.and.arrow.down.right"
            case .tooClose:
                return "arrow.down.right.and.arrow.up.left"
            case .offCenter:
                return "arrow.up.and.down.and.arrow.left.and.right"
            case .notFacingCamera:
                return "eye"
            case .blurry:
                return "hand.raised"
            case .perfect:
                return "checkmark.circle.fill"
            }
        }
        
        var isProblem: Bool {
            self != .perfect
        }
        
        var severity: Int {
            switch self {
            case .noFace: return 3
            case .multipleFaces: return 3
            case .tooDark, .tooBright: return 2
            case .tooFar, .tooClose: return 2
            case .offCenter: return 1
            case .notFacingCamera: return 2
            case .blurry: return 2
            case .perfect: return 0
            }
        }
    }
    
    struct QualityResult {
        let issues: [QualityIssue]
        let overallScore: Double // 0-100
        let brightness: Double // 0-255
        let blurScore: Double // higher = sharper
        let faceSize: Double // 0-1 (percentage of frame)
        let faceCenterOffset: Double // 0-1 (distance from center)
        let faceYaw: Double // radians
        let faceRoll: Double // radians
        
        var primaryIssue: QualityIssue {
            issues.max(by: { $0.severity < $1.severity }) ?? .perfect
        }
        
        var isAcceptable: Bool {
            overallScore >= 60
        }
        
        var isGood: Bool {
            overallScore >= 80
        }
    }
    
    // MARK: - Configuration
    
    struct Thresholds {
        // Brightness (0-255 grayscale average)
        static let minBrightness: Double = 40
        static let maxBrightness: Double = 220
        static let idealMinBrightness: Double = 80
        static let idealMaxBrightness: Double = 180
        
        // Face size (percentage of frame width)
        static let minFaceSize: Double = 0.15
        static let maxFaceSize: Double = 0.8
        static let idealMinFaceSize: Double = 0.25
        static let idealMaxFaceSize: Double = 0.6
        
        // Face position (distance from center, 0-1)
        static let maxCenterOffset: Double = 0.25
        static let idealCenterOffset: Double = 0.1
        
        // Face angle (radians)
        static let maxYaw: Double = 0.4 // ~23 degrees
        static let maxRoll: Double = 0.3 // ~17 degrees
        
        // Blur (Laplacian variance)
        static let minSharpness: Double = 50
        static let idealSharpness: Double = 100
    }
    
    // MARK: - Singleton
    
    static let shared = PhotoQualityAnalyzer()
    private init() {}
    
    // MARK: - Public Methods
    
    /// Analyze image quality with face observation
    func analyze(image: UIImage, faceObservation: VNFaceObservation?) -> QualityResult {
        var issues: [QualityIssue] = []
        var score: Double = 100
        
        // Get image metrics
        let brightness = calculateBrightness(image: image)
        let blurScore = calculateSharpness(image: image)
        
        // Face-specific metrics
        var faceSize: Double = 0
        var faceCenterOffset: Double = 0
        var faceYaw: Double = 0
        var faceRoll: Double = 0
        
        // Check if face exists
        guard let face = faceObservation else {
            return QualityResult(
                issues: [.noFace],
                overallScore: 0,
                brightness: brightness,
                blurScore: blurScore,
                faceSize: 0,
                faceCenterOffset: 0,
                faceYaw: 0,
                faceRoll: 0
            )
        }
        
        // Calculate face metrics
        faceSize = Double(face.boundingBox.width)
        let faceCenter = CGPoint(
            x: face.boundingBox.midX,
            y: face.boundingBox.midY
        )
        faceCenterOffset = sqrt(pow(faceCenter.x - 0.5, 2) + pow(faceCenter.y - 0.5, 2))
        faceYaw = face.yaw?.doubleValue ?? 0
        faceRoll = face.roll?.doubleValue ?? 0
        
        // Check brightness
        if brightness < Thresholds.minBrightness {
            issues.append(.tooDark)
            score -= 30
        } else if brightness > Thresholds.maxBrightness {
            issues.append(.tooBright)
            score -= 30
        } else if brightness < Thresholds.idealMinBrightness || brightness > Thresholds.idealMaxBrightness {
            score -= 10
        }
        
        // Check face size
        if faceSize < Thresholds.minFaceSize {
            issues.append(.tooFar)
            score -= 25
        } else if faceSize > Thresholds.maxFaceSize {
            issues.append(.tooClose)
            score -= 20
        } else if faceSize < Thresholds.idealMinFaceSize {
            score -= 10
        }
        
        // Check face position
        if faceCenterOffset > Thresholds.maxCenterOffset {
            issues.append(.offCenter)
            score -= 15
        } else if faceCenterOffset > Thresholds.idealCenterOffset {
            score -= 5
        }
        
        // Check face angle
        if abs(faceYaw) > Thresholds.maxYaw || abs(faceRoll) > Thresholds.maxRoll {
            issues.append(.notFacingCamera)
            score -= 25
        }
        
        // Check blur
        if blurScore < Thresholds.minSharpness {
            issues.append(.blurry)
            score -= 25
        } else if blurScore < Thresholds.idealSharpness {
            score -= 10
        }
        
        // If no issues, it's perfect
        if issues.isEmpty {
            issues.append(.perfect)
        }
        
        return QualityResult(
            issues: issues,
            overallScore: max(0, min(100, score)),
            brightness: brightness,
            blurScore: blurScore,
            faceSize: faceSize,
            faceCenterOffset: faceCenterOffset,
            faceYaw: faceYaw,
            faceRoll: faceRoll
        )
    }
    
    /// Quick check for multiple faces
    func checkFaceCount(_ observations: [VNFaceObservation]) -> QualityIssue? {
        if observations.isEmpty {
            return .noFace
        } else if observations.count > 1 {
            return .multipleFaces(count: observations.count)
        }
        return nil
    }
    
    // MARK: - Private Methods
    
    /// Calculate average brightness of image (0-255)
    private func calculateBrightness(image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 128 }
        
        let width = min(cgImage.width, 100) // Downsample for speed
        let height = min(cgImage.height, 100)
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var pixels = [UInt8](repeating: 0, count: width * height)
        
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 128 }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let sum = pixels.reduce(0) { $0 + Int($1) }
        return Double(sum) / Double(pixels.count)
    }
    
    /// Calculate image sharpness using Laplacian variance
    private func calculateSharpness(image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 100 }
        
        // Downsample for performance
        let maxDimension = 200
        let scale = min(1.0, Double(maxDimension) / Double(max(cgImage.width, cgImage.height)))
        let width = Int(Double(cgImage.width) * scale)
        let height = Int(Double(cgImage.height) * scale)
        
        // Convert to grayscale
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var pixels = [UInt8](repeating: 0, count: width * height)
        
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 100 }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Apply Laplacian kernel and calculate variance
        // Laplacian kernel: [0, 1, 0], [1, -4, 1], [0, 1, 0]
        var laplacianValues: [Double] = []
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x
                let center = Double(pixels[idx])
                let top = Double(pixels[(y - 1) * width + x])
                let bottom = Double(pixels[(y + 1) * width + x])
                let left = Double(pixels[y * width + (x - 1)])
                let right = Double(pixels[y * width + (x + 1)])
                
                let laplacian = top + bottom + left + right - 4 * center
                laplacianValues.append(laplacian)
            }
        }
        
        // Calculate variance
        guard !laplacianValues.isEmpty else { return 100 }
        
        let mean = laplacianValues.reduce(0, +) / Double(laplacianValues.count)
        let variance = laplacianValues.reduce(0) { $0 + pow($1 - mean, 2) } / Double(laplacianValues.count)
        
        return variance
    }
}
