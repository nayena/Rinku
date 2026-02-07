import SwiftUI
import AVFoundation
import CoreBluetooth
import Combine

struct PermissionsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var cameraManager: CameraManager
    var onComplete: () -> Void
    var showBluetoothPermission: Bool = false  // Show Bluetooth permission for glasses setup

    @State private var cameraGranted = false
    @State private var microphoneGranted = false
    @State private var bluetoothGranted = false
    @State private var isRequestingCamera = false
    @State private var isRequestingMicrophone = false
    @State private var isRequestingBluetooth = false
    @StateObject private var bluetoothManager = BluetoothPermissionManager()

    private var allGranted: Bool {
        let basePermissions = cameraGranted && microphoneGranted
        if showBluetoothPermission {
            return basePermissions && bluetoothGranted
        }
        return basePermissions
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primaryLight)
                        .frame(width: 80, height: 80)

                    Image(systemName: "shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.Colors.primary)
                }

                Text("Permissions Needed")
                    .font(.system(size: Theme.FontSize.h1, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Rinku AI needs access to your camera and microphone to help you recognize loved ones.")
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Permission Cards
            VStack(spacing: 16) {
                // Camera Permission
                PermissionCard(
                    icon: "camera.fill",
                    title: "Camera Access",
                    description: "Required to capture faces for recognition. All processing happens on your device.",
                    isGranted: cameraGranted,
                    isLoading: isRequestingCamera
                ) {
                    requestCameraPermission()
                }

                // Microphone Permission
                PermissionCard(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required to play gentle voice reminders about your loved ones.",
                    isGranted: microphoneGranted,
                    isLoading: isRequestingMicrophone
                ) {
                    requestMicrophonePermission()
                }
                
                // Bluetooth Permission (for glasses)
                if showBluetoothPermission {
                    PermissionCard(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Bluetooth Access",
                        description: "Required to connect to Meta smart glasses for hands-free face recognition.",
                        isGranted: bluetoothGranted,
                        isLoading: isRequestingBluetooth
                    ) {
                        requestBluetoothPermission()
                    }
                }
            }
            .padding(.horizontal, 16)

            // Privacy Note
            VStack {
                Text("**Your privacy matters.** All facial recognition happens on your device. We never store or transmit photos without your explicit consent.")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(Theme.Colors.primaryDark)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .background(Theme.Colors.primaryLight)
            .cornerRadius(Theme.CornerRadius.medium)
            .padding(.horizontal, 16)

            // Continue Button
            RinkuButton(
                title: "Continue to Recognize",
                variant: .primary,
                size: .large,
                isDisabled: !allGranted
            ) {
                onComplete()
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(Theme.Colors.background)
        .onAppear {
            checkCurrentPermissions()
        }
    }

    private func checkCurrentPermissions() {
        // Check camera
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraGranted = cameraStatus == .authorized

        // Check microphone
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneGranted = micStatus == .authorized
        
        // Check Bluetooth (if needed)
        if showBluetoothPermission {
            bluetoothGranted = bluetoothManager.isAuthorized
        }
    }

    private func requestCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .notDetermined:
            isRequestingCamera = true
            Task {
                let granted = await cameraManager.requestAuthorization()
                await MainActor.run {
                    cameraGranted = granted
                    isRequestingCamera = false
                    if granted {
                        store.grantPermission(.camera)
                    }
                }
            }
        case .authorized:
            cameraGranted = true
            store.grantPermission(.camera)
        case .denied, .restricted:
            // Open settings
            openSettings()
        @unknown default:
            break
        }
    }

    private func requestMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .notDetermined:
            isRequestingMicrophone = true
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    microphoneGranted = granted
                    isRequestingMicrophone = false
                    if granted {
                        store.grantPermission(.microphone)
                    }
                }
            }
        case .authorized:
            microphoneGranted = true
            store.grantPermission(.microphone)
        case .denied, .restricted:
            openSettings()
        @unknown default:
            break
        }
    }
    
    private func requestBluetoothPermission() {
        isRequestingBluetooth = true
        bluetoothManager.requestAuthorization { granted in
            DispatchQueue.main.async {
                bluetoothGranted = granted
                isRequestingBluetooth = false
            }
        }
    }

    private func openSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}

// MARK: - Permission Card

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    var isLoading: Bool = false
    let onGrant: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isGranted ? Theme.Colors.successLight : Theme.Colors.primaryLight)
                        .frame(width: 48, height: 48)

                    Image(systemName: isGranted ? "checkmark" : icon)
                        .font(.system(size: 24))
                        .foregroundColor(isGranted ? Theme.Colors.success : Theme.Colors.primary)
                }

                // Text
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: Theme.FontSize.h2, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text(description)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()
            }

            // Button
            RinkuButton(
                title: isGranted ? "Granted" : "Allow \(title.replacingOccurrences(of: " Access", with: ""))",
                variant: isGranted ? .secondary : .primary,
                size: .large,
                isLoading: isLoading,
                isDisabled: isGranted
            ) {
                onGrant()
            }
        }
        .padding(24)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(isGranted ? Theme.Colors.success : Theme.Colors.border, lineWidth: 2)
        )
    }
}

// MARK: - Bluetooth Permission Manager

/// Helper class to manage Bluetooth authorization
class BluetoothPermissionManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?
    private var authorizationCallback: ((Bool) -> Void)?
    
    @Published var isAuthorized: Bool = false
    
    override init() {
        super.init()
        checkCurrentAuthorization()
    }
    
    private func checkCurrentAuthorization() {
        switch CBCentralManager.authorization {
        case .allowedAlways:
            isAuthorized = true
        case .notDetermined, .restricted, .denied:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        authorizationCallback = completion
        
        // Creating a CBCentralManager triggers the permission dialog if not determined
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: false
        ])
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let authorized = CBCentralManager.authorization == .allowedAlways
        DispatchQueue.main.async {
            self.isAuthorized = authorized
            self.authorizationCallback?(authorized)
            self.authorizationCallback = nil
        }
    }
}

#Preview {
    PermissionsView(store: AppStore.shared, cameraManager: CameraManager()) {
        print("Permissions complete")
    }
}

#Preview("With Bluetooth") {
    PermissionsView(
        store: AppStore.shared,
        cameraManager: CameraManager(),
        onComplete: { print("Permissions complete") },
        showBluetoothPermission: true
    )
}
