import Foundation
import Combine

// MARK: - ConfirmationSource

enum ConfirmationSource: String, Codable {
    case patientTap       // patient pressed "I took them" in the glasses/app UI
    case caregiverManual  // caregiver logged it via the app on their own device
}

// MARK: - MedicationEntry

/// A scheduled medication in the patient's routine.
/// Weekday reuses the module-level `Weekday` type defined in ContextEngine.swift.
struct MedicationEntry: Identifiable, Codable, Equatable {
    let id: String
    var name: String              // e.g. "Morning Medication", "Blue Pill"
    var scheduledHour: Int        // 0–23
    var scheduledMinute: Int      // 0–59
    var weekdays: Set<Weekday>    // empty = every day

    var isAllDays: Bool { weekdays.isEmpty }

    init(
        id: String = UUID().uuidString.lowercased(),
        name: String,
        scheduledHour: Int,
        scheduledMinute: Int,
        weekdays: Set<Weekday> = []
    ) {
        self.id = id
        self.name = name
        self.scheduledHour = scheduledHour
        self.scheduledMinute = scheduledMinute
        self.weekdays = weekdays
    }

    /// Whether this entry is scheduled on a given Calendar weekday value (1 = Sun … 7 = Sat).
    func applies(on calendarWeekday: Int) -> Bool {
        guard let day = Weekday(rawValue: calendarWeekday) else { return true }
        return weekdays.isEmpty || weekdays.contains(day)
    }

    /// Total minutes from midnight for sorting and comparison.
    var startMinuteOfDay: Int { scheduledHour * 60 + scheduledMinute }
}

// MARK: - MedicationLog

/// A confirmed dose event written when the patient (or caregiver) marks a dose as taken.
struct MedicationLog: Identifiable, Codable {
    let id: String
    let entryId: String?              // which MedicationEntry this confirms; nil = general
    let takenAt: Date
    let confirmedBy: ConfirmationSource

    init(
        id: String = UUID().uuidString.lowercased(),
        entryId: String? = nil,
        takenAt: Date = .now,
        confirmedBy: ConfirmationSource
    ) {
        self.id = id
        self.entryId = entryId
        self.takenAt = takenAt
        self.confirmedBy = confirmedBy
    }
}

// MARK: - MedicationStatus

/// The answer to "has this patient taken their medication?"
enum MedicationStatus: Equatable {
    /// A dose was confirmed at the given time.
    case taken(at: Date)

    /// A scheduled dose exists for today and its time has passed, but no log entry found.
    case notTaken

    /// No scheduled entry applies right now, or no entries have been configured.
    /// Should NOT trigger an audio alert — escalate to caregiver if needed.
    case unknown
}

// MARK: - MedicationService

/// Stores medication schedules (UserDefaults, per user) and dose logs (Documents/, 7-day TTL).
/// Single source of truth for `EnvironmentObserver` when a medication container is detected.
@MainActor
final class MedicationService: ObservableObject {
    static let shared = MedicationService()

    // MARK: - Published State

    /// All configured medication schedules for the current user.
    @Published private(set) var entries: [MedicationEntry] = []

    /// Dose confirmations for the past 7 days.
    @Published private(set) var log: [MedicationLog] = []

    // MARK: - Private

    private let entriesKeyPrefix = "medication_entries_"
    private let fileManager      = FileManager.default
    private let authService      = AuthService.shared
    private var cancellables     = Set<AnyCancellable>()

    /// 7-day log retention window.
    private let logRetentionInterval: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - Initialisation

    private init() {
        setupAuthObserver()
        loadEntries()
        loadLog()
    }

    // MARK: - Auth Observer (Combine, matching AppStore pattern)

