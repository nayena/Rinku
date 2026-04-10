import SwiftUI
import AVFoundation

struct CameraFrameView: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var faceDetectionManager: FaceDetectionManager
    var statusMessage: String? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera Preview or Placeholder
                if cameraManager.isSessionRunning {
                    CameraPreviewView(session: cameraManager.session)
                } else {
                    // Placeholder when camera not running
                    Color(red: 0.15, green: 0.15, blue: 0.15)

                    if let error = cameraManager.error {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)

                            Text(error.localizedDescription)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    } else {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)

                            Text("Starting camera...")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                }

                // Face detection overlay (only when camera is running)
                if cameraManager.isSessionRunning {
                    // Draw face bounding boxes
                    ForEach(Array(faceDetectionManager.detectedFaces.enumerated()), id: \.offset) { _, faceRect in
                        FaceBoxOverlay(
                            normalizedRect: faceRect,
                            viewSize: geometry.size,
                            stabilityProgress: faceDetectionManager.faceStabilityProgress,
                            isRecognizing: faceDetectionManager.isRecognizing,
                            qualityScore: faceDetectionManager.qualityScore,
                            isQualityAcceptable: faceDetectionManager.isQualityAcceptable
                        )
                    }
                    
                    // Guide when no face detected
                    if !faceDetectionManager.hasFace {
                        VStack {
                            Spacer()
                            
                            // Center circle guide for face positioning
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    .frame(width: 180, height: 180)
                                
                                // Positioning hints
                                VStack(spacing: 8) {
                                    Image(systemName: "face.dashed")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.5))
                                    
                                    Text("Position face here")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            
                            Spacer()
                        }
                    }
                }

                // Status overlay
                VStack {
                    // Top status bar
                    if cameraManager.isSessionRunning {
                        HStack {
                            // Quality score indicator
                            if faceDetectionManager.hasFace {
                                QualityScoreBadge(
                                    score: faceDetectionManager.qualityScore,
                                    isAcceptable: faceDetectionManager.isQualityAcceptable
                                )
                            } else {
                                // No face indicator
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 8, height: 8)
                                    
                                    Text("No face")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(Theme.CornerRadius.pill)
                            }
                            
                            Spacer()
                            
                            // Auto mode indicator
                            if faceDetectionManager.isAutoRecognitionEnabled {
                                HStack(spacing: 4) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 10))
                                    Text("Auto")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.primary.opacity(0.8))
                                .cornerRadius(Theme.CornerRadius.pill)
                            }
                        }
                        .padding(12)
                    }
                    
                    Spacer()
                    
                    // Quality feedback message
                    if cameraManager.isSessionRunning && faceDetectionManager.hasFace {
                        QualityFeedbackBanner(
                            issue: faceDetectionManager.qualityIssue,
                            isRecognizing: faceDetectionManager.isRecognizing
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Bottom status message
                    if let status = statusMessage, !status.isEmpty {
                        Text(status)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(Theme.CornerRadius.medium)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: faceDetectionManager.qualityIssue)
            }
            .cornerRadius(Theme.CornerRadius.medium)
        }
        .aspectRatio(3/4, contentMode: .fit)
    }
}

// MARK: - Quality Score Badge

struct QualityScoreBadge: View {
    let score: Double
    let isAcceptable: Bool
    
    private var scoreColor: Color {
        if score >= 80 {
            return Theme.Colors.success
        } else if score >= 60 {
            return Color.yellow
        } else {
            return Theme.Colors.danger
        }
    }
    
    private var statusText: String {
        if score >= 80 {
            return "Great"
        } else if score >= 60 {
            return "OK"
        } else {
            return "Poor"
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Score circle
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
            }
            
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.5))
        .cornerRadius(Theme.CornerRadius.pill)
    }
}

// MARK: - Quality Feedback Banner

struct QualityFeedbackBanner: View {
    let issue: PhotoQualityAnalyzer.QualityIssue
    let isRecognizing: Bool
    
