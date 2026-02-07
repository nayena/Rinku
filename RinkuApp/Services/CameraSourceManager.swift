import SwiftUI
import AVFoundation
import Combine

/// The active camera source for face recognition
enum CameraSource: String, CaseIterable, Identifiable {
    case phone = "Phone"
    case glasses = "Glasses"
    case auto = "Auto"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .phone:
            return "iphone"
        case .glasses:
            return "eyeglasses"
        case .auto:
            return "sparkles"
        }
    }
    
    var description: String {
        switch self {
        case .phone:
            return "Use phone camera"
        case .glasses:
            return "Use Meta glasses camera"
        case .auto:
            return "Auto-select best camera"
        }
    }
}

/// Unified camera source manager that routes frames from either phone or glasses camera
@MainActor
final class CameraSourceManager: ObservableObject {
    static let shared = CameraSourceManager()
    
    // MARK: - Published State
    
    @Published var selectedSource: CameraSource = .auto {
        didSet {
            if oldValue != selectedSource {
                updateActiveSource()
            }
        }
    }
    
    @Published private(set) var activeSource: CameraSource = .phone
    @Published private(set) var currentFrame: UIImage?
    @Published private(set) var isStreaming: Bool = false
    @Published private(set) var statusMessage: String = ""
    
    /// Callback for when a frame is captured (for face detection)
    var onFrameCaptured: ((UIImage) -> Void)?
    
    // MARK: - Dependencies
    
    private let phoneCamera: CameraManager
    private let glassesCameraManager = GlassesCameraManager.shared
    private let wearablesService = WearablesService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var isGlassesConnected: Bool {
        wearablesService.registrationState.isConnected
    }
    
    var isGlassesAvailable: Bool {
        wearablesService.isSDKConfigured && isGlassesConnected && glassesCameraManager.hasActiveDevice
    }
    
    var canUseGlasses: Bool {
        isGlassesAvailable
    }
    
    // MARK: - Initialization
    
    init() {
        self.phoneCamera = CameraManager()
        setupObservers()
        updateActiveSource()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe glasses connection state
        wearablesService.$registrationState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateActiveSource()
            }
            .store(in: &cancellables)
        
        // Observe glasses device availability
        glassesCameraManager.$hasActiveDevice
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateActiveSource()
            }
            .store(in: &cancellables)
        
        // Observe glasses streaming status
        glassesCameraManager.$streamingStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                if self.activeSource == .glasses {
                    self.isStreaming = status == .streaming
                    self.updateStatusMessage()
                }
            }
            .store(in: &cancellables)
        
        // Observe phone camera status
        phoneCamera.$isSessionRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                guard let self else { return }
                if self.activeSource == .phone {
                    self.isStreaming = isRunning
                    self.updateStatusMessage()
                }
            }
            .store(in: &cancellables)
        
        // Observe glasses frames
        glassesCameraManager.$currentVideoFrame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame in
                guard let self, self.activeSource == .glasses, let frame = frame else { return }
                self.currentFrame = frame
                self.onFrameCaptured?(frame)
            }
            .store(in: &cancellables)
    }
    
    private func updateActiveSource() {
        let previousSource = activeSource
        
        switch selectedSource {
        case .phone:
            activeSource = .phone
        case .glasses:
            // If glasses selected but not available, show error but stay on glasses mode
            activeSource = .glasses
        case .auto:
            // Auto mode: prefer glasses when available, fallback to phone
            if isGlassesAvailable {
                activeSource = .glasses
            } else {
                activeSource = .phone
            }
        }
        
        // Handle source change
        if previousSource != activeSource {
            handleSourceChange(from: previousSource, to: activeSource)
        }
        
        updateStatusMessage()
    }
    
    private func handleSourceChange(from oldSource: CameraSource, to newSource: CameraSource) {
        print("[CameraSourceManager] Switching from \(oldSource) to \(newSource)")
        
        // Stop old source
        Task {
            if oldSource == .glasses {
                await glassesCameraManager.stopStreaming()
            } else if oldSource == .phone {
                phoneCamera.stopSession()
            }
            
            // Start new source if we were streaming
            if isStreaming {
                await startActiveCamera()
            }
        }
    }
    
    private func updateStatusMessage() {
        switch activeSource {
        case .glasses:
            if !isGlassesConnected {
                statusMessage = "Glasses not connected"
            } else if !glassesCameraManager.hasActiveDevice {
                statusMessage = "Waiting for glasses..."
            } else if glassesCameraManager.streamingStatus == .waiting {
                statusMessage = "Connecting to glasses..."
            } else if glassesCameraManager.isStreaming {
                statusMessage = "Using glasses camera"
            } else {
                statusMessage = "Glasses ready"
            }
        case .phone:
            if phoneCamera.isSessionRunning {
                statusMessage = "Using phone camera"
            } else {
                statusMessage = "Phone camera ready"
            }
        case .auto:
            if activeSource == .glasses && isGlassesAvailable {
                statusMessage = "Auto: Using glasses"
            } else {
                statusMessage = "Auto: Using phone"
            }
        }
        
        // Add fallback indicator
        if selectedSource == .glasses && activeSource == .phone {
            statusMessage = "Glasses unavailable - using phone"
        }
    }
    
    // MARK: - Public Methods
    
    /// Configure and prepare cameras
    func configure() {
        phoneCamera.configureSession()
    }
    
    /// Start the active camera
    func startActiveCamera() async {
        switch activeSource {
        case .glasses:
            if canUseGlasses {
                await glassesCameraManager.startStreaming()
            } else {
                // Fallback to phone if glasses not available
                if selectedSource == .auto {
                    activeSource = .phone
                    phoneCamera.startSession()
                    setupPhoneFrameCapture()
                }
            }
        case .phone, .auto:
            phoneCamera.startSession()
            setupPhoneFrameCapture()
        }
        
        updateStatusMessage()
    }
    
    /// Stop the active camera
    func stopActiveCamera() async {
        if activeSource == .glasses {
            await glassesCameraManager.stopStreaming()
        } else {
            phoneCamera.stopSession()
        }
        
        currentFrame = nil
        isStreaming = false
    }
    
    /// Set up frame capture callback for phone camera
    func setupPhoneFrameCapture() {
        phoneCamera.onImageCaptured = { [weak self] image in
            guard let self, self.activeSource == .phone else { return }
            
            self.currentFrame = image
            self.onFrameCaptured?(image)
        }
    }
    
    /// Get the phone camera manager for preview layer
    func getPhoneCameraManager() -> CameraManager {
        return phoneCamera
    }
    
    /// Check if phone camera is authorized
    var isPhoneCameraAuthorized: Bool {
        phoneCamera.isAuthorized
    }
    
    /// Request phone camera authorization
    func requestPhoneCameraAuthorization() async -> Bool {
        await phoneCamera.requestAuthorization()
    }
    
    /// Reset state
    func reset() {
        currentFrame = nil
        glassesCameraManager.reset()
    }
}
