import Foundation

struct LovedOne: Identifiable, Equatable, Hashable, Codable {
    let id: String
    var fullName: String
    var familiarName: String?
    var relationship: String
    var memoryPrompt: String?
    var audioFileName: String?  // Local file name for voice recording
    var enrolled: Bool
    var photoFileNames: [String]  // Local file names for stored photos
    var familyId: String?  // If set, belongs to a family (shared); otherwise personal

    var initials: String {
        let parts = fullName.trimmingCharacters(in: .whitespaces).split(separator: " ")
        if parts.count == 1 {
            return String(parts[0].prefix(2)).uppercased()
        }
        let first = parts.first?.first ?? Character(" ")
        let last = parts.last?.first ?? Character(" ")
        return "\(first)\(last)".uppercased()
    }

    var displayName: String {
        familiarName ?? fullName
    }

    var hasPhotos: Bool {
        !photoFileNames.isEmpty
    }

    var photoCount: Int {
        photoFileNames.count
    }
    
    /// Whether this loved one belongs to a family (shared)
    var isShared: Bool {
        familyId != nil
    }

    init(
        id: String = UUID().uuidString.lowercased(),
        fullName: String,
        familiarName: String? = nil,
        relationship: String,
        memoryPrompt: String? = nil,
        audioFileName: String? = nil,
        enrolled: Bool = false,
        photoFileNames: [String] = [],
        familyId: String? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.familiarName = familiarName
        self.relationship = relationship
        self.memoryPrompt = memoryPrompt
        self.audioFileName = audioFileName
        self.enrolled = enrolled
        self.photoFileNames = photoFileNames
        self.familyId = familyId
    }
}
