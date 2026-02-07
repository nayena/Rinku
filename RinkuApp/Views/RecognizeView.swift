import SwiftUI
import AVFoundation

struct RecognizeView: View {
    @ObservedObject var store: AppStore
    @Binding var selectedTab: TabItem
    @StateObject private var cameraManager = CameraManager()
    @ObservedObject private var audioService = AudioService.shared
    @StateObject private var faceDetectionManager = FaceDetectionManager()
    @ObservedObject private var historyService = RecognitionHistoryService.shared
    @ObservedObject private var offlineCache = OfflineFaceCache.shared
    @StateObject private var cameraSourceManager = CameraSourceManager.shared
    @ObservedObject private var wearablesService = WearablesService.shared
    @ObservedObject private var glassesCameraManager = GlassesCameraManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var showPermissions = false
    @State private var status: RecognitionStatus = .idle
    @State private var recognizedPerson: LovedOne? = nil
    @State private var showEnrollSheet = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .success
    @State private var lastCapturedImage: UIImage?
    @State private var isAWSConfigured = AWSConfig.isConfigured
    @State private var wasOfflineRecognition = false
    @State private var showGlassesSettings = false

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header with Camera Source Toggle
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("camera_recognize_title".localized)
                                .font(.system(size: Theme.FontSize.h1, weight: .bold))
                                .foregroundColor(Theme.Colors.textPrimary)

                            Text("camera_subtitle".localized)
                                .font(.system(size: Theme.FontSize.caption))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Spacer()

