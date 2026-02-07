import SwiftUI

/// Detailed settings view for Meta smart glasses connection and configuration
struct GlassesSettingsView: View {
    @ObservedObject private var wearablesService = WearablesService.shared
    @ObservedObject private var glassesCameraManager = GlassesCameraManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Connection Status Card
                    ConnectionStatusCard(
                        registrationState: wearablesService.registrationState,
                        hasActiveDevice: glassesCameraManager.hasActiveDevice,
                        onConnect: { wearablesService.connectGlasses() },
                        onDisconnect: { wearablesService.disconnectGlasses() }
                    )
                    
                    // Setup Instructions
                    if !wearablesService.registrationState.isConnected {
                        SetupInstructionsCard()
                    }
                    
                    // Device Info (when connected)
                    if wearablesService.registrationState.isConnected {
                        DeviceInfoCard(
                            hasActiveDevice: glassesCameraManager.hasActiveDevice,
                            streamingStatus: glassesCameraManager.streamingStatus
                        )
                    }
                    
                    // Troubleshooting
                    TroubleshootingCard()
                    
                    
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Smart Glasses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Connection Status Card

private struct ConnectionStatusCard: View {
    let registrationState: GlassesRegistrationState
    let hasActiveDevice: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    private var statusColor: Color {
        switch registrationState {
        case .registered:
            return hasActiveDevice ? Theme.Colors.success : Theme.Colors.warning
        case .registering:
            return Theme.Colors.warning
        case .unregistered:
            return Theme.Colors.textSecondary
        }
    }
    
    private var statusText: String {
        switch registrationState {
        case .registered:
            return hasActiveDevice ? "Connected & Ready" : "Connected (No Device)"
        case .registering:
            return "Connecting..."
        case .unregistered:
            return "Not Connected"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: registrationState.isConnected ? "eyeglasses" : "eyeglasses")
                    .font(.system(size: 36))
                    .foregroundColor(statusColor)
            }
            
            // Status Text
            VStack(spacing: 4) {
                Text("Meta Smart Glasses")
                    .font(.system(size: Theme.FontSize.h2, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(statusText)
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            
            // Action Button
            if registrationState == .registering {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("Opening Meta AI app...")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(.top, 8)
            } else if registrationState.isConnected {
                Button {
                    onDisconnect()
                } label: {
                    Text("Disconnect Glasses")
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundColor(Theme.Colors.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.dangerLight)
                        .cornerRadius(Theme.CornerRadius.medium)
                }
            } else {
                Button {
                    onConnect()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                        Text("Connect Glasses")
                    }
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.primary)
                    .cornerRadius(Theme.CornerRadius.medium)
                }
            }
        }
        .padding(24)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Setup Instructions Card

private struct SetupInstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to Connect")
                .font(.system(size: Theme.FontSize.h3, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: 12) {
                SetupStep(
                    number: 1,
                    title: "Enable Developer Mode",
                    description: "In Meta AI app, go to Settings > Developer Mode and enable it"
                )
                
                SetupStep(
                    number: 2,
                    title: "Pair Your Glasses",
                    description: "Make sure your Meta glasses are paired with the Meta AI app"
                )
                
                SetupStep(
                    number: 3,
                    title: "Connect to Rinku",
                    description: "Tap 'Connect Glasses' above to authorize Rinku"
                )
                
                SetupStep(
                    number: 4,
                    title: "Grant Permissions",
                    description: "Allow Rinku to access the glasses camera when prompted"
                )
            }
        }
        .padding(20)
        .background(Theme.Colors.primaryLight)
        .cornerRadius(Theme.CornerRadius.medium)
    }
}

private struct SetupStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary)
                    .frame(width: 24, height: 24)
                
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(description)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Device Info Card

private struct DeviceInfoCard: View {
    let hasActiveDevice: Bool
    let streamingStatus: GlassesStreamingStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device Status")
                .font(.system(size: Theme.FontSize.h3, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
            
            VStack(spacing: 12) {
                DeviceInfoRow(
                    icon: "antenna.radiowaves.left.and.right",
                    label: "Device Available",
                    value: hasActiveDevice ? "Yes" : "No",
                    valueColor: hasActiveDevice ? Theme.Colors.success : Theme.Colors.warning
                )
                
                DeviceInfoRow(
                    icon: "video",
                    label: "Camera Stream",
                    value: streamingStatus.displayText,
                    valueColor: streamingStatus == .streaming ? Theme.Colors.success : Theme.Colors.textSecondary
                )
                
                DeviceInfoRow(
                    icon: "checkmark.shield",
                    label: "Permissions",
                    value: "Granted",
                    valueColor: Theme.Colors.success
                )
            }
        }
        .padding(20)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}

private struct DeviceInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let valueColor: Color
    
    var body: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.primary)
                    .frame(width: 20)
                
                Text(label)
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: Theme.FontSize.body, weight: .medium))
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Troubleshooting Card

private struct TroubleshootingCard: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(Theme.Colors.primary)
                    
                    Text("Troubleshooting")
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    TroubleshootingItem(
                        question: "Glasses not connecting?",
                        answer: "Make sure Developer Mode is enabled in the Meta AI app and your glasses are powered on."
                    )
                    
                    TroubleshootingItem(
                        question: "Camera not working?",
                        answer: "Ensure you've granted camera permissions when prompted. You can also check in iOS Settings > Privacy."
                    )
                    
                    TroubleshootingItem(
                        question: "Stream keeps disconnecting?",
                        answer: "Make sure your glasses are charged and within Bluetooth range. Try moving closer to your phone."
                    )
                    
                    TroubleshootingItem(
                        question: "Meta AI app not opening?",
                        answer: "Install the Meta AI app from the App Store if you haven't already."
                    )
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}

private struct TroubleshootingItem: View {
    let question: String
    let answer: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(question)
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
            
            Text(answer)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    GlassesSettingsView()
}
