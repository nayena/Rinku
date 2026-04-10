import Foundation

/// Represents a single face recognition event
struct RecognitionEvent: Identifiable, Codable {
    let id: String
    let personId: String
    let personName: String
    let relationship: String
    let timestamp: Date
    let confidence: Double
    let wasOffline: Bool
    
    /// Thumbnail image data (compressed JPEG)
    var thumbnailData: Data?
    
    init(
        id: String = UUID().uuidString,
        personId: String,
        personName: String,
        relationship: String,
        timestamp: Date = Date(),
        confidence: Double,
        wasOffline: Bool = false,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.personId = personId
        self.personName = personName
        self.relationship = relationship
        self.timestamp = timestamp
        self.confidence = confidence
        self.wasOffline = wasOffline
        self.thumbnailData = thumbnailData
    }
    
    // MARK: - Computed Properties
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var confidencePercent: Int {
        Int(confidence)
    }
}

/// Summary of recognition events for a specific person
struct RecognitionSummary: Identifiable {
    let personId: String
    let personName: String
    let relationship: String
    let totalRecognitions: Int
    let lastSeen: Date
    let averageConfidence: Double
    
    var id: String { personId }
    
    var lastSeenAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSeen, relativeTo: Date())
    }
}