                        // Camera Source Toggle
                        CameraSourceToggle(
                            selectedSource: $cameraSourceManager.selectedSource,
                            isGlassesConnected: wearablesService.registrationState.isConnected,
                            onGlassesSetup: { showGlassesSettings = true }
                        )
                    }
                    
                    // Camera Source Status
                    if cameraSourceManager.activeSource == .glasses || cameraSourceManager.selectedSource == .glasses {
                        CameraSourceStatusBar(
                            activeSource: cameraSourceManager.activeSource,
                            statusMessage: cameraSourceManager.statusMessage,
                            isGlassesConnected: wearablesService.registrationState.isConnected
                        )
                    }

                    // Camera View with face detection overlay
                    // Shows either phone camera or glasses stream based on active source
                    if cameraSourceManager.activeSource == .glasses && glassesCameraManager.currentVideoFrame != nil {
                        GlassesCameraFrameView(
                            image: glassesCameraManager.currentVideoFrame,
                            faceDetectionManager: faceDetectionManager,
                            statusMessage: autoStatusMessage
                        )
                    } else {
                        CameraFrameView(
                            cameraManager: cameraManager,
                            faceDetectionManager: faceDetectionManager,
                            statusMessage: autoStatusMessage
                        )
                    }

                    // Status Bar
                    HStack {
                        Spacer()
                        StatusBarView(type: status.statusType, message: statusMessage)
                        Spacer()
                    }

                    // AWS Configuration warning
                    if !isAWSConfigured {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.Colors.warning)
                            Text("camera_aws_warning".localized)
                                .font(.system(size: Theme.FontSize.caption))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(12)
                        .background(Theme.Colors.warningLight)
                        .cornerRadius(8)
                    }

                    // Recognition Result
                    if status == .recognized, let person = recognizedPerson {
                        RecognitionResultCard(
                            person: person,
                            audioService: audioService,
                            historyService: historyService,
                            wasOffline: wasOfflineRecognition
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Manual button (as fallback)
                    if status != .recognized {
                        VStack(spacing: 12) {
                            // Info about auto mode
                            if faceDetectionManager.isAutoRecognitionEnabled && isAWSConfigured {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(Theme.Colors.primary)
                                    Text("camera_auto_info".localized)
                                        .font(.system(size: Theme.FontSize.caption))
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                                .padding(12)
                                .background(Theme.Colors.primaryLight)
                                .cornerRadius(8)
                            }
                            
                            // Manual recognize button (if auto is disabled or as fallback)
                            if !faceDetectionManager.isAutoRecognitionEnabled || !isAWSConfigured {
                                RinkuButton(
                                    title: "camera_who_is_this".localized,
                                    variant: .primary,
                                    size: .large,
                                    isLoading: status == .extracting,
                                    isDisabled: !canRecognize
                                ) {
                                    Task {
                                        await handleRecognize()
                                    }
                                }
                            }

                            RinkuButton(
                                title: "camera_add_photo".localized,
                                icon: "person.fill.badge.plus",
                                variant: .secondary,
                                size: .large,
                                isDisabled: !cameraManager.isSessionRunning
                            ) {
                                showEnrollSheet = true
                            }
                        }
                    } else {
                        // Show "Scan Again" button when recognized
                        RinkuButton(
                            title: "camera_scan_again".localized,
                            icon: "arrow.clockwise",
                            variant: .secondary,
                            size: .large
                        ) {
                            resetForNewScan()
                        }
                    }

                    
                }
                .padding(.horizontal, 16)
                .padding(.top, 32)
            .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background.ignoresSafeArea())

            // Toast
            if showToast {
                ToastContainer {
                    ToastView(
                        type: toastType,
                        message: toastMessage
                    ) {
                        showToast = false
                    }
                }
            }

            // Bottom Sheet
            BottomSheet(isPresented: $showEnrollSheet, title: "camera_choose_person".localized) {
                VStack(spacing: 12) {
                    if store.lovedOnes.isEmpty {
                        VStack(spacing: 16) {
                            Text("camera_no_loved_ones".localized)
                                .font(.system(size: Theme.FontSize.body))
                                .foregroundColor(Theme.Colors.textSecondary)

                            RinkuButton(
                                title: "home_add_button".localized,
                                variant: .primary,
                                size: .medium
                            ) {
                                showEnrollSheet = false
                                selectedTab = .add
                            }
                        }
                        .padding(.vertical, 32)
                    } else {
                        ForEach(store.lovedOnes) { person in
                            PersonListItem(
                                name: person.displayName,
                                relationship: person.relationship
                            ) {
                                Task {
                                    await handleEnroll(personId: person.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            checkPermissionsAndSetup()
        }
        .onDisappear {
            cameraManager.stopSession()
            faceDetectionManager.reset()
        }
        .fullScreenCover(isPresented: $showPermissions) {
            PermissionsView(store: store, cameraManager: cameraManager) {
                showPermissions = false
                startCamera()
            }
        }
        .sheet(isPresented: $showGlassesSettings) {
            GlassesSettingsView()
        }
        .onChange(of: cameraManager.isSessionRunning) { _, isRunning in
            if isRunning {
                setupFrameCapture()
            }
        }
        .onChange(of: glassesCameraManager.isStreaming) { _, isStreaming in
            if isStreaming {
                setupFrameCapture()
            }
        }
        .onChange(of: cameraSourceManager.selectedSource) { oldSource, newSource in
            // Only handle if the source actually changed and we're running
            if oldSource != newSource && (cameraManager.isSessionRunning || glassesCameraManager.isStreaming) {
                handleCameraSourceChange(from: oldSource, to: newSource)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: status)
        .id(languageManager.currentLanguage) // Force refresh when language changes
    }

    private var canRecognize: Bool {
        cameraManager.isSessionRunning && status != .loading && status != .extracting && isAWSConfigured
    }

    private var statusMessage: String {
        if status == .recognized, let person = recognizedPerson {
            return "I think this is \(person.displayName), your \(person.relationship)."
        }
        return status.message
    }
    
    private var autoStatusMessage: String? {
        if !isAWSConfigured {
            return "camera_configure_aws".localized
        }
        if status == .extracting || faceDetectionManager.isRecognizing {
            return "camera_recognizing".localized
        }
        if status == .recognized {
            return nil // Result card shows info
        }
        if !faceDetectionManager.hasFace {
            return "camera_position_face".localized
        }
        if faceDetectionManager.faceStabilityProgress < 1.0 {
            return "camera_hold_still".localized
        }
        return nil
    }

    private func checkPermissionsAndSetup() {
        // Check system authorization status directly to avoid race condition
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)

        if cameraStatus == .authorized {
            // Already authorized, start camera
            cameraManager.checkAuthorizationStatus()
            startCamera()
        } else if cameraStatus == .notDetermined {
            // Need to request permission
            showPermissions = true
        } else {
            // Denied or restricted - show permissions view to guide user to settings
            showPermissions = true
        }
    }

    private func startCamera() {
        status = .loading
        
        // Check AWS configuration
        isAWSConfigured = AWSConfig.isConfigured
        
        // Enable auto-recognition only if AWS is configured
        faceDetectionManager.isAutoRecognitionEnabled = isAWSConfigured
        
        // Determine which camera to use
        if cameraSourceManager.selectedSource == .glasses && wearablesService.registrationState.isConnected {
            // Use glasses camera
            Task {
                await glassesCameraManager.startStreaming()
                await MainActor.run {
                    status = .enrolled
                }
            }
        } else {
            // Use phone camera (default)
            cameraManager.configureSession()
            cameraManager.startSession()
            status = .enrolled
        }
    }

    private func setupFrameCapture() {
        // Set up auto-recognition callback
        faceDetectionManager.onReadyToRecognize = { [self] image in
            Task { @MainActor in
                await self.handleAutoRecognize(image: image)
            }
        }
        
        // Set up phone camera frame callback (uses UIImage for Swift 6 Sendable compliance)
        cameraManager.onImageCaptured = { image in
            // Store the latest image for manual recognition
            self.lastCapturedImage = image
            
            // Process frame for face detection (auto mode)
            self.faceDetectionManager.processImage(image)
        }
        
        // Set up glasses frame callback
        glassesCameraManager.onFrameCaptured = { image in
            // Store the latest image
            self.lastCapturedImage = image
            
            // Process for face detection
            self.faceDetectionManager.processImage(image)
        }
    }
    
    private func handleCameraSourceChange(from oldSource: CameraSource, to newSource: CameraSource) {
        print("[RecognizeView] Camera source changed from \(oldSource) to \(newSource)")
        
        // Reset face detection state
        faceDetectionManager.reset()
        
        // Handle camera switching
        Task {
            // Stop old camera
            if oldSource == .glasses {
                await glassesCameraManager.stopStreaming()
            } else {
                cameraManager.stopSession()
            }
            
            // Start new camera
            if newSource == .glasses && wearablesService.registrationState.isConnected {
                await glassesCameraManager.startStreaming()
                toastMessage = "Switched to glasses camera"
            } else {
                cameraManager.configureSession()
                cameraManager.startSession()
                toastMessage = "Switched to phone camera"
            }
            
            toastType = .info
            showToast = true
        }
    }
    
    private func handleAutoRecognize(image: UIImage) async {
        // Check if there are any loved ones with photos
        let lovedOnesWithPhotos = store.lovedOnes.filter { !$0.photoFileNames.isEmpty }
        guard !lovedOnesWithPhotos.isEmpty else {
            // Try offline cache even without enrolled photos
            if offlineCache.hasCache {
                await tryOfflineRecognition(image: image)
            } else {
                faceDetectionManager.recognitionCompleted()
            }
            return
        }
        
        status = .extracting
        recognizedPerson = nil
        wasOfflineRecognition = false
        
        do {
            let result = try await AWSRekognitionService.shared.findMatchingPerson(
                sourceImage: image,
                lovedOnes: lovedOnesWithPhotos,
                similarityThreshold: 70.0
            )
            
            faceDetectionManager.recognitionCompleted()
            offlineCache.setOfflineMode(false)
            
            if result.isMatch, let personId = result.personId {
                if let person = store.getLovedOne(byId: personId) {
                    recognizedPerson = person
                    status = .recognized
                    toastMessage = "Recognized with \(Int(result.similarity))% confidence"
                    toastType = .success
                    showToast = true
                    
                    // Log to history
                    historyService.logRecognition(
                        person: person,
                        confidence: Double(result.similarity),
                        image: image,
                        wasOffline: false
                    )
                    
                    // Cache for offline use
                    await offlineCache.cacheFace(person: person, image: image)
                    
                    // Play audio reminder
                    audioService.speakRecognitionReminder(for: person)
                } else {
                    status = .enrolled
                }
            } else {
                status = .notRecognized
                toastMessage = "Face not recognized"
                toastType = .info
                showToast = true
                
                // Reset after a moment to try again
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if self.status == .notRecognized {
                        self.status = .enrolled
                    }
                }
            }
        } catch {
            print("Auto recognition error: \(error)")
            
            // Try offline recognition as fallback
            await tryOfflineRecognition(image: image)
        }
    }
    
    private func tryOfflineRecognition(image: UIImage) async {
        offlineCache.setOfflineMode(true)
        
        if let offlineResult = await offlineCache.matchOffline(image: image) {
            // Found offline match
            if let person = store.getLovedOne(byId: offlineResult.personId) {
                faceDetectionManager.recognitionCompleted()
                
                recognizedPerson = person
                status = .recognized
                wasOfflineRecognition = true
                toastMessage = "Offline match (~\(Int(offlineResult.similarity))%)"
                toastType = .success
                showToast = true
                
                // Log to history (marked as offline)
                historyService.logRecognition(
                    person: person,
                    confidence: offlineResult.similarity,
                    image: image,
                    wasOffline: true
                )
                
                // Play audio reminder
                audioService.speakRecognitionReminder(for: person)
            } else {
                faceDetectionManager.recognitionCompleted()
                status = .enrolled
            }
        } else {
            faceDetectionManager.recognitionCompleted()
            status = .enrolled
            
            if offlineCache.hasCache {
                toastMessage = "No offline match found"
                toastType = .info
                showToast = true
            }
        }
    }
    
    private func resetForNewScan() {
        recognizedPerson = nil
        status = .enrolled
        faceDetectionManager.reset()
        audioService.stop()
    }

    private func handleRecognize() async {
        guard let sourceImage = lastCapturedImage else {
            status = .notRecognized
            toastMessage = "No image captured. Please try again."
            toastType = .error
            showToast = true
            return
        }

        // Check if there are any loved ones with photos
        let lovedOnesWithPhotos = store.lovedOnes.filter { !$0.photoFileNames.isEmpty }
        if lovedOnesWithPhotos.isEmpty {
            // Try offline cache
            if offlineCache.hasCache {
                await tryOfflineRecognition(image: sourceImage)
                return
            }
            status = .notRecognized
            toastMessage = "No loved ones with photos to compare against"
            toastType = .info
            showToast = true
            return
        }

        status = .extracting
        recognizedPerson = nil
        wasOfflineRecognition = false

        do {
            let result = try await AWSRekognitionService.shared.findMatchingPerson(
                sourceImage: sourceImage,
                lovedOnes: lovedOnesWithPhotos,
                similarityThreshold: 70.0
            )
            
            offlineCache.setOfflineMode(false)

            if result.isMatch, let personId = result.personId {
                // Find the person in the store
                if let person = store.getLovedOne(byId: personId) {
                    recognizedPerson = person
                    status = .recognized
                    toastMessage = "Recognized with \(Int(result.similarity))% confidence"
                    toastType = .success
                    showToast = true
                    
                    // Log to history
                    historyService.logRecognition(
                        person: person,
                        confidence: Double(result.similarity),
                        image: sourceImage,
                        wasOffline: false
                    )
                    
                    // Cache for offline use
                    await offlineCache.cacheFace(person: person, image: sourceImage)
                    
                    // Play audio reminder
                    audioService.speakRecognitionReminder(for: person)
                } else {
                    status = .notRecognized
                }
            } else {
                status = .notRecognized
                toastMessage = "No match found"
                toastType = .info
                showToast = true
            }
        } catch let error as AWSRekognitionService.RekognitionError {
            print("AWS Rekognition error: \(error)")
            // Try offline fallback
            await tryOfflineRecognition(image: sourceImage)
        } catch {
            print("Recognition error: \(error)")
            // Try offline fallback
            await tryOfflineRecognition(image: sourceImage)
        }
    }

    private func handleEnroll(personId: String) async {
        showEnrollSheet = false

        guard let image = lastCapturedImage else {
            toastMessage = "No image captured"
            toastType = .error
            showToast = true
            return
        }

        guard store.getLovedOne(byId: personId) != nil else {
            return
        }

        status = .extracting

        do {
            // First verify there's a face in the image using AWS
            let hasFace = try await AWSRekognitionService.shared.detectFace(in: image)
            
            guard hasFace else {
                status = .enrolled
                toastMessage = "No face detected in frame. Please try again."
                toastType = .error
                showToast = true
                return
            }

            // Save the photo for this person
            let fileName = try await PhotoStorage.shared.savePhoto(image, forPersonId: personId)
            
            // Update the store
            store.addPhotos(toPersonId: personId, fileNames: [fileName])
            store.enrollPerson(id: personId)
            
            status = .enrolled
            toastMessage = "Photo added successfully!"
            toastType = .success
            showToast = true
        } catch let error as AWSRekognitionService.RekognitionError {
            print("Enrollment error: \(error)")
            status = .enrolled
            toastMessage = error.localizedDescription
            toastType = .error
            showToast = true
        } catch {
            print("Enrollment error: \(error)")
            status = .enrolled
            toastMessage = "Failed to save photo: \(error.localizedDescription)"
            toastType = .error
            showToast = true
        }
    }
}

// MARK: - Recognition Result Card

struct RecognitionResultCard: View {
    let person: LovedOne
    @ObservedObject var audioService: AudioService
    @ObservedObject var historyService: RecognitionHistoryService
    var wasOffline: Bool = false

    private var previousRecognitions: [RecognitionEvent] {
        let events = historyService.events(forPersonId: person.id)
        return events.count > 1 ? Array(events.dropFirst()) : []
    }

    private var lastSeenText: String? {
        guard let previousEvent = previousRecognitions.first else { return nil }
        return "Last seen \(previousEvent.timeAgo)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                // Avatar with gradient ring
                ZStack {
                    Circle()
                        .stroke(Theme.Gradients.primary, lineWidth: 3)
                        .frame(width: 70, height: 70)

                    Circle()
                        .fill(Theme.Gradients.subtle)
                        .frame(width: 62, height: 62)

                    Text(person.initials)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.Gradients.primary)
                }

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(person.displayName)
                            .font(.system(size: Theme.FontSize.h2, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)

                        // Offline badge
                        if wasOffline {
                            Text("OFFLINE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.orange)
                                .cornerRadius(Theme.CornerRadius.small)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.accent.opacity(0.6))

                        Text(person.relationship)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }

                    // Last seen info
                    if let lastSeen = lastSeenText {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(lastSeen)
                                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        }
                        .foregroundColor(Theme.Colors.primary)
                    }
                }

                Spacer()

                // Volume Button - Replay audio
                Button(action: {
                    audioService.speakRecognitionReminder(for: person)
                }) {
                    ZStack {
                        Circle()
                            .fill(Theme.Gradients.primary)
                            .frame(width: 44, height: 44)
                            .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 8, y: 4)

                        Image(systemName: audioService.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }

            // Memory Prompt
            if let memoryPrompt = person.memoryPrompt {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.accent)

                    Text(memoryPrompt)
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineSpacing(3)
                }
                .padding(14)
                .background(Theme.Colors.accentLight.opacity(0.5))
                .cornerRadius(Theme.CornerRadius.medium)
            }

            // Audio status indicator
            if audioService.isSpeaking {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Theme.Colors.primary)
                    Text("camera_speaking".localized)
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(Theme.Colors.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.Colors.primaryLight)
                .cornerRadius(Theme.CornerRadius.pill)
            }
        }
        .padding(24)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                .stroke(wasOffline ? Color.orange.opacity(0.5) : Theme.Colors.primary.opacity(0.2), lineWidth: 2)
        )
        .themeShadow(Theme.Shadows.medium)
    }
}

