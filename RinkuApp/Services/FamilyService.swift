import Foundation
import Combine

/// Service for managing family groups
@MainActor
final class FamilyService: ObservableObject {
    
    static let shared = FamilyService()
    
    // MARK: - Published State
    
    @Published private(set) var currentFamily: Family?
    @Published private(set) var familyMembers: [FamilyMember] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: FamilyError?
    
    // MARK: - Dependencies
    
    private let authService = AuthService.shared
    
    // MARK: - Errors
    
    enum FamilyError: LocalizedError {
        case notAuthenticated
        case networkError(Error)
        case invalidInviteCode
        case alreadyInFamily
        case notFamilyMember
        case cannotLeaveOwnFamily
        case familyNotFound
        case decodingError
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Please sign in to manage families"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidInviteCode:
                return "Invalid invite code. Please check and try again."
            case .alreadyInFamily:
                return "You're already in a family. Leave your current family first."
            case .notFamilyMember:
                return "You're not a member of this family"
            case .cannotLeaveOwnFamily:
                return "You can't leave a family you created. Delete it instead."
            case .familyNotFound:
                return "Family not found"
            case .decodingError:
                return "Failed to process response"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load family on init if user is signed in
        Task {
            await loadMyFamily()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load the user's current family (if any)
    func loadMyFamily() async {
        guard authService.isSignedIn, let userId = authService.currentUser?.id else {
            currentFamily = nil
            familyMembers = []
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            // First, get user's family membership
            let membership = try await fetchMyMembership(userId: userId)
            print("👥 My membership: \(membership?.familyId ?? "none")")
            
            if let membership = membership {
                // Fetch the family details
                let family = try await fetchFamily(id: membership.familyId)
                currentFamily = family
                print("👥 Family loaded: \(family.name)")
                
                // Fetch all members
                familyMembers = try await fetchFamilyMembers(familyId: membership.familyId)
                print("👥 Loaded \(familyMembers.count) members: \(familyMembers.map { $0.displayName })")
            } else {
                currentFamily = nil
                familyMembers = []
                print("👥 No family membership found")
            }
        } catch {
            self.error = .networkError(error)
            print("❌ Failed to load family: \(error)")
        }
        
        isLoading = false
    }
    
    /// Create a new family
    func createFamily(name: String, role: FamilyRole = .caregiver) async throws -> Family {
        guard let userId = authService.currentUser?.id else {
            throw FamilyError.notAuthenticated
        }
        
        // Check if already in a family
        if currentFamily != nil {
            throw FamilyError.alreadyInFamily
        }
        
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        // Create family
        let family = Family(
            name: name,
            createdBy: userId,
            inviteCode: Family.generateInviteCode()
        )
        
        let createdFamily = try await insertFamily(family)
        
        // Add creator as member
        let member = FamilyMember(
            familyId: createdFamily.id,
            userId: userId,
            role: role
        )
        _ = try await insertFamilyMember(member)
        
        // Reload to get full data
        await loadMyFamily()
        
        return createdFamily
    }
    
    /// Join an existing family using invite code
    func joinFamily(inviteCode: String, role: FamilyRole = .patient) async throws {
        guard let userId = authService.currentUser?.id else {
            throw FamilyError.notAuthenticated
        }
        
        // Check if already in a family
        if currentFamily != nil {
            throw FamilyError.alreadyInFamily
        }
        
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        // Find family by invite code
        guard let family = try await fetchFamilyByInviteCode(inviteCode.uppercased()) else {
            throw FamilyError.invalidInviteCode
        }
        
        // Add as member
        let member = FamilyMember(
            familyId: family.id,
            userId: userId,
            role: role
        )
        _ = try await insertFamilyMember(member)
        
        // Reload
        await loadMyFamily()
    }
    
    /// Leave current family
    func leaveFamily() async throws {
        guard let userId = authService.currentUser?.id else {
            throw FamilyError.notAuthenticated
        }
        
        guard let family = currentFamily else {
            throw FamilyError.notFamilyMember
        }
        
        // If user created the family, they need to delete it instead
        if family.createdBy == userId {
            throw FamilyError.cannotLeaveOwnFamily
        }
        
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        try await deleteFamilyMember(userId: userId, familyId: family.id)
        
        currentFamily = nil
        familyMembers = []
    }
    
    /// Delete family (only creator can do this)
    func deleteFamily() async throws {
        guard let userId = authService.currentUser?.id else {
            throw FamilyError.notAuthenticated
        }
        
        guard let family = currentFamily, family.createdBy == userId else {
            throw FamilyError.notFamilyMember
        }
        
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        try await deleteFamilyFromDB(familyId: family.id)
        
        currentFamily = nil
        familyMembers = []
    }
    
    /// Remove a member from family (only creator can do this)
    func removeMember(memberId: String) async throws {
        guard let userId = authService.currentUser?.id else {
            throw FamilyError.notAuthenticated
        }
        
        guard let family = currentFamily, family.createdBy == userId else {
            throw FamilyError.notFamilyMember
        }
        
        try await deleteFamilyMemberById(memberId: memberId)
        
        // Reload members
        familyMembers = try await fetchFamilyMembers(familyId: family.id)
    }
    
    /// Check if user is in a family
    var isInFamily: Bool {
        currentFamily != nil
    }
    
    /// Check if current user is the family creator
    var isCreator: Bool {
        guard let userId = authService.currentUser?.id,
              let family = currentFamily else {
            return false
        }
        return family.createdBy == userId
    }
    
    // MARK: - Private API Methods
    
    private func fetchMyMembership(userId: String) async throws -> FamilyMember? {
        guard let accessToken = authService.accessToken else {
            throw FamilyError.notAuthenticated
        }
        
        var request = URLRequest(url: SupabaseConfig.restURL
            .appendingPathComponent("family_members")
            .appending(queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "limit", value: "1")
            ]))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FamilyError.networkError(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0))
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let dtos = try decoder.decode([FamilyMemberDTO].self, from: data)
        return dtos.first?.toFamilyMember()
    }
    
    private func fetchFamily(id: String) async throws -> Family {
        guard let accessToken = authService.accessToken else {
            throw FamilyError.notAuthenticated
        }
        
        var request = URLRequest(url: SupabaseConfig.restURL
            .appendingPathComponent("families")
            .appending(queryItems: [
                URLQueryItem(name: "id", value: "eq.\(id)"),
                URLQueryItem(name: "select", value: "*")
            ]))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FamilyError.networkError(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0))
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let dtos = try decoder.decode([FamilyDTO].self, from: data)
        guard let dto = dtos.first else {
            throw FamilyError.familyNotFound
        }
        
        return dto.toFamily()
    }
    
    private func fetchFamilyByInviteCode(_ code: String) async throws -> Family? {
        guard let accessToken = authService.accessToken else {
            throw FamilyError.notAuthenticated
        }
        
        var request = URLRequest(url: SupabaseConfig.restURL
            .appendingPathComponent("families")
            .appending(queryItems: [
                URLQueryItem(name: "invite_code", value: "eq.\(code)"),
                URLQueryItem(name: "select", value: "*")
            ]))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FamilyError.networkError(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0))
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let dtos = try decoder.decode([FamilyDTO].self, from: data)
        return dtos.first?.toFamily()
    }
    
    private func fetchFamilyMembers(familyId: String) async throws -> [FamilyMember] {
        guard let accessToken = authService.accessToken else {
            throw FamilyError.notAuthenticated
        }
        
        // Fetch members with profile info via join
        var request = URLRequest(url: SupabaseConfig.restURL
            .appendingPathComponent("family_members")
            .appending(queryItems: [
                URLQueryItem(name: "family_id", value: "eq.\(familyId)"),
                URLQueryItem(name: "select", value: "*,profiles(full_name,email)")
            ]))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Debug logging
        if let responseString = String(data: data, encoding: .utf8) {
            print("👥 Fetch members response (\((response as? HTTPURLResponse)?.statusCode ?? 0)): \(responseString)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FamilyError.networkError(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0))
        }
        
        // Parse response with nested profiles
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("👥 Failed to parse as JSON array")
            throw FamilyError.decodingError
        }
        
        print("👥 Found \(jsonArray.count) raw member records")
        
        return jsonArray.compactMap { dict -> FamilyMember? in
            guard let id = dict["id"] as? String,
                  let familyId = dict["family_id"] as? String,
                  let userId = dict["user_id"] as? String,
                  let roleStr = dict["role"] as? String,
                  let role = FamilyRole(rawValue: roleStr) else {
                return nil
            }
            
            var userName: String?
            var userEmail: String?
            
            if let profiles = dict["profiles"] as? [String: Any] {
                userName = profiles["full_name"] as? String
                userEmail = profiles["email"] as? String
            }
            
            let joinedAt: Date
            if let dateStr = dict["joined_at"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                joinedAt = formatter.date(from: dateStr) ?? Date()
            } else {
                joinedAt = Date()
            }
            
            return FamilyMember(
                id: id,
                familyId: familyId,
                userId: userId,
                role: role,
                joinedAt: joinedAt,
                userName: userName,
                userEmail: userEmail
            )
        }
    }
    
    private func insertFamily(_ family: Family) async throws -> Family {
        guard let accessToken = authService.accessToken else {
            throw FamilyError.notAuthenticated
        }
        
        var request = URLRequest(url: SupabaseConfig.restURL.appendingPathComponent("families"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        // Only send required fields - let Supabase generate the ID
        let body: [String: Any] = [
            "name": family.name,
            "created_by": family.createdBy,
            "invite_code": family.inviteCode
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Debug logging
        if let responseString = String(data: data, encoding: .utf8) {
            print("🏠 Insert family response (\((response as? HTTPURLResponse)?.statusCode ?? 0)): \(responseString)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("🏠 Family creation failed: \(errorMessage)")
            throw FamilyError.networkError(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let dtos = try decoder.decode([FamilyDTO].self, from: data)
        guard let created = dtos.first else {
            throw FamilyError.decodingError
        }
        
        return created.toFamily()
    }
    
    private func insertFamilyMember(_ member: FamilyMember) async throws -> FamilyMember {
        guard let accessToken = authService.accessToken else {
            throw FamilyError.notAuthenticated
        }
        
        var request = URLRequest(url: SupabaseConfig.restURL.appendingPathComponent("family_members"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        // Only send required fields - let Supabase generate the ID
        let body: [String: Any] = [
            "family_id": member.familyId,
            "user_id": member.userId,
            "role": member.role.rawValue
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Debug logging
        if let responseString = String(data: data, encoding: .utf8) {
            print("👤 Insert family member response (\((response as? HTTPURLResponse)?.statusCode ?? 0)): \(responseString)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("👤 Family member creation failed: \(errorMessage)")
            throw FamilyError.networkError(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let dtos = try decoder.decode([FamilyMemberDTO].self, from: data)
        guard let created = dtos.first else {
            throw FamilyError.decodingError
        }
        
        return created.toFamilyMember()
    }
    
    private func deleteFamilyMember(userId: String, familyId: String) async throws {
        guard let accessToken = authService.accessToken else {
            throw FamilyError.notAuthenticated
        }
        
        var request = URLRequest(url: SupabaseConfig.restURL
            .appendingPathComponent("family_members")
            .appending(queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "family_id", value: "eq.\(familyId)")
            ]))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FamilyError.networkError(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0))
        }
    }
    
    private func deleteFamilyMemberById(memberId: String) async throws {
        guard let accessToken = authService.accessToken else {
            throw FamilyError.notAuthenticated
        }
        
        var request = URLRequest(url: SupabaseConfig.restURL
            .appendingPathComponent("family_members")
            .appending(queryItems: [
                URLQueryItem(name: "id", value: "eq.\(memberId)")
            ]))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FamilyError.networkError(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0))
        }
    }
    
    private func deleteFamilyFromDB(familyId: String) async throws {
        guard let accessToken = authService.accessToken else {
            throw FamilyError.notAuthenticated
        }
        
        var request = URLRequest(url: SupabaseConfig.restURL
            .appendingPathComponent("families")
            .appending(queryItems: [
                URLQueryItem(name: "id", value: "eq.\(familyId)")
            ]))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FamilyError.networkError(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0))
        }
    }
}
