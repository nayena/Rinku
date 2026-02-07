import SwiftUI
import Combine
import MWDATCore

/// Registration state for Meta glasses connection (our own enum for @Published compatibility)
enum GlassesRegistrationState: Equatable {
    case unregistered
    case registering
    case registered
    
    var displayText: String {
        switch self {
        case .unregistered:
            return "Not Connected"
        case .registering:
            return "Connecting..."
        case .registered:
            return "Connected"
        }
    }
    
    var isConnected: Bool {
        self == .registered
    }
}

/// Service that manages Meta smart glasses connection and device discovery
@MainActor
final class WearablesService: ObservableObject {
    static let shared = WearablesService()
    
    // MARK: - Published State
    
    @Published private(set) var registrationState: GlassesRegistrationState = .unregistered
    @Published private(set) var availableDevices: [String] = []
    @Published private(set) var hasActiveDevice: Bool = false
    @Published private(set) var isSDKConfigured: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Private Properties
    
    private var wearables: WearablesInterface?
    private var registrationTask: Task<Void, Never>?
    private var deviceStreamTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    private init() {
        configureSDK()
    }
    
    deinit {
        registrationTask?.cancel()
        deviceStreamTask?.cancel()
    }
    
    // MARK: - SDK Configuration
    
    private func configureSDK() {
        do {
            try Wearables.configure()
            wearables = Wearables.shared
            isSDKConfigured = true
            
            // Start monitoring registration state
            setupRegistrationStream()
            
            print("[WearablesService] SDK configured successfully")
        } catch {
            print("[WearablesService] Failed to configure SDK: \(error)")
            isSDKConfigured = false
        }
    }
    
    private func setupRegistrationStream() {
        guard let wearables = wearables else { return }
        
        // Update initial state by checking against known cases
        updateFromSDKState(wearables.registrationState)
        
        registrationTask = Task {
            for await state in wearables.registrationStateStream() {
                self.updateFromSDKState(state)
                
                if state == .registered {
                    await self.setupDeviceStream()
                }
            }
        }
    }
    
    /// Convert SDK RegistrationState to our GlassesRegistrationState
    private func updateFromSDKState(_ sdkState: RegistrationState) {
        if sdkState == .registered {
            registrationState = .registered
        } else if sdkState == .registering {
            registrationState = .registering
        } else {
            // Any other state (including the "not registered" state) maps to unregistered
            registrationState = .unregistered
        }
    }
    
    private func setupDeviceStream() async {
        guard let wearables = wearables else { return }
        
        deviceStreamTask?.cancel()
        
        deviceStreamTask = Task {
            for await devices in wearables.devicesStream() {
                self.availableDevices = devices.map { String(describing: $0) }
                self.hasActiveDevice = !devices.isEmpty
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Start the glasses registration/pairing flow
    /// This opens the Meta AI app for OAuth authorization
    func connectGlasses() {
        guard registrationState != .registering else { return }
        
        guard let wearables = wearables else {
            showError("SDK not configured")
            return
        }
        
        do {
            try wearables.startRegistration()
        } catch {
            showError("Failed to start registration: \(error.localizedDescription)")
        }
    }
    
    /// Disconnect from the glasses
    func disconnectGlasses() {
        guard let wearables = wearables else { return }
        
        do {
            try wearables.startUnregistration()
        } catch {
            showError("Failed to disconnect: \(error.localizedDescription)")
        }
    }
    
    /// Handle URL callback from Meta AI app
    func handleURL(_ url: URL) async -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true else {
            return false
        }
        
        do {
            _ = try await Wearables.shared.handleUrl(url)
            return true
        } catch {
            showError("Registration error: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Request camera permission for glasses
    func requestGlassesCameraPermission() async -> Bool {
        guard let wearables = wearables else { return false }
        
        do {
            let status = try await wearables.checkPermissionStatus(.camera)
            if status == .granted {
                return true
            }
            
            let requestStatus = try await wearables.requestPermission(.camera)
            return requestStatus == .granted
        } catch {
            showError("Permission error: \(error.localizedDescription)")
            return false
        }
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