// MARK: - Camera Source Toggle

struct CameraSourceToggle: View {
    @Binding var selectedSource: CameraSource
    let isGlassesConnected: Bool
    let onGlassesSetup: () -> Void

    var body: some View {
        Menu {
            ForEach(CameraSource.allCases) { source in
                Button {
                    if source == .glasses && !isGlassesConnected {
                        onGlassesSetup()
                    } else {
                        selectedSource = source
                    }
                } label: {
                    HStack {
                        Image(systemName: source.icon)
                        Text(source.rawValue)
                        if selectedSource == source {
                            Image(systemName: "checkmark")
                        }
                        if source == .glasses && !isGlassesConnected {
                            Text("(Setup)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedSource.icon)
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.Gradients.primary)
            .cornerRadius(Theme.CornerRadius.pill)
            .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 8, y: 4)
        }
    }
}

// MARK: - Camera Source Status Bar

struct CameraSourceStatusBar: View {
    let activeSource: CameraSource
    let statusMessage: String
    let isGlassesConnected: Bool

    private var statusColor: Color {
        if activeSource == .glasses && isGlassesConnected {
            return Theme.Colors.success
        }
        return Theme.Colors.primary
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: activeSource == .glasses ? "eyeglasses" : "iphone")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(statusColor)
            }

            Text(statusMessage)
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)

            Spacer()

            if activeSource == .glasses {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isGlassesConnected ? Theme.Colors.success : Theme.Colors.warning)
                        .frame(width: 8, height: 8)

                    Text(isGlassesConnected ? "Connected" : "Connecting")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isGlassesConnected ? Theme.Colors.success : Theme.Colors.warning)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(statusColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Glasses Camera Frame View

struct GlassesCameraFrameView: View {
    let image: UIImage?
    @ObservedObject var faceDetectionManager: FaceDetectionManager
    var statusMessage: String?

    var body: some View {
        ZStack {
            // Video frame from glasses
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 400)
                    .clipped()
            } else {
                // Placeholder when no frame
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.9), Color.black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 400)
                    .overlay(
                            VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(Theme.Gradients.primary, lineWidth: 3)
                                    .frame(width: 60, height: 60)

                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.2)
                            }
                            Text("camera_connecting_glasses".localized)
                                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
            }

            // Face detection overlay
            if faceDetectionManager.hasFace {
                FaceDetectionOverlay(
                    faceDetectionManager: faceDetectionManager
                )
            }

            // Status message overlay
            if let message = statusMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.7))
                        )
                        .padding(.bottom, 20)
                }
            }

            // Glasses indicator
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "eyeglasses")
                            .font(.system(size: 12, weight: .medium))
                        Text("GLASSES")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Gradients.primary)
                    .cornerRadius(Theme.CornerRadius.pill)
                    .shadow(color: Theme.Colors.primary.opacity(0.4), radius: 8, y: 2)

                    Spacer()
                }
                .padding(16)

                Spacer()
            }
        }
        .cornerRadius(Theme.CornerRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                .stroke(Theme.Gradients.primary, lineWidth: 3)
        )
        .themeShadow(Theme.Shadows.medium)
    }
}

