import Foundation

/// Role within a family
enum FamilyRole: String, Codable, CaseIterable {
    case patient
    case caregiver
    
    var displayName: String {
        switch self {
        case .patient:
            return "Patient"
        case .caregiver:
            return "Caregiver"
        }
    }
    
    var description: String {
        switch self {
        case .patient:
            return "Uses the app for face recognition"
        case .caregiver:
            return "Helps manage loved ones"
        }
    }
    
    var icon: String {
        switch self {
        case .patient:
            return "person.fill"
        case .caregiver:
            return "heart.circle.fill"
        }
    }
}

/// Represents a family group that can share loved ones
struct Family: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    let createdBy: String
    let inviteCode: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        createdBy: String,
        inviteCode: String = Family.generateInviteCode(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdBy = createdBy
        self.inviteCode = inviteCode
        self.createdAt = createdAt
    }
    
    /// Generate a random 6-character invite code
    static func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Excluding confusing chars like 0, O, 1, I
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

/// Represents a member within a family
struct FamilyMember: Identifiable, Codable, Equatable {
    let id: String
    let familyId: String
    let userId: String
    let role: FamilyRole
    let joinedAt: Date
    
    // Optional: populated from profiles table
    var userName: String?
    var userEmail: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case familyId = "family_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case userName = "user_name"
        case userEmail = "user_email"
    }
    
    init(
        id: String = UUID().uuidString,
        familyId: String,
        userId: String,
        role: FamilyRole,
        joinedAt: Date = Date(),
        userName: String? = nil,
        userEmail: String? = nil
    ) {
        self.id = id
        self.familyId = familyId
        self.userId = userId
        self.role = role
        self.joinedAt = joinedAt
        self.userName = userName
        self.userEmail = userEmail
    }
    
    var displayName: String {
        userName ?? userEmail ?? "Unknown"
    }
    
    var initials: String {
        if let name = userName, !name.isEmpty {
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }
        if let email = userEmail {
            return String(email.prefix(2)).uppercased()
        }
        return "?"
    }
}

/// DTO for creating family in Supabase
struct FamilyDTO: Codable {
    let id: String?
    let name: String
    var createdBy: String?
    let inviteCode: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
    }
    
    init(from family: Family) {
        self.id = family.id
        self.name = family.name
        self.createdBy = family.createdBy
        self.inviteCode = family.inviteCode
        self.createdAt = family.createdAt
    }
    
    func toFamily() -> Family {
        Family(
            id: id ?? UUID().uuidString,
            name: name,
            createdBy: createdBy ?? "",
            inviteCode: inviteCode,
            createdAt: createdAt ?? Date()
        )
    }
}

/// DTO for family member in Supabase
struct FamilyMemberDTO: Codable {
    let id: String?
    let familyId: String
    var userId: String?
    let role: String
    let joinedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case familyId = "family_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
    }
    
    init(familyId: String, userId: String, role: FamilyRole) {
        self.id = nil
        self.familyId = familyId
        self.userId = userId
        self.role = role.rawValue
        self.joinedAt = nil
    }
    
    func toFamilyMember() -> FamilyMember {
        FamilyMember(
            id: id ?? UUID().uuidString,
            familyId: familyId,
            userId: userId ?? "",
            role: FamilyRole(rawValue: role) ?? .caregiver,
            joinedAt: joinedAt ?? Date()
        )
    }
}
