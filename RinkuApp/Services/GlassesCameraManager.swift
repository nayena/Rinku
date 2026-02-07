import SwiftUI
import Combine
import MWDATCore
import MWDATCamera

/// Streaming status for glasses camera
enum GlassesStreamingStatus: Equatable {
    case stopped
    case waiting
    case streaming
    
    var displayText: String {
        switch self {
        case .stopped:
            return "Stopped"
        case .waiting:
            return "Connecting..."
        case .streaming:
            return "Streaming"
        }
    }
}

/// Manages video streaming from Meta smart glasses camera
@MainActor
final class GlassesCameraManager: ObservableObject {
    static let shared = GlassesCameraManager()
    
    // MARK: - Published State
    
    @Published private(set) var currentVideoFrame: UIImage?
    @Published private(set) var streamingStatus: GlassesStreamingStatus = .stopped
    @Published private(set) var hasReceivedFirstFrame: Bool = false
    @Published private(set) var hasActiveDevice: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    /// Callback for when a frame is captured (for face detection)
    var onFrameCaptured: ((UIImage) -> Void)?
    
    var isStreaming: Bool {
        streamingStatus == .streaming
    }
    
    // MARK: - Private Properties
    
    private var streamSession: StreamSession?
    private var deviceSelector: AutoDeviceSelector?
    private var stateListenerToken: AnyListenerToken?
    private var videoFrameListenerToken: AnyListenerToken?
    private var errorListenerToken: AnyListenerToken?
    private var deviceMonitorTask: Task<Void, Never>?
    
    private let wearablesService = WearablesService.shared
    
    // MARK: - Initialization
    
    private init() {
        setupStreamSession()
    }
    
    deinit {
        deviceMonitorTask?.cancel()
    }
    
    // MARK: - Setup
    
    private func setupStreamSession() {
        guard wearablesService.isSDKConfigured else {
            print("[GlassesCameraManager] SDK not configured, skipping stream session setup")
            return
        }
        
        // Create device selector for auto-selecting available devices
        let wearables = Wearables.shared
        deviceSelector = AutoDeviceSelector(wearables: wearables)
        
        guard let deviceSelector = deviceSelector else { return }
        
        // Configure stream session with appropriate settings for face recognition
        // Using low resolution and 24fps to balance quality and performance
        let config = StreamSessionConfig(
            videoCodec: VideoCodec.raw,
            resolution: StreamingResolution.low,
            frameRate: 24
        )
        
        streamSession = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)
        
        guard let streamSession = streamSession else { return }
        
        // Monitor device availability
        deviceMonitorTask = Task { @MainActor in
            for await device in deviceSelector.activeDeviceStream() {
                self.hasActiveDevice = device != nil
            }
        }
        
        // Subscribe to session state changes
        stateListenerToken = streamSession.statePublisher.listen { [weak self] state in
            Task { @MainActor [weak self] in
                self?.updateStatusFromState(state)
            }
        }
        
        // Subscribe to video frames
        videoFrameListenerToken = streamSession.videoFramePublisher.listen { [weak self] videoFrame in
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                if let image = videoFrame.makeUIImage() {
                    self.currentVideoFrame = image
                    
                    if !self.hasReceivedFirstFrame {
                        self.hasReceivedFirstFrame = true
                    }
                    
                    // Call the frame callback for face detection
                    self.onFrameCaptured?(image)
                }
            }
        }
        
        // Subscribe to errors
        errorListenerToken = streamSession.errorPublisher.listen { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let errorMessage = self.formatStreamingError(error)
                if errorMessage != self.errorMessage {
                    self.showError(errorMessage)
                }
            }
        }
        
        // Update initial state
        updateStatusFromState(streamSession.state)
        
        print("[GlassesCameraManager] Stream session configured")
    }
    
    private func updateStatusFromState(_ state: StreamSessionState) {
        switch state {
        case .stopped:
            currentVideoFrame = nil
            streamingStatus = .stopped
            hasReceivedFirstFrame = false
        case .waitingForDevice, .starting, .stopping, .paused:
            streamingStatus = .waiting
        case .streaming:
            streamingStatus = .streaming
        @unknown default:
            streamingStatus = .stopped
        }
    }
    
    private func formatStreamingError(_ error: StreamSessionError) -> String {
        switch error {
        case .internalError:
            return "An internal error occurred. Please try again."
        case .deviceNotFound:
            return "Glasses not found. Please ensure they are connected."
        case .deviceNotConnected:
            return "Glasses disconnected. Please check your connection."
        case .timeout:
            return "Connection timed out. Please try again."
        case .videoStreamingError:
            return "Video streaming failed. Please try again."
        case .audioStreamingError:
            return "Audio streaming failed."
        case .permissionDenied:
            return "Camera permission denied. Please grant permission in Settings."
        @unknown default:
            return "An unknown streaming error occurred."
        }
    }
    
    // MARK: - Public Methods
    
    /// Start streaming video from glasses
    func startStreaming() async {
        guard let streamSession = streamSession else {
            showError("Stream session not configured")
            return
        }
        
        // Request camera permission first
        let hasPermission = await wearablesService.requestGlassesCameraPermission()
        guard hasPermission else {
            showError("Camera permission denied")
            return
        }
        
        await streamSession.start()
        print("[GlassesCameraManager] Started streaming")
    }
    
    /// Stop streaming video from glasses
    func stopStreaming() async {
        guard let streamSession = streamSession else { return }
        
        await streamSession.stop()
        currentVideoFrame = nil
        hasReceivedFirstFrame = false
        print("[GlassesCameraManager] Stopped streaming")
    }
    
    /// Reset state for new session
    func reset() {
        currentVideoFrame = nil
        hasReceivedFirstFrame = false
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    func dismissError() {
        showError = false
        errorMessage = ""
    }
}
