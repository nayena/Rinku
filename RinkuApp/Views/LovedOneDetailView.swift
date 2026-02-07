import SwiftUI
import PhotosUI

struct LovedOneDetailView: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    
    let lovedOne: LovedOne
    
    @State private var isEditing = false
    @State private var editedFullName: String = ""
    @State private var editedFamiliarName: String = ""
    @State private var editedRelationship: String = ""
    @State private var editedMemoryPrompt: String = ""
    @State private var editedAudioFileName: String?

    @State private var showDeleteAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .success
    
    // Photo management
    @State private var photos: [UIImage] = []
    @State private var isLoadingPhotos = true
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showAddPhotoSheet = false
    @State private var photoToDelete: Int? = nil
    @State private var showDeletePhotoAlert = false
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with back button
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.system(size: Theme.FontSize.body))
                            .foregroundColor(Theme.Colors.primary)
                        }
                        
                        Spacer()
                        
                        Button(isEditing ? "Done" : "Edit") {
                            if isEditing {
                                saveChanges()
                            }
                            withAnimation {
                                isEditing.toggle()
                            }
                        }
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundColor(Theme.Colors.primary)
                    }
                    
                    // Profile Header
                    VStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.Colors.primary, Theme.Colors.primaryDark],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Text(lovedOne.initials)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        // Name and relationship
                        if isEditing {
                            VStack(spacing: 4) {
                                Text("Editing")
                                    .font(.system(size: Theme.FontSize.caption))
                                    .foregroundColor(Theme.Colors.primary)
                                Text(lovedOne.displayName)
                                    .font(.system(size: Theme.FontSize.h1, weight: .bold))
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                        } else {
                            VStack(spacing: 4) {
                                Text(lovedOne.displayName)
                                    .font(.system(size: Theme.FontSize.h1, weight: .bold))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                
                                Text(lovedOne.relationship)
                                    .font(.system(size: Theme.FontSize.body))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                        
                        // Status badges
                        HStack(spacing: 12) {
                            StatusBadge(
                                icon: "photo.fill",
                                text: "\(lovedOne.photoCount) photo\(lovedOne.photoCount == 1 ? "" : "s")",
                                color: lovedOne.hasPhotos ? Theme.Colors.success : Theme.Colors.warning
                            )
                            
                            StatusBadge(
                                icon: lovedOne.enrolled ? "checkmark.circle.fill" : "circle",
                                text: lovedOne.enrolled ? "Enrolled" : "Not enrolled",
                                color: lovedOne.enrolled ? Theme.Colors.success : Theme.Colors.textSecondary
                            )
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Edit Form or Display
                    if isEditing {
                        editForm
                    } else {
                        displayInfo
                    }
                    
                    // Photos Section
                    photosSection
                    
                    // Delete Button
                    Button {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Loved One")
                        }
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundColor(Theme.Colors.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.Colors.dangerLight)
                        .cornerRadius(Theme.CornerRadius.medium)
                    }
                    .padding(.top, 16)
                    
                    
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .scrollContentBackground(.hidden)
            
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
        .navigationBarHidden(true)
        .onAppear {
            loadInitialState()
        }
        .alert("Delete Loved One", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteLovedOne()
            }
        } message: {
            Text("Are you sure you want to delete \(lovedOne.displayName)? This will remove all their photos and cannot be undone.")
        }
        .alert("Delete Photo", isPresented: $showDeletePhotoAlert) {
            Button("Cancel", role: .cancel) { 
                photoToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let index = photoToDelete {
                    deletePhoto(at: index)
                }
            }
        } message: {
            Text("Are you sure you want to delete this photo?")
        }
        .sheet(isPresented: $showAddPhotoSheet) {
            addPhotoSheet
        }
    }
    
    // MARK: - Display Info View
    
    private var displayInfo: some View {
        VStack(spacing: 16) {
            // Full Name
            InfoRow(label: "Full Name", value: lovedOne.fullName)
            
            // Familiar Name
            if let familiarName = lovedOne.familiarName {
                InfoRow(label: "Familiar Name", value: familiarName)
            }
            
            // Relationship
            InfoRow(label: "Relationship", value: lovedOne.relationship)
            
            // Memory Prompt
            if let memoryPrompt = lovedOne.memoryPrompt {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Memory Prompt")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.Colors.textSecondary)

                    Text(memoryPrompt)
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.primaryLight)
                        .cornerRadius(Theme.CornerRadius.medium)
                }
            }

            // Voice Recording (display only)
            if lovedOne.audioFileName != nil {
                VoiceRecorderView(personId: lovedOne.id, audioFileName: .constant(lovedOne.audioFileName))
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
    
    // MARK: - Edit Form View
    
    private var editForm: some View {
        VStack(spacing: 16) {
            RinkuTextField(
                label: "Full Name",
                text: $editedFullName,
                placeholder: "e.g., Gabriela Martinez",
                isRequired: true
            )
            
            RinkuTextField(
                label: "Familiar Name",
                text: $editedFamiliarName,
                placeholder: "e.g., Gabi (optional)",
                helperText: "The name you usually call them"
            )
            
            RinkuTextField(
                label: "Relationship",
                text: $editedRelationship,
                placeholder: "e.g., Daughter",
                isRequired: true
            )
            
            RinkuTextField(
                label: "Memory Prompt",
                text: $editedMemoryPrompt,
                placeholder: "e.g., She loves painting...",
                helperText: "A gentle reminder about this person",
                isMultiline: true
            )

            VoiceRecorderView(personId: lovedOne.id, audioFileName: $editedAudioFileName)
        }
    }
    
    // MARK: - Photos Section
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos")
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    showAddPhotoSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(Theme.Colors.primary)
                }
            }
            
            if isLoadingPhotos {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 32)
            } else if photos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Text("No photos yet")
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Button {
                        showAddPhotoSheet = true
                    } label: {
                        Text("Add Photos")
                            .font(.system(size: Theme.FontSize.body, weight: .medium))
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 100)
                                .clipped()
                                .cornerRadius(8)
                            
                            // Delete button
                            Button {
                                photoToDelete = index
                                showDeletePhotoAlert = true
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            .padding(4)
                        }
                    }
                }
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
    
    // MARK: - Add Photo Sheet
    
    private var addPhotoSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.Colors.primary)
                        
                        Text("Select Photos")
                            .font(.system(size: Theme.FontSize.body, weight: .medium))
                            .foregroundColor(Theme.Colors.primary)
                        
                        Text("Choose clear photos of their face")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                    .background(Theme.Colors.primaryLight)
                    .cornerRadius(Theme.CornerRadius.medium)
                }
                .onChange(of: selectedItems) { _, newItems in
                    Task {
                        await addSelectedPhotos(newItems)
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .navigationTitle("Add Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showAddPhotoSheet = false
                        selectedItems = []
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadInitialState() {
        // Load edit fields
        editedFullName = lovedOne.fullName
        editedFamiliarName = lovedOne.familiarName ?? ""
        editedRelationship = lovedOne.relationship
        editedMemoryPrompt = lovedOne.memoryPrompt ?? ""
        editedAudioFileName = lovedOne.audioFileName

        // Load photos
        Task {
            await loadPhotos()
        }
    }
    
    private func loadPhotos() async {
        isLoadingPhotos = true
        var loadedPhotos: [UIImage] = []
        
        for fileName in lovedOne.photoFileNames {
            if let image = await PhotoStorage.shared.loadPhoto(fileName: fileName) {
                loadedPhotos.append(image)
            }
        }
        
        await MainActor.run {
            photos = loadedPhotos
            isLoadingPhotos = false
        }
    }
    
    private func saveChanges() {
        var updated = lovedOne
        updated.fullName = editedFullName.trimmingCharacters(in: .whitespaces)
        updated.familiarName = editedFamiliarName.isEmpty ? nil : editedFamiliarName.trimmingCharacters(in: .whitespaces)
        updated.relationship = editedRelationship.trimmingCharacters(in: .whitespaces)
        updated.memoryPrompt = editedMemoryPrompt.isEmpty ? nil : editedMemoryPrompt.trimmingCharacters(in: .whitespaces)
        updated.audioFileName = editedAudioFileName

        store.updateLovedOne(updated)
        
        toastMessage = "Changes saved"
        toastType = .success
        showToast = true
    }
    
    private func deleteLovedOne() {
        store.deleteLovedOne(id: lovedOne.id)
        dismiss()
    }
    
    private func deletePhoto(at index: Int) {
        guard index < lovedOne.photoFileNames.count else { return }
        
        let fileName = lovedOne.photoFileNames[index]
        
        Task {
            // Delete from local storage
            await PhotoStorage.shared.deletePhoto(fileName: fileName)
            
            // Update loved one
            var updated = lovedOne
            updated.photoFileNames.remove(at: index)
            updated.enrolled = !updated.photoFileNames.isEmpty
            
            await MainActor.run {
                store.updateLovedOne(updated)
                photos.remove(at: index)
                photoToDelete = nil
                
                toastMessage = "Photo deleted"
                toastType = .success
                showToast = true
            }
        }
    }
    
    private func addSelectedPhotos(_ items: [PhotosPickerItem]) async {
        var newImages: [UIImage] = []
        
        for item in items {
            if let image = await UIImage.from(item) {
                newImages.append(image)
            }
        }
        
        guard !newImages.isEmpty else { return }
        
        do {
            // Save photos to local storage
            let fileNames = try await PhotoStorage.shared.savePhotos(newImages, forPersonId: lovedOne.id)
            
            // Upload to Supabase if signed in
            let authService = AuthService.shared
            if authService.isSignedIn {
                let supabaseService = SupabaseService.shared
                for image in newImages {
                    _ = try? await supabaseService.uploadPhoto(image: image, lovedOneId: lovedOne.id)
                }
            }
            
            // Update loved one
            var updated = lovedOne
            updated.photoFileNames.append(contentsOf: fileNames)
            updated.enrolled = true
            
            await MainActor.run {
                store.updateLovedOne(updated)
                photos.append(contentsOf: newImages)
                selectedItems = []
                showAddPhotoSheet = false
                
                toastMessage = "\(newImages.count) photo(s) added"
                toastType = .success
                showToast = true
            }
        } catch {
            await MainActor.run {
                toastMessage = "Failed to save photos"
                toastType = .error
                showToast = true
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(Theme.Colors.textSecondary)
            
            Text(value)
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: Theme.FontSize.caption))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.pill)
    }
}

#Preview {
    LovedOneDetailView(
        store: AppStore.shared,
        lovedOne: LovedOne(
            id: "1",
            fullName: "Gabriela Martinez",
            familiarName: "Gabi",
            relationship: "Daughter",
            memoryPrompt: "She loves painting and always brings flowers on Sundays.",
            enrolled: true,
            photoFileNames: []
        )
    )
}
