import Foundation
import Combine

// MARK: - DailyEventType

enum DailyEventType: String, Codable, CaseIterable {
    case visitor
    case appointment
    case activity
    case other

    var displayName: String {
        switch self {
        case .visitor:      return "Visitor"
        case .appointment:  return "Appointment"
        case .activity:     return "Activity"
        case .other:        return "Other"
        }
    }

    /// SF Symbol name for display in views.
    var iconName: String {
        switch self {
        case .visitor:      return "person.fill"
        case .appointment:  return "stethoscope"
        case .activity:     return "star.fill"
        case .other:        return "ellipsis.circle.fill"
        }
    }
}

// MARK: - DailyEvent

/// A caregiver-entered event for a specific calendar day
/// (visit, appointment, activity, etc.).
struct DailyEvent: Identifiable, Codable {
    let id: String
    var title: String           // "Carlos is visiting"
    var time: Date?             // optional; only hour + minute used when speaking
    var type: DailyEventType
    var forDate: Date           // the calendar day this event belongs to

    init(
        id: String = UUID().uuidString.lowercased(),
        title: String,
        time: Date? = nil,
        type: DailyEventType = .other,
        forDate: Date = .now
    ) {
        self.id      = id
        self.title   = title
        self.time    = time
        self.type    = type
        self.forDate = forDate
    }

    /// Formatted time string for TTS, e.g. "10:30 in the morning".
    var spokenTime: String? {
        guard let date = time else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        let hm = formatter.string(from: date)
        let h = Calendar.current.component(.hour, from: date)
        let suffix = h < 12 ? "in the morning" : h < 17 ? "in the afternoon" : "in the evening"
        return "\(hm) \(suffix)"
    }
}

// MARK: - PositiveMemory

/// A short positive note written by a caregiver the night before,
/// read aloud to the patient the following morning.
struct PositiveMemory: Identifiable, Codable {
    let id: String
    var text: String        // "Yesterday you had lunch with Carlos and he made you laugh."
    var forDate: Date       // the morning this will be played (written the night before)
    var writtenAt: Date

    init(
        id: String = UUID().uuidString.lowercased(),
        text: String,
        forDate: Date,
        writtenAt: Date = .now
    ) {
        self.id        = id
        self.text      = text
        self.forDate   = forDate
        self.writtenAt = writtenAt
    }
}

// MARK: - GroundingDetail

/// A permanent comforting fact about the patient, rotated across briefings.
/// e.g. "Your cat Milo is home." / "You've lived in this house for 30 years."
struct GroundingDetail: Identifiable, Codable {
    let id: String
    var text: String

    init(
        id: String = UUID().uuidString.lowercased(),
        text: String
    ) {
        self.id   = id
        self.text = text
    }
}

// MARK: - DailyBriefingService

/// Manages the morning briefing feature:
/// stores events, memories, and grounding details,
/// builds the spoken briefing text, and auto-triggers when the
/// glasses first come online each morning.
///
/// ## Trigger flow
///   RinkuApp initialises DailyBriefingService.shared at launch.
///   The init subscribes to GlassesCameraManager.$hasReceivedFirstFrame.
///   When that property flips true (first frame of a new streaming session):
///     - hour guard: 05:00–11:59
///     - date guard: not already played today
///   If both pass, buildBriefing() runs and AudioService speaks the result.
@MainActor
final class DailyBriefingService: ObservableObject {
    static let shared = DailyBriefingService()

    // MARK: - Published State

    @Published private(set) var events: [DailyEvent] = []
    @Published private(set) var memories: [PositiveMemory] = []
    @Published private(set) var groundingDetails: [GroundingDetail] = []

    /// Date of the last briefing that was spoken (nil = never this user).
    @Published private(set) var lastBriefingDate: Date?

    /// The full text that was spoken at the last briefing (for caregiver review).
    @Published private(set) var lastBriefingText: String?

    // MARK: - Private

    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    /// Days to retain events after their scheduled date.
    private let eventRetentionDays: Double = 3
    /// Days to retain positive memories.
    private let memoryRetentionDays: Double = 30

    // MARK: - Storage key helpers

    private var userId: String {
        authService.currentUser?.id ?? "guest"
    }

    private var eventsURL: URL { documentURL("daily_events_\(userId).json") }
    private var memoriesURL: URL { documentURL("positive_memories_\(userId).json") }

    private var groundingKey: String   { "grounding_details_\(userId)" }
    private var groundingIndexKey: String { "grounding_index_\(userId)" }
    private var lastBriefingKey: String { "last_briefing_date_\(userId)" }
    private var lastBriefingTextKey: String { "last_briefing_text_\(userId)" }

