import Foundation
import UIKit
import Combine

/// Manages storage and retrieval of recognition history
final class RecognitionHistoryService: ObservableObject {
    
    static let shared = RecognitionHistoryService()
    
    // MARK: - Published State
    
    @Published private(set) var events: [RecognitionEvent] = []
    @Published private(set) var isLoading = false
    
    // MARK: - Configuration
    
    /// Maximum number of events to keep in history
    private let maxEvents = 500
    
    /// Maximum age of events to keep (30 days)
    private let maxEventAge: TimeInterval = 30 * 24 * 60 * 60
    
    /// Thumbnail size for cached images
    private let thumbnailSize = CGSize(width: 100, height: 100)
    
    // MARK: - Private
    
    private let fileManager = FileManager.default
    private var currentUserId: String?
    
    /// Get the history URL for the current user (or a default for guests)
    private var historyURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName: String
        if let userId = currentUserId {
            fileName = "recognition_history_\(userId).json"
        } else {
            fileName = "recognition_history_guest.json"
        }
        return documentsPath.appendingPathComponent(fileName)
    }
    
    // MARK: - Initialization
    
    private init() {
        // Subscribe to auth changes
        setupAuthObserver()
        
        // Load history for current user if already signed in
        loadForCurrentUser()
    }
    
    /// Set up observer for auth state changes
    private func setupAuthObserver() {
        // Listen for sign-in/sign-out notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserChanged),
            name: .userSessionDidChange,
            object: nil
        )
    }
    
    /// Load history for the currently signed-in user (if any)
    private func loadForCurrentUser() {
        // Access AuthService to check current user
        // Using UserDefaults to check session since AuthService is MainActor
        if let data = UserDefaults.standard.data(forKey: "supabase_session"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let userJson = json["user"] as? [String: Any],
           let userId = userJson["id"] as? String {
            print("📜 Loading history for existing user: \(userId)")
            currentUserId = userId
            loadHistory()
        }
    }
    
    @objc private func handleUserChanged(_ notification: Notification) {
        if let userId = notification.userInfo?["userId"] as? String {
            loadHistoryForUser(userId)
        } else {
            // User signed out
            handleSignOut()
        }
    }
    
    /// Load history for a specific user (call when user signs in)
    func loadHistoryForUser(_ userId: String) {
        print("📜 Loading recognition history for user: \(userId)")
        currentUserId = userId
        events = []
        loadHistory()
    }
    
    /// Handle user sign out
    func handleSignOut() {
        print("📜 Clearing recognition history for signed out user")
        currentUserId = nil
        events = []
    }
    
    // MARK: - Public Methods
    
    /// Log a new recognition event
    func logRecognition(
        person: LovedOne,
        confidence: Double,
        image: UIImage? = nil,
        wasOffline: Bool = false
    ) {
        // Create thumbnail from image
        var thumbnailData: Data? = nil
        if let image = image {
            thumbnailData = createThumbnail(from: image)
        }
        
        let event = RecognitionEvent(
            personId: person.id,
            personName: person.displayName,
            relationship: person.relationship,
            confidence: confidence,
            wasOffline: wasOffline,
            thumbnailData: thumbnailData
        )
        
        // Add to beginning of list (most recent first)
        events.insert(event, at: 0)
        
        // Trim old events
        trimHistory()
        
        // Save
        saveHistory()
    }
    
    /// Get events for a specific person
    func events(forPersonId personId: String) -> [RecognitionEvent] {
        events.filter { $0.personId == personId }
    }
    
    /// Get summary for each person
    func getSummaries() -> [RecognitionSummary] {
        let grouped = Dictionary(grouping: events) { $0.personId }
        
        return grouped.compactMap { (personId, events) -> RecognitionSummary? in
            guard let first = events.first else { return nil }
            
            let avgConfidence = events.map { $0.confidence }.reduce(0, +) / Double(events.count)
            let lastSeen = events.map { $0.timestamp }.max() ?? Date()
            
            return RecognitionSummary(
                personId: personId,
                personName: first.personName,
                relationship: first.relationship,
                totalRecognitions: events.count,
                lastSeen: lastSeen,
                averageConfidence: avgConfidence
            )
        }.sorted { $0.lastSeen > $1.lastSeen }
    }
    
    /// Get last recognition for a person
    func lastRecognition(forPersonId personId: String) -> RecognitionEvent? {
        events.first { $0.personId == personId }
    }
    
    /// Get recent events (last 24 hours)
    func recentEvents() -> [RecognitionEvent] {
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        return events.filter { $0.timestamp > oneDayAgo }
    }
    
    /// Get events for today
    func todayEvents() -> [RecognitionEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return events.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
    }
    
    /// Clear all history
    func clearHistory() {
        events = []
        saveHistory()
    }
    
    /// Delete events for a specific person (when they're deleted)
    func deleteEvents(forPersonId personId: String) {
        events.removeAll { $0.personId == personId }
        saveHistory()
    }
    
    // MARK: - Private Methods
    
    private func loadHistory() {
        guard fileManager.fileExists(atPath: historyURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: historyURL)
            events = try JSONDecoder().decode([RecognitionEvent].self, from: data)
            
            // Clean up old events on load
            trimHistory()
        } catch {
            print("Failed to load recognition history: \(error)")
            events = []
        }
    }
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: historyURL)
        } catch {
            print("Failed to save recognition history: \(error)")
        }
    }
    
    private func trimHistory() {
        let cutoffDate = Date().addingTimeInterval(-maxEventAge)
        
        // Remove events older than maxEventAge
        events.removeAll { $0.timestamp < cutoffDate }
        
        // Keep only maxEvents most recent
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
    }
    
    private func createThumbnail(from image: UIImage) -> Data? {
        let size = thumbnailSize
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        
        return thumbnail.jpegData(compressionQuality: 0.6)
    }
}
