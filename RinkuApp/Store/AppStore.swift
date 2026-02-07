import Foundation
import SwiftUI
import Combine

@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published var lovedOnes: [LovedOne] = []
    @Published var permissions = PermissionState()
    @Published var recognitionState = RecognitionState()
    @Published var recognizedPerson: LovedOne? = nil
    @Published var isSyncing = false
    @Published var syncError: String?

    private let storageKeyPrefix = "loved_ones_data_"  // Per-user storage
    private let authService = AuthService.shared
    private let supabaseService = SupabaseService.shared
    private let familyService = FamilyService.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Get the storage key for the current user (or a default for guests)
    private var currentStorageKey: String {
        if let userId = authService.currentUser?.id {
            return storageKeyPrefix + userId
        }
        return storageKeyPrefix + "guest"
    }

    private init() {
        setupAuthObserver()
        setupFamilyObserver()
        // Load initial data if already signed in
        if authService.isSignedIn {
            loadLovedOnes()
        }
    }
    
    // MARK: - Auth Observer
    
    private func setupAuthObserver() {
        // Watch for auth state changes
        authService.$isSignedIn
            .dropFirst() // Skip initial value
            .sink { [weak self] isSignedIn in
                Task { @MainActor in
                    if isSignedIn {
                        // Clear previous user's data and load new user's data
                        self?.clearLocalData()
                        self?.loadLovedOnes()
                        // Load family first, then sync
                        await self?.familyService.loadMyFamily()
                        await self?.syncWithSupabase()
                    } else {
                        // User signed out - clear all local data
                        self?.handleSignOut()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Handle user sign out - clear all local data
    private func handleSignOut() {
        print("🚪 User signed out - clearing local data")
        lovedOnes = []
        recognizedPerson = nil
        syncError = nil
        // Don't delete the stored data - just clear from memory
        // This way if the same user signs back in, their local cache is still there
    }
    
    /// Clear in-memory data (called before loading new user)
    private func clearLocalData() {
        print("🧹 Clearing in-memory data for new user session")
        lovedOnes = []
        recognizedPerson = nil
        syncError = nil
    }
    
    // MARK: - Family Observer
    
    private func setupFamilyObserver() {
        // Watch for family changes to trigger sync
        familyService.$currentFamily
            .dropFirst() // Skip initial value
            .sink { [weak self] family in
                Task { @MainActor in
                    // Resync when family changes
                    await self?.syncWithSupabase()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Get the family ID to use for new loved ones (if user is in a family)
    var currentFamilyId: String? {
        familyService.currentFamily?.id
    }
    
    /// Whether user is in a family
    var isInFamily: Bool {
        familyService.isInFamily
    }

    // MARK: - Local Persistence

    private func loadLovedOnes() {
        let key = currentStorageKey
        print("📂 Loading loved ones for key: \(key)")
        
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([LovedOne].self, from: data) else {
            // Start with empty list for new users - no sample data
            print("📂 No cached data found for user, starting fresh")
            lovedOnes = []
            return
        }
        lovedOnes = decoded
        print("📂 Loaded \(lovedOnes.count) loved ones from local cache")
    }

    private func saveLovedOnes() {
        let key = currentStorageKey
        if let data = try? JSONEncoder().encode(lovedOnes) {
            UserDefaults.standard.set(data, forKey: key)
            print("💾 Saved \(lovedOnes.count) loved ones to key: \(key)")
        }
    }
    
    /// Clear all local data for the current user (useful for debugging)
    func clearAllUserData() {
        let key = currentStorageKey
        UserDefaults.standard.removeObject(forKey: key)
        lovedOnes = []
        print("🗑️ Cleared all data for key: \(key)")
    }
    
    // MARK: - Supabase Sync
    
    /// Sync data with Supabase (fetch remote data, download photos, and merge)
    func syncWithSupabase() async {
        guard authService.isSignedIn else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Fetch loved ones from Supabase
            let remoteLovedOnes = try await supabaseService.fetchLovedOnes()
            
            // Process each remote loved one
            var mergedLovedOnes: [LovedOne] = []
            
            for dto in remoteLovedOnes {
                let lovedOneId = dto.id ?? ""

                // Check if we have local photos for this person
                // Use case-insensitive comparison since PostgreSQL normalizes UUIDs to lowercase
                // but Swift's UUID().uuidString generates uppercase
                var localPhotoFileNames = lovedOnes.first { $0.id.caseInsensitiveCompare(lovedOneId) == .orderedSame }?.photoFileNames ?? []
                
                // Fetch photo records from Supabase
                if let photos = try? await supabaseService.fetchPhotos(forLovedOneId: lovedOneId) {
                    // Download any photos we don't have locally
                    for photo in photos {
                        let localFileName = "\(lovedOneId)_\(photo.fileName)"
                        
                        // Check if we already have this photo locally
                        let exists = await PhotoStorage.shared.photoExists(fileName: localFileName)
                        
                        if !exists {
                            // Download and save locally
                            do {
                                let image = try await supabaseService.downloadPhoto(storagePath: photo.storagePath)
                                let savedFileName = try await PhotoStorage.shared.savePhoto(image, forPersonId: lovedOneId)
                                if !localPhotoFileNames.contains(savedFileName) {
                                    localPhotoFileNames.append(savedFileName)
                                }
                                print("Downloaded photo: \(photo.fileName)")
                            } catch {
                                print("Failed to download photo \(photo.fileName): \(error)")
                            }
                        } else if !localPhotoFileNames.contains(localFileName) {
                            localPhotoFileNames.append(localFileName)
                        }
                    }
                }
                
                let lovedOne = dto.toLovedOne(photoFileNames: localPhotoFileNames)
                mergedLovedOnes.append(lovedOne)
            }
            
            // Handle local-only entries (upload them to Supabase)
            // Use case-insensitive comparison for UUID matching
            for local in lovedOnes {
                if !mergedLovedOnes.contains(where: { $0.id.caseInsensitiveCompare(local.id) == .orderedSame }) {
                    // This is a local-only entry, upload it to Supabase
                    let dto = LovedOneDTO.from(local)
                    if let created = try? await supabaseService.createLovedOne(dto) {
                        let newId = created.id ?? local.id
                        // Create new LovedOne with the server-assigned ID
                        let updatedLocal = LovedOne(
                            id: newId,
                            fullName: local.fullName,
                            familiarName: local.familiarName,
                            relationship: local.relationship,
                            memoryPrompt: local.memoryPrompt,
                            audioFileName: local.audioFileName,
                            enrolled: local.enrolled,
                            photoFileNames: local.photoFileNames,
                            familyId: local.familyId
                        )
                        mergedLovedOnes.append(updatedLocal)

                        // Also upload the photos for this local entry
                        for fileName in local.photoFileNames {
                            if let image = await PhotoStorage.shared.loadPhoto(fileName: fileName) {
                                _ = try? await supabaseService.uploadPhoto(image: image, lovedOneId: newId)
                            }
                        }
                    } else {
                        // Upload failed - preserve the local entry so we don't lose data
                        mergedLovedOnes.append(local)
                    }
                }
            }
            
            lovedOnes = mergedLovedOnes
            saveLovedOnes()
            isSyncing = false
            
            print("Sync complete: \(lovedOnes.count) loved ones")
        } catch {
            syncError = error.localizedDescription
            isSyncing = false
            print("Sync error: \(error)")
        }
    }
    
    /// Upload a loved one to Supabase
    private func uploadToSupabase(_ lovedOne: LovedOne) async {
        guard authService.isSignedIn else { return }

        do {
            let dto = LovedOneDTO.from(lovedOne)
            let created = try await supabaseService.createLovedOne(dto)

            // Update local ID if server returned a different one (e.g. case normalization)
            if let serverId = created.id,
               serverId.lowercased() != lovedOne.id.lowercased(),
               let index = lovedOnes.firstIndex(where: { $0.id == lovedOne.id }) {
                lovedOnes[index] = LovedOne(
                    id: serverId.lowercased(),
                    fullName: lovedOne.fullName,
                    familiarName: lovedOne.familiarName,
                    relationship: lovedOne.relationship,
                    memoryPrompt: lovedOne.memoryPrompt,
                    audioFileName: lovedOne.audioFileName,
                    enrolled: lovedOne.enrolled,
                    photoFileNames: lovedOne.photoFileNames,
                    familyId: lovedOne.familyId
                )
                saveLovedOnes()
            }
        } catch {
            print("Failed to upload to Supabase: \(error)")
        }
    }
    
    /// Update loved one in Supabase
    private func updateInSupabase(_ lovedOne: LovedOne) async {
        guard authService.isSignedIn else { return }
        
        do {
            let dto = LovedOneDTO.from(lovedOne)
            try await supabaseService.updateLovedOne(dto)
        } catch {
            print("Failed to update in Supabase: \(error)")
        }
    }
    
    /// Delete loved one from Supabase
    private func deleteFromSupabase(id: String) async {
        guard authService.isSignedIn else { return }
        
        do {
            try await supabaseService.deleteLovedOne(id: id)
        } catch {
            print("Failed to delete from Supabase: \(error)")
        }
    }

    // MARK: - Loved Ones Management

    /// Add a loved one with photos (new flow)
    /// If user is in a family, the loved one is automatically added to the family
    func addLovedOne(
        id: String = UUID().uuidString.lowercased(),
        fullName: String,
        familiarName: String?,
        relationship: String,
        memoryPrompt: String?,
        audioFileName: String? = nil,
        photoFileNames: [String] = [],
        enrolled: Bool = false
    ) {
        // If user is in a family, automatically add to family
        let familyId = currentFamilyId

        let newPerson = LovedOne(
            id: id,
            fullName: fullName,
            familiarName: familiarName?.isEmpty == true ? nil : familiarName,
            relationship: relationship,
            memoryPrompt: memoryPrompt?.isEmpty == true ? nil : memoryPrompt,
            audioFileName: audioFileName,
            enrolled: enrolled,
            photoFileNames: photoFileNames,
            familyId: familyId
        )
        lovedOnes.append(newPerson)
        saveLovedOnes()
        
        // Sync to Supabase
        Task {
            await uploadToSupabase(newPerson)
        }
    }

    func getLovedOne(byId id: String) -> LovedOne? {
        lovedOnes.first { $0.id == id }
    }

    func updateLovedOne(_ lovedOne: LovedOne) {
        if let index = lovedOnes.firstIndex(where: { $0.id == lovedOne.id }) {
            lovedOnes[index] = lovedOne
            saveLovedOnes()
            
            // Sync to Supabase
            Task {
                await updateInSupabase(lovedOne)
            }
        }
    }

    func deleteLovedOne(id: String) {
        lovedOnes.removeAll { $0.id == id }
        saveLovedOnes()

        // Delete from Supabase
        Task {
            await deleteFromSupabase(id: id)
        }
        
        // Also delete local photos
        Task {
            await PhotoStorage.shared.deleteAllPhotos(forPersonId: id)
        }
    }

    func enrollPerson(id: String) {
        if let index = lovedOnes.firstIndex(where: { $0.id == id }) {
            lovedOnes[index].enrolled = true
            saveLovedOnes()
            
            // Sync to Supabase
            Task {
                await updateInSupabase(lovedOnes[index])
            }
        }
    }

    func addPhotos(toPersonId id: String, fileNames: [String]) {
        if let index = lovedOnes.firstIndex(where: { $0.id == id }) {
            lovedOnes[index].photoFileNames.append(contentsOf: fileNames)
            saveLovedOnes()
            // Note: Photos are stored locally, not synced to Supabase storage yet
        }
    }

    // MARK: - Permissions

    func grantPermission(_ type: PermissionType) {
        switch type {
        case .camera:
            permissions.camera = true
        case .microphone:
            permissions.microphone = true
        }
    }

    var hasAllPermissions: Bool {
        permissions.allGranted
    }

    // MARK: - Recognition

    func setRecognizedPerson(_ person: LovedOne?) {
        recognizedPerson = person
    }
}

enum PermissionType {
    case camera
    case microphone
}