// MARK: - Face Detection Overlay (extracted for reuse)

struct FaceDetectionOverlay: View {
    @ObservedObject var faceDetectionManager: FaceDetectionManager

    private var borderColor: Color {
        faceDetectionManager.faceStabilityProgress >= 1.0 ? Theme.Colors.success : Theme.Colors.primary
    }

    var body: some View {
        GeometryReader { geometry in
            ForEach(Array(faceDetectionManager.detectedFaces.enumerated()), id: \.offset) { index, faceBoundingBox in
                let rect = convertBoundingBox(faceBoundingBox, in: geometry.size)

                // Face detection frame with animated corners
                ZStack {
                    // Corner brackets
                    FaceFrameCorners(color: borderColor)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }

            // Progress indicator
            if faceDetectionManager.hasFace && faceDetectionManager.faceStabilityProgress < 1.0 {
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView(value: faceDetectionManager.faceStabilityProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: Theme.Colors.primary))
                            .frame(width: 120)

                        Text("camera_hold_still".localized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(Theme.CornerRadius.medium)
                    .padding(.bottom, 50)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func convertBoundingBox(_ boundingBox: CGRect, in size: CGSize) -> CGRect {
        let x = boundingBox.minX * size.width
        let y = (1 - boundingBox.maxY) * size.height
        let width = boundingBox.width * size.width
        let height = boundingBox.height * size.height

        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Face Frame Corners

struct FaceFrameCorners: View {
    let color: Color
    let cornerLength: CGFloat = 24
    let lineWidth: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            Path { path in
                // Top-left corner
                path.move(to: CGPoint(x: 0, y: cornerLength))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: cornerLength, y: 0))

                // Top-right corner
                path.move(to: CGPoint(x: width - cornerLength, y: 0))
                path.addLine(to: CGPoint(x: width, y: 0))
                path.addLine(to: CGPoint(x: width, y: cornerLength))

                // Bottom-right corner
                path.move(to: CGPoint(x: width, y: height - cornerLength))
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: width - cornerLength, y: height))

                // Bottom-left corner
                path.move(to: CGPoint(x: cornerLength, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: 0, y: height - cornerLength))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

#Preview {
    RecognizeView(store: AppStore.shared, selectedTab: .constant(.recognize))
}
