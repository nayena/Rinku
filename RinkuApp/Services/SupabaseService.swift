import Foundation
import UIKit
import Combine

/// Service for Supabase database and storage operations
@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    @Published var isSyncing = false
    @Published var lastSyncError: Error?
    
    private let authService = AuthService.shared
    
    private init() {}
    
    // MARK: - Loved Ones CRUD
    
    /// Fetch all loved ones for the current user
    func fetchLovedOnes() async throws -> [LovedOneDTO] {
        guard let token = await authService.getAccessToken() else {
            throw SupabaseError.notAuthenticated
        }
        
        let url = SupabaseConfig.restURL.appendingPathComponent("loved_ones")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SupabaseError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([LovedOneDTO].self, from: data)
    }
    
    /// Create a new loved one
    func createLovedOne(_ lovedOne: LovedOneDTO) async throws -> LovedOneDTO {
        guard let token = await authService.getAccessToken(),
              let userId = authService.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let url = SupabaseConfig.restURL.appendingPathComponent("loved_ones")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        var lovedOneWithUser = lovedOne
        lovedOneWithUser.userId = userId
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(lovedOneWithUser)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw SupabaseError.createFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let results = try decoder.decode([LovedOneDTO].self, from: data)
        
        guard let created = results.first else {
            throw SupabaseError.createFailed
        }
        
        return created
    }
    
    /// Update a loved one
    func updateLovedOne(_ lovedOne: LovedOneDTO) async throws {
        guard let token = await authService.getAccessToken(),
              let id = lovedOne.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let url = SupabaseConfig.restURL.appendingPathComponent("loved_ones")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(lovedOne)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw SupabaseError.updateFailed
        }
    }
    
    /// Delete a loved one
    func deleteLovedOne(id: String) async throws {
        guard let token = await authService.getAccessToken() else {
            throw SupabaseError.notAuthenticated
        }
        
        let url = SupabaseConfig.restURL.appendingPathComponent("loved_ones")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw SupabaseError.deleteFailed
        }
    }
    
    // MARK: - Photos
    
    /// Upload a photo to storage
    func uploadPhoto(image: UIImage, lovedOneId: String) async throws -> PhotoDTO {
        guard let token = await authService.getAccessToken(),
              let userId = authService.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw SupabaseError.uploadFailed
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        let storagePath = "\(userId)/\(lovedOneId)/\(fileName)"
        
        // Upload to storage
        let uploadURL = SupabaseConfig.storageURL
            .appendingPathComponent("object")
            .appendingPathComponent(SupabaseConfig.photosBucket)
            .appendingPathComponent(storagePath)
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = imageData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SupabaseError.uploadFailed
        }
        
        // Create photo record in database
        let photo = PhotoDTO(
            id: nil,
            lovedOneId: lovedOneId,
            userId: userId,
            storagePath: storagePath,
            fileName: fileName,
            createdAt: nil
        )
        
        return try await createPhotoRecord(photo)
    }
    
    /// Create photo record in database
    private func createPhotoRecord(_ photo: PhotoDTO) async throws -> PhotoDTO {
        guard let token = await authService.getAccessToken() else {
            throw SupabaseError.notAuthenticated
        }
        
        let url = SupabaseConfig.restURL.appendingPathComponent("photos")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(photo)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw SupabaseError.createFailed
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let results = try decoder.decode([PhotoDTO].self, from: data)
        
        guard let created = results.first else {
            throw SupabaseError.createFailed
        }
        
        return created
    }
    
    /// Fetch photos for a loved one
    func fetchPhotos(forLovedOneId lovedOneId: String) async throws -> [PhotoDTO] {
        guard let token = await authService.getAccessToken() else {
            throw SupabaseError.notAuthenticated
        }
        
        let url = SupabaseConfig.restURL.appendingPathComponent("photos")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "loved_one_id", value: "eq.\(lovedOneId)"),
            URLQueryItem(name: "select", value: "*")
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SupabaseError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([PhotoDTO].self, from: data)
    }
    
    /// Get download URL for a photo
    func getPhotoURL(storagePath: String) async throws -> URL {
        guard let token = await authService.getAccessToken() else {
            throw SupabaseError.notAuthenticated
        }
        
        // Create signed URL for private bucket
        let signURL = SupabaseConfig.storageURL
            .appendingPathComponent("object/sign")
            .appendingPathComponent(SupabaseConfig.photosBucket)
            .appendingPathComponent(storagePath)
        
        var request = URLRequest(url: signURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ["expiresIn": 3600] // 1 hour
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let signedURL = json["signedURL"] as? String else {
            throw SupabaseError.fetchFailed
        }
        
        return SupabaseConfig.projectURL.appendingPathComponent(signedURL)
    }
    
    /// Download photo image
    func downloadPhoto(storagePath: String) async throws -> UIImage {
        let url = try await getPhotoURL(storagePath: storagePath)
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let image = UIImage(data: data) else {
            throw SupabaseError.downloadFailed
        }
        
        return image
    }
}

// MARK: - DTOs

struct LovedOneDTO: Codable {
    var id: String?
    var userId: String?
    var familyId: String?
    let fullName: String
    let familiarName: String?
    let relationship: String
    let memoryPrompt: String?
    let audioFileName: String?
    var enrolled: Bool
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case familyId = "family_id"
        case fullName = "full_name"
        case familiarName = "familiar_name"
        case relationship
        case memoryPrompt = "memory_prompt"
        case audioFileName = "audio_file_name"
        case enrolled
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// Convert to local LovedOne model
    func toLovedOne(photoFileNames: [String] = []) -> LovedOne {
        var lovedOne = LovedOne(
            id: (id ?? UUID().uuidString).lowercased(),
            fullName: fullName,
            familiarName: familiarName,
            relationship: relationship,
            memoryPrompt: memoryPrompt,
            audioFileName: audioFileName,
            enrolled: enrolled,
            photoFileNames: photoFileNames
        )
        lovedOne.familyId = familyId
        return lovedOne
    }
    
    /// Create from local LovedOne model
    static func from(_ lovedOne: LovedOne) -> LovedOneDTO {
        LovedOneDTO(
            id: lovedOne.id,
            userId: nil,
            familyId: lovedOne.familyId,
            fullName: lovedOne.fullName,
            familiarName: lovedOne.familiarName,
            relationship: lovedOne.relationship,
            memoryPrompt: lovedOne.memoryPrompt,
            audioFileName: lovedOne.audioFileName,
            enrolled: lovedOne.enrolled,
            createdAt: nil,
            updatedAt: nil
        )
    }
}

struct PhotoDTO: Codable {
    var id: String?
    let lovedOneId: String
    var userId: String?
    let storagePath: String
    let fileName: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case lovedOneId = "loved_one_id"
        case userId = "user_id"
        case storagePath = "storage_path"
        case fileName = "file_name"
        case createdAt = "created_at"
    }
}

// MARK: - Errors

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case fetchFailed
    case createFailed
    case updateFailed
    case deleteFailed
    case uploadFailed
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to sync your data"
        case .fetchFailed:
            return "Failed to fetch data"
        case .createFailed:
            return "Failed to save data"
        case .updateFailed:
            return "Failed to update data"
        case .deleteFailed:
            return "Failed to delete data"
        case .uploadFailed:
            return "Failed to upload photo"
        case .downloadFailed:
            return "Failed to download photo"
        }
    }
}