    private func documentURL(_ name: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
    }

    // MARK: - Init

    private init() {
        loadAll()
        setupAuthObserver()
        setupGlassesObserver()
    }

    // MARK: - Auth Observer

    private func setupAuthObserver() {
        authService.$isSignedIn
            .dropFirst()
            .sink { [weak self] isSignedIn in
                Task { @MainActor [weak self] in
                    if isSignedIn {
                        self?.loadAll()
                    } else {
                        self?.clearState()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Glasses Observer (auto-trigger)

    private func setupGlassesObserver() {
        GlassesCameraManager.shared.$hasReceivedFirstFrame
            .filter { $0 }      // only the false→true transition
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.triggerIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Replay

    /// Replays the briefing immediately — uses the cached morning text so the patient
    /// hears the exact same message they got at first wake.
    /// If no cached text exists (app restarted), rebuilds from current data.
    /// Does NOT advance the grounding index or update `lastBriefingDate`.
    func replayBriefing() {
        if let text = lastBriefingText, !text.isEmpty {
            AudioService.shared.speak(text)
        } else {
            // Rebuild in case the app was relaunched since the briefing played
            Task {
                let text = await buildBriefing(for: .now)
                guard !text.isEmpty else { return }
                AudioService.shared.speak(text)
            }
        }
    }

    // MARK: - Auto-trigger

    /// Called every time the glasses receive their first frame.
    /// Plays the briefing if: hour is 05–11 AND briefing hasn't played today.
    func triggerIfNeeded(for date: Date = .now) async {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        // Only between 5 AM and noon
        guard hour >= 5 && hour < 12 else { return }

        // Not already played today
        if let last = lastBriefingDate,
           calendar.isDate(last, inSameDayAs: date) { return }

        let text = await buildBriefing(for: date)
        guard !text.isEmpty else { return }

        // Record before speaking in case speech throws
        lastBriefingDate = date
        lastBriefingText = text
        saveBriefingMeta()

        // Advance grounding rotation for next time
        advanceGroundingIndex()

        AudioService.shared.speak(text)
    }

    // MARK: - Build Briefing

    /// Assembles the full spoken briefing for the given date.
    /// Parts (in order):
    ///   1. Warm greeting + natural date ("Good morning! Today is Wednesday, April 9th.")
    ///   2. Today's scheduled events ("Carlos is visiting at 10:30 in the morning.")
    ///   3. Positive memory from yesterday ("Yesterday you had lunch with Carlos.")
    ///   4. Morning medication reminder ("Your blood pressure pill is at 8:00 in the morning.")
    ///   5. One grounding detail — rotated ("You've lived in this house for 30 years.")
    func buildBriefing(for date: Date = .now) async -> String {
        let calendar = Calendar.current
        let hour     = calendar.component(.hour, from: date)
        var parts: [String] = []

        // 1. Greeting + date
        let salutation: String
        switch hour {
        case 5..<12:  salutation = "Good morning"
        case 12..<18: salutation = "Good afternoon"
        default:      salutation = "Good evening"
        }
        parts.append("\(salutation)! Today is \(spokenDate(date)).")

        // 2. Today's events (sorted by time)
        let todayEvents = events
            .filter { calendar.isDate($0.forDate, inSameDayAs: date) }
            .sorted {
                let t0 = $0.time ?? Date.distantFuture
                let t1 = $1.time ?? Date.distantFuture
                return t0 < t1
            }
        for event in todayEvents {
            if let spoken = event.spokenTime {
                parts.append("\(event.title) at \(spoken).")
            } else {
                parts.append("\(event.title) today.")
            }
        }

        // 3. Positive memory written for today (caregiver wrote it last night)
        if let memory = memoryForDate(date) {
            parts.append(memory.text)
        }

        // 4. Morning medication reminder
        let weekday = calendar.component(.weekday, from: date)
        let morningMeds = MedicationService.shared.entries
            .filter { $0.applies(on: weekday) && $0.scheduledHour < 12 }
            .sorted { $0.startMinuteOfDay < $1.startMinuteOfDay }

        if let med = morningMeds.first {
            let h = med.scheduledHour
            let m = med.scheduledMinute
            let displayH = h == 0 ? 12 : h
            let timeStr = String(format: "%d:%02d in the morning", displayH, m)
            parts.append("Your \(med.name.lowercased()) is scheduled at \(timeStr).")
        }

        // 5. Grounding detail (read current index; do NOT advance here — caller does that)
        if !groundingDetails.isEmpty {
            let index = UserDefaults.standard.integer(forKey: groundingIndexKey)
            let detail = groundingDetails[index % groundingDetails.count]
            parts.append(detail.text)
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Event CRUD

    func addEvent(_ event: DailyEvent) {
        events.append(event)
        saveEvents()
    }

    func deleteEvent(id: String) {
        events.removeAll { $0.id == id }
        saveEvents()
    }

    func eventsForDate(_ date: Date = .now) -> [DailyEvent] {
        events.filter { Calendar.current.isDate($0.forDate, inSameDayAs: date) }
            .sorted {
                let t0 = $0.time ?? Date.distantFuture
                let t1 = $1.time ?? Date.distantFuture
                return t0 < t1
            }
    }

    // MARK: - Memory CRUD

    /// Upserts a memory for a given date (only one memory per day is kept).
    func saveMemory(_ memory: PositiveMemory) {
        memories.removeAll { Calendar.current.isDate($0.forDate, inSameDayAs: memory.forDate) }
        memories.insert(memory, at: 0)
        saveMemories()
    }

    func deleteMemory(id: String) {
        memories.removeAll { $0.id == id }
        saveMemories()
    }

    func memoryForDate(_ date: Date) -> PositiveMemory? {
        memories.first { Calendar.current.isDate($0.forDate, inSameDayAs: date) }
    }

    // MARK: - Grounding Detail CRUD

    func addGroundingDetail(_ detail: GroundingDetail) {
        groundingDetails.append(detail)
        saveGroundingDetails()
    }

    func deleteGroundingDetail(id: String) {
        groundingDetails.removeAll { $0.id == id }
        saveGroundingDetails()
    }

    // MARK: - Private Helpers

    private func advanceGroundingIndex() {
        guard !groundingDetails.isEmpty else { return }
        let current = UserDefaults.standard.integer(forKey: groundingIndexKey)
        UserDefaults.standard.set(current + 1, forKey: groundingIndexKey)
    }

    private func spokenDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM"
        let dayAndMonth = formatter.string(from: date)
        let day = Calendar.current.component(.day, from: date)
        return "\(dayAndMonth) \(day)\(ordinalSuffix(day))"
        // → "Wednesday, April 9th"
    }

    private func ordinalSuffix(_ n: Int) -> String {
        if (11...13).contains(n % 100) { return "th" }
        switch n % 10 {
        case 1:  return "st"
        case 2:  return "nd"
        case 3:  return "rd"
        default: return "th"
        }
    }

    // MARK: - Persistence

    private func loadAll() {
        events          = loadDocuments(from: eventsURL, as: [DailyEvent].self) ?? []
        memories        = loadDocuments(from: memoriesURL, as: [PositiveMemory].self) ?? []
        groundingDetails = loadUserDefaults(key: groundingKey, as: [GroundingDetail].self) ?? []
        trimStale()

        if let interval = UserDefaults.standard.object(forKey: lastBriefingKey) as? Double {
            lastBriefingDate = Date(timeIntervalSince1970: interval)
        }
        lastBriefingText = UserDefaults.standard.string(forKey: lastBriefingTextKey)
    }

    private func clearState() {
        events = []
        memories = []
        groundingDetails = []
        lastBriefingDate = nil
        lastBriefingText = nil
    }

    private func saveEvents() {
        saveDocuments(events, to: eventsURL)
    }

    private func saveMemories() {
        saveDocuments(memories, to: memoriesURL)
    }

    private func saveGroundingDetails() {
        guard let data = try? JSONEncoder().encode(groundingDetails) else { return }
        UserDefaults.standard.set(data, forKey: groundingKey)
    }

    private func saveBriefingMeta() {
        if let date = lastBriefingDate {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: lastBriefingKey)
        }
        if let text = lastBriefingText {
            UserDefaults.standard.set(text, forKey: lastBriefingTextKey)
        }
    }

    private func trimStale() {
        let now = Date()
        let eventCutoff  = now.addingTimeInterval(-eventRetentionDays  * 86400)
        let memoryCutoff = now.addingTimeInterval(-memoryRetentionDays * 86400)
        events.removeAll   { $0.forDate < eventCutoff }
        memories.removeAll { $0.forDate < memoryCutoff }
    }

    // MARK: - Generic persistence helpers

    private func loadDocuments<T: Decodable>(from url: URL, as type: T.Type) -> T? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(type, from: data)
        else { return nil }
        return decoded
    }

    private func saveDocuments<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadUserDefaults<T: Decodable>(key: String, as type: T.Type) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(type, from: data)
        else { return nil }
        return decoded
    }
}