    private var backgroundColor: Color {
        if isRecognizing {
            return Theme.Colors.primary
        }
        switch issue {
        case .perfect:
            return Theme.Colors.success
        case .noFace, .multipleFaces:
            return Theme.Colors.danger
        default:
            return Color.orange
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            if isRecognizing {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.white)
                
                Text("Recognizing...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            } else {
                Image(systemName: issue.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(issue.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .cornerRadius(Theme.CornerRadius.medium)
        .shadow(color: backgroundColor.opacity(0.4), radius: 8, y: 4)
    }
}

// MARK: - Face Box Overlay

struct FaceBoxOverlay: View {
    let normalizedRect: CGRect
    let viewSize: CGSize
    let stabilityProgress: Double
    let isRecognizing: Bool
    var qualityScore: Double = 100
    var isQualityAcceptable: Bool = true
    
    // Convert Vision coordinates (origin bottom-left, normalized) to SwiftUI coordinates
    private var convertedRect: CGRect {
        // Vision uses bottom-left origin, SwiftUI uses top-left
        // Also need to mirror horizontally for front camera
        let x = (1 - normalizedRect.origin.x - normalizedRect.width) * viewSize.width
        let y = (1 - normalizedRect.origin.y - normalizedRect.height) * viewSize.height
        let width = normalizedRect.width * viewSize.width
        let height = normalizedRect.height * viewSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private var boxColor: Color {
        if isRecognizing {
            return Theme.Colors.primary
        } else if !isQualityAcceptable {
            return Color.orange
        } else if stabilityProgress >= 1.0 {
            return Theme.Colors.success
        } else if stabilityProgress > 0.5 {
            return Color.yellow
        } else if qualityScore >= 80 {
            return Theme.Colors.success
        } else {
            return Color.white
        }
    }
    
    var body: some View {
        let rect = convertedRect
        
        ZStack {
            // Face bounding box with corner accents
            FaceBoxShape()
                .stroke(boxColor, lineWidth: 3)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
            
            // Progress ring when detecting (only if quality is acceptable)
            if stabilityProgress > 0 && stabilityProgress < 1.0 && !isRecognizing && isQualityAcceptable {
                Circle()
                    .trim(from: 0, to: stabilityProgress)
                    .stroke(Theme.Colors.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .position(x: rect.midX, y: rect.maxY + 30)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: stabilityProgress)
        .animation(.easeInOut(duration: 0.2), value: isRecognizing)
        .animation(.easeInOut(duration: 0.2), value: qualityScore)
    }
}

// MARK: - Face Box Shape (corner accents only)

struct FaceBoxShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerLength: CGFloat = 20
        
        // Top-left corner
        path.move(to: CGPoint(x: 0, y: cornerLength))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: cornerLength, y: 0))
        
        // Top-right corner
        path.move(to: CGPoint(x: rect.width - cornerLength, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: cornerLength))
        
        // Bottom-right corner
        path.move(to: CGPoint(x: rect.width, y: rect.height - cornerLength))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width - cornerLength, y: rect.height))
        
        // Bottom-left corner
        path.move(to: CGPoint(x: cornerLength, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height - cornerLength))
        
        return path
    }
}

#Preview {
    VStack {
        CameraFrameView(
            cameraManager: CameraManager(),
            faceDetectionManager: FaceDetectionManager(),
            statusMessage: "Loading models..."
        )
        .padding()
    }
    .background(Color.gray.opacity(0.2))
}

#Preview("Quality Feedback") {
    VStack(spacing: 20) {
        QualityFeedbackBanner(
            issue: .perfect,
            isRecognizing: false
        )
        
        QualityFeedbackBanner(
            issue: .tooDark,
            isRecognizing: false
        )
        
        QualityFeedbackBanner(
            issue: .tooFar,
            isRecognizing: false
        )
        
        QualityFeedbackBanner(
            issue: .notFacingCamera,
            isRecognizing: false
        )
        
        QualityFeedbackBanner(
            issue: .blurry,
            isRecognizing: true
        )
        
        HStack {
            QualityScoreBadge(score: 95, isAcceptable: true)
            QualityScoreBadge(score: 70, isAcceptable: true)
            QualityScoreBadge(score: 40, isAcceptable: false)
        }
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