    private func setupAuthObserver() {
        authService.$isSignedIn
            .dropFirst()
            .sink { [weak self] isSignedIn in
                Task { @MainActor [weak self] in
                    if isSignedIn {
                        self?.loadEntries()
                        self?.loadLog()
                    } else {
                        self?.handleSignOut()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func handleSignOut() {
        entries = []
        log = []
    }

    // MARK: - Core Query

    /// Returns the medication status for a given moment.
    ///
    /// Logic:
    ///   1. If no entries are configured for today → `.unknown`
    ///   2. If no scheduled dose time has passed yet today → `.unknown`
    ///   3. If a dose time has passed but no log entry exists today → `.notTaken`
    ///   4. If a log entry exists today → `.taken(at:)`
    ///
    /// The caller (EnvironmentObserver consumer) should speak `.unknown` as silence
    /// and escalate `.notTaken` to a gentle prompt before suggesting a dose.
    func queryStatus(for date: Date = .now) -> MedicationStatus {
        let calendar    = Calendar.current
        let weekday     = calendar.component(.weekday, from: date)
        let nowMinutes  = calendar.component(.hour, from: date) * 60
                        + calendar.component(.minute, from: date)

        // 1. Entries scheduled for today
        let todayEntries = entries.filter { $0.applies(on: weekday) }
        guard !todayEntries.isEmpty else { return .unknown }

        // 2. Entries whose scheduled time has already passed
        let passedEntries = todayEntries.filter { $0.startMinuteOfDay <= nowMinutes }
        guard !passedEntries.isEmpty else { return .unknown }

        // 3. Any log entry recorded on the same calendar day
        let todayLogs = log.filter { calendar.isDate($0.takenAt, inSameDayAs: date) }

        if let mostRecent = todayLogs.max(by: { $0.takenAt < $1.takenAt }) {
            return .taken(at: mostRecent.takenAt)
        }

        return .notTaken
    }

    // MARK: - Logging

    /// Record that a dose was taken right now.
    /// - Parameters:
    ///   - confirmedBy: Who confirmed the dose.
    ///   - entryId: The specific `MedicationEntry.id` being confirmed, or nil for a general log.
    func logDose(confirmedBy: ConfirmationSource, entryId: String? = nil) {
        let entry = MedicationLog(entryId: entryId, confirmedBy: confirmedBy)
        log.insert(entry, at: 0) // most-recent first
        trimLog()
        saveLog()
    }

    // MARK: - Entry CRUD

    func addEntry(_ entry: MedicationEntry) {
        entries.append(entry)
        saveEntries()
    }

    func updateEntry(_ entry: MedicationEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
        saveEntries()
    }

    func deleteEntry(id: String) {
        entries.removeAll { $0.id == id }
        // Also remove log entries for the deleted schedule
        log.removeAll { $0.entryId == id }
        saveEntries()
        saveLog()
    }

    // MARK: - Convenience Queries

    /// The most recent log entry, regardless of day.
    var lastDose: MedicationLog? { log.first }

    /// All log entries for the current calendar day.
    func todayLog(relativeTo date: Date = .now) -> [MedicationLog] {
        log.filter { Calendar.current.isDate($0.takenAt, inSameDayAs: date) }
    }

    // MARK: - Storage Keys & Paths

    private var currentEntriesKey: String {
        if let userId = authService.currentUser?.id {
            return entriesKeyPrefix + userId
        }
        return entriesKeyPrefix + "guest"
    }

    private var logURL: URL {
        let docs     = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = authService.currentUser.map { "medication_log_\($0.id).json" }
                    ?? "medication_log_guest.json"
        return docs.appendingPathComponent(fileName)
    }

    // MARK: - Entries Persistence (UserDefaults)

    private func loadEntries() {
        let key = currentEntriesKey
        guard let data    = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MedicationEntry].self, from: data)
        else {
            entries = []
            return
        }
        entries = decoded
    }

    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: currentEntriesKey)
    }

    // MARK: - Log Persistence (Documents/)

    private func loadLog() {
        guard fileManager.fileExists(atPath: logURL.path) else {
            log = []
            return
        }
        do {
            let data  = try Data(contentsOf: logURL)
            let decoded = try JSONDecoder().decode([MedicationLog].self, from: data)
            log = decoded
            trimLog()  // enforce TTL on load
        } catch {
            print("[MedicationService] Failed to load log: \(error)")
            log = []
        }
    }

    private func saveLog() {
        do {
            let data = try JSONEncoder().encode(log)
            try data.write(to: logURL, options: .atomic)
        } catch {
            print("[MedicationService] Failed to save log: \(error)")
        }
    }

    /// Remove log entries older than `logRetentionInterval` (7 days).
    private func trimLog() {
        let cutoff = Date().addingTimeInterval(-logRetentionInterval)
        log.removeAll { $0.takenAt < cutoff }
    }
}
