import AVFoundation
import SwiftUI
import Combine

final class CameraManager: NSObject, ObservableObject {
    // Published properties must be updated on main thread
    @MainActor @Published var isAuthorized = false
    @MainActor @Published var isSessionRunning = false
    @MainActor @Published var error: CameraError?

    // These are accessed from sessionQueue, so they're not MainActor
    let session = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let frameQueue = DispatchQueue(label: "camera.frame.queue")

    // Callback for when a frame is captured (for face detection later)
    // Uses UIImage instead of CMSampleBuffer for Sendable compliance
    @MainActor var onFrameCaptured: ((CMSampleBuffer) -> Void)?
    @MainActor var onImageCaptured: ((UIImage) -> Void)?

    enum CameraError: Error, LocalizedError, Sendable {
        case notAuthorized
        case configurationFailed
        case noCameraAvailable

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Camera access was denied. Please enable it in Settings."
            case .configurationFailed:
                return "Failed to configure camera session."
            case .noCameraAvailable:
                return "No camera available on this device."
            }
        }
    }

    override init() {
        super.init()
        Task { @MainActor in
            checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    @MainActor
    func checkAuthorizationStatus() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = false
        case .denied, .restricted:
            isAuthorized = false
            error = .notAuthorized
        @unknown default:
            isAuthorized = false
        }
    }

    @MainActor
    func requestAuthorization() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        if status == .authorized {
            isAuthorized = true
            return true
        }

        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            isAuthorized = granted
            if !granted {
                error = .notAuthorized
            }
            return granted
        }

        error = .notAuthorized
        return false
    }

    // MARK: - Session Configuration

    func configureSession() {
        sessionQueue.async { [self] in
            session.beginConfiguration()
            session.sessionPreset = .high

            // Add video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                Task { @MainActor in
                    self.error = .noCameraAvailable
                }
                session.commitConfiguration()
                return
            }

            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)

                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                } else {
                    Task { @MainActor in
                        self.error = .configurationFailed
                    }
                    session.commitConfiguration()
                    return
                }
            } catch {
                Task { @MainActor in
                    self.error = .configurationFailed
                }
                session.commitConfiguration()
                return
            }

            // Add video output for frame processing
            videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]

            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)

                // Set video orientation
                if let connection = videoOutput.connection(with: .video) {
                    if connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    }
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = true
                    }
                }
            }

            session.commitConfiguration()
        }
    }

    // MARK: - Session Control

    func startSession() {
        sessionQueue.async { [self] in
            if !session.isRunning {
                session.startRunning()
                let running = session.isRunning
                Task { @MainActor in
                    self.isSessionRunning = running
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [self] in
            if session.isRunning {
                session.stopRunning()
                Task { @MainActor in
                    self.isSessionRunning = false
                }
            }
        }
    }
}

// MARK: - Video Output Delegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Convert to UIImage on the capture thread (CMSampleBuffer is not Sendable)
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)
        
        // Pass the Sendable UIImage to main actor
        Task { @MainActor [weak self] in
            self?.onImageCaptured?(image)
        }
    }
}

// MARK: - Image Conversion Helpers

extension CMSampleBuffer {
    /// Convert CMSampleBuffer to UIImage
    func toUIImage() -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else {
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}
