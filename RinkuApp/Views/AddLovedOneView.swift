import SwiftUI
import PhotosUI

struct AddLovedOneView: View {
    @ObservedObject var store: AppStore
    @Binding var selectedTab: TabItem
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var fullName = ""
    @State private var familiarName = ""
    @State private var relationship = ""
    @State private var memoryPrompt = ""
    @State private var audioFileName: String?
    @State private var personId = UUID().uuidString.lowercased()

    @State private var fullNameError: String? = nil
    @State private var relationshipError: String? = nil

    @State private var fullNameTouched = false
    @State private var relationshipTouched = false

    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .success

    // Photo picker state
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isProcessingPhotos = false
    @State private var photoError: String? = nil

    // Focus state for keyboard dismissal
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case fullName, familiarName, relationship, memoryPrompt
    }

    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !relationship.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedImages.isEmpty
    }

    private func validate() -> Bool {
        var valid = true

        if fullName.trimmingCharacters(in: .whitespaces).isEmpty {
            fullNameError = "add_loved_one_error_name".localized
            valid = false
        } else {
            fullNameError = nil
        }

        if relationship.trimmingCharacters(in: .whitespaces).isEmpty {
            relationshipError = "add_loved_one_error_relationship".localized
            valid = false
        } else {
            relationshipError = nil
        }

        if selectedImages.isEmpty {
            photoError = "add_loved_one_error_photo".localized
            valid = false
        } else {
            photoError = nil
        }

        return valid
    }

    private func handleSubmit() {
        fullNameTouched = true
        relationshipTouched = true

        if validate() {
            isProcessingPhotos = true

            Task {
                await saveLovedOneWithPhotos()
            }
        }
    }

    private func saveLovedOneWithPhotos() async {
        let authService = AuthService.shared
        let supabaseService = SupabaseService.shared

        do {
            // Save photos to local storage first (for fast local access)
            let fileNames = try await PhotoStorage.shared.savePhotos(selectedImages, forPersonId: personId)

            // Verify faces exist in photos using AWS (if configured)
            var validPhotoCount = fileNames.count
            if AWSConfig.isConfigured {
                validPhotoCount = 0
                for fileName in fileNames {
                    if let image = await PhotoStorage.shared.loadPhoto(fileName: fileName) {
                        do {
                            let hasFace = try await AWSRekognitionService.shared.detectFace(in: image)
                            if hasFace {
                                validPhotoCount += 1
                            }
                        } catch {
                            print("Face detection check failed: \(error)")
                            // Still count it if we can't verify
                            validPhotoCount += 1
                        }
                    }
                }
            }

            // Add loved one to store (this also syncs metadata to Supabase)
            await MainActor.run {
                store.addLovedOne(
                    id: personId,
                    fullName: fullName.trimmingCharacters(in: .whitespaces),
                    familiarName: familiarName.isEmpty ? nil : familiarName.trimmingCharacters(in: .whitespaces),
                    relationship: relationship.trimmingCharacters(in: .whitespaces),
                    memoryPrompt: memoryPrompt.isEmpty ? nil : memoryPrompt.trimmingCharacters(in: .whitespaces),
                    audioFileName: audioFileName,
                    photoFileNames: fileNames,
                    enrolled: validPhotoCount > 0
                )
            }
            
            // Upload photos to Supabase Storage if signed in
            if authService.isSignedIn {
                var uploadedCount = 0
                for image in selectedImages {
                    do {
                        _ = try await supabaseService.uploadPhoto(image: image, lovedOneId: personId)
                        uploadedCount += 1
                    } catch {
                        print("Failed to upload photo to Supabase: \(error)")
                    }
                }
                print("Uploaded \(uploadedCount) photos to Supabase")
            }

            await MainActor.run {
                isProcessingPhotos = false

                if AWSConfig.isConfigured {
                    let syncMsg = authService.isSignedIn ? " (synced to cloud)" : ""
                    toastMessage = "Added with \(validPhotoCount) photo(s) ready for recognition!\(syncMsg)"
                    toastType = .success
                } else {
                    toastMessage = "Added! Configure AWS credentials to enable face recognition."
                    toastType = .info
                }
                showToast = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    selectedTab = .lovedOnes
                    resetForm()
                }
            }
        } catch {
            await MainActor.run {
                isProcessingPhotos = false
                toastMessage = "Failed to save photos: \(error.localizedDescription)"
                toastType = .error
                showToast = true
            }
        }
    }

    private func resetForm() {
        fullName = ""
        familiarName = ""
        relationship = ""
        memoryPrompt = ""
        fullNameError = nil
        relationshipError = nil
        photoError = nil
        fullNameTouched = false
        relationshipTouched = false
        showToast = false
        selectedItems = []
        selectedImages = []
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header with gradient accent
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("add_loved_one_title".localized)
                                .font(.system(size: Theme.FontSize.h1, weight: .bold))
                                .foregroundColor(Theme.Colors.textPrimary)

                            Text("add_loved_one_subtitle".localized)
                                .font(.system(size: Theme.FontSize.caption))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Spacer()

                        ZStack {
                            Circle()
                                .fill(Theme.Gradients.subtle)
                                .frame(width: 48, height: 48)

                            Image(systemName: "person.fill.badge.plus")
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.Gradients.primary)
                        }
                    }

                    // Photo Picker Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            HStack(spacing: 4) {
                                Text("add_loved_one_photos".localized)
                                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textPrimary)

                                Text("*")
                                    .foregroundColor(Theme.Colors.danger)
                            }

                            Spacer()

                            if !selectedImages.isEmpty {
                                Text("\(selectedImages.count) photo\(selectedImages.count == 1 ? "" : "s")")
                                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                                    .foregroundColor(Theme.Colors.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Theme.Colors.primaryLight)
                                    .cornerRadius(Theme.CornerRadius.pill)
                            }
                        }

                        // Photo Grid
                        if !selectedImages.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 10) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 100)
                                            .clipped()
                                            .cornerRadius(Theme.CornerRadius.medium)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                                    .stroke(Theme.Colors.primary.opacity(0.3), lineWidth: 2)
                                            )

                                        // Remove button with gradient
                                        Button {
                                            selectedImages.remove(at: index)
                                            if index < selectedItems.count {
                                                selectedItems.remove(at: index)
                                            }
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(Theme.Colors.danger)
                                                    .frame(width: 24, height: 24)

                                                Image(systemName: "xmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                            .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                        }

                        // Photo Picker Button
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: 10,
                            matching: .images
                        ) {
                            HStack(spacing: 10) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 18, weight: .medium))
                                Text(selectedImages.isEmpty ? "add_loved_one_add_photos".localized : "add_loved_one_add_more".localized)
                                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                    .stroke(Theme.Gradients.primary, lineWidth: 2)
                                    .background(Theme.Colors.primaryLight.cornerRadius(Theme.CornerRadius.medium))
                            )
                            .foregroundColor(Theme.Colors.primary)
                        }
                        .onChange(of: selectedItems) { _, newItems in
                            Task {
                                await loadSelectedPhotos(newItems)
                            }
                        }

                        if let error = photoError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 14))
                                Text(error)
                                    .font(.system(size: Theme.FontSize.caption))
                            }
                            .foregroundColor(Theme.Colors.danger)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.accent)

                            Text("add_loved_one_photo_tip".localized)
                                .font(.system(size: Theme.FontSize.caption))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineSpacing(2)
                        }
                        .padding(12)
                        .background(Theme.Colors.accentLight.opacity(0.5))
                        .cornerRadius(Theme.CornerRadius.small)
                    }
                    .padding(20)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.large)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                            .stroke(photoError != nil ? Theme.Colors.danger : Theme.Colors.borderLight, lineWidth: 1)
                    )
                    .themeShadow(Theme.Shadows.small)

                    // Form Section
                    VStack(spacing: 20) {
                        RinkuTextField(
                            label: "add_loved_one_full_name".localized,
                            text: $fullName,
                            placeholder: "add_loved_one_full_name_placeholder".localized,
                            errorText: fullNameTouched ? fullNameError : nil,
                            isRequired: true,
                            isFocused: focusedField == .fullName,
                            onTap: { focusedField = .fullName }
                        )
                        .onChange(of: fullName) { _, _ in
                            if fullNameTouched { _ = validate() }
                        }

                        RinkuTextField(
                            label: "add_loved_one_familiar_name".localized,
                            text: $familiarName,
                            placeholder: "add_loved_one_familiar_name_placeholder".localized,
                            isFocused: focusedField == .familiarName,
                            onTap: { focusedField = .familiarName }
                        )

                        RinkuTextField(
                            label: "add_loved_one_relationship".localized,
                            text: $relationship,
                            placeholder: "add_loved_one_relationship_placeholder".localized,
                            errorText: relationshipTouched ? relationshipError : nil,
                            isRequired: true,
                            isFocused: focusedField == .relationship,
                            onTap: { focusedField = .relationship }
                        )
                        .onChange(of: relationship) { _, _ in
                            if relationshipTouched { _ = validate() }
                        }

                        RinkuTextField(
                            label: "add_loved_one_memory_prompt".localized,
                            text: $memoryPrompt,
                            placeholder: "add_loved_one_memory_prompt_placeholder".localized,
                            isMultiline: true,
                            isFocused: focusedField == .memoryPrompt,
                            onTap: { focusedField = .memoryPrompt }
                        )

                        VoiceRecorderView(personId: personId, audioFileName: $audioFileName)
                    }

                    // Actions
                    VStack(spacing: 14) {
                        RinkuButton(
                            title: "action_save".localized,
                            icon: "checkmark",
                            variant: .primary,
                            size: .large,
                            isLoading: isProcessingPhotos,
                            isDisabled: !isFormValid
                        ) {
                            handleSubmit()
                        }

                        RinkuButton(
                            title: "action_cancel".localized,
                            variant: .ghost,
                            size: .medium,
                            isDisabled: isProcessingPhotos
                        ) {
                            selectedTab = .lovedOnes
                            resetForm()
                        }
                    }
                    .padding(.top, 8)

                    
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                focusedField = nil
            }

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
        }
        .id(languageManager.currentLanguage) // Force refresh when language changes
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []

        for item in items {
            if let image = await UIImage.from(item) {
                images.append(image)
            }
        }

        await MainActor.run {
            selectedImages = images
            if !images.isEmpty {
                photoError = nil
            }
        }
    }
}

#Preview {
    AddLovedOneView(store: AppStore.shared, selectedTab: .constant(.add))
}
