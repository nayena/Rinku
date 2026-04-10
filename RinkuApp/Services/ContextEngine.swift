import Foundation
import Combine

// MARK: - Weekday

enum Weekday: Int, Codable, Hashable, CaseIterable, Identifiable {
    case sunday    = 1
    case monday    = 2
    case tuesday   = 3
    case wednesday = 4
    case thursday  = 5
    case friday    = 6
    case saturday  = 7

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .sunday:    return "Sunday"
        case .monday:    return "Monday"
        case .tuesday:   return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday:  return "Thursday"
        case .friday:    return "Friday"
        case .saturday:  return "Saturday"
        }
    }

    var shortName: String { String(displayName.prefix(3)) }
}

// MARK: - RoutineEntry

/// A scheduled activity in the patient's daily routine.
struct RoutineEntry: Identifiable, Codable, Equatable {
    let id: String
    var title: String          // e.g. "Morning Medication"
    var note: String?          // e.g. "with the blue pill organizer"
    var weekdays: Set<Weekday> // empty = applies every day
    var startHour: Int         // 0–23
    var startMinute: Int       // 0–59
    var durationMinutes: Int   // 0 = treated as a 15-minute point-in-time window

    var isAllDays: Bool { weekdays.isEmpty }

    init(
        id: String = UUID().uuidString.lowercased(),
        title: String,
        note: String? = nil,
        weekdays: Set<Weekday> = [],
        startHour: Int,
        startMinute: Int,
        durationMinutes: Int = 0
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.weekdays = weekdays
        self.startHour = startHour
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
    }

    /// Whether this entry applies on the given Calendar weekday value (1 = Sunday … 7 = Saturday).
    func applies(on calendarWeekday: Int) -> Bool {
        guard let day = Weekday(rawValue: calendarWeekday) else { return true }
        return weekdays.isEmpty || weekdays.contains(day)
    }

    /// Minutes from `date` until this entry's start time on the same calendar day.
    /// Negative means the start time has already passed.
    func minutesUntilStart(from date: Date, calendar: Calendar = .current) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let nowMinutes   = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let entryMinutes = startHour * 60 + startMinute
        return entryMinutes - nowMinutes
    }

    /// Whether this entry's window is currently active at `date`.
    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        let offset = minutesUntilStart(from: date, calendar: calendar)
        let window = durationMinutes > 0 ? durationMinutes : 15
        return offset <= 0 && abs(offset) < window
    }
}

// MARK: - TimeOfDay

enum TimeOfDay {
    case morning    // 05:00–11:59
    case afternoon  // 12:00–17:59
    case evening    // 18:00–20:59
    case night      // 21:00–04:59

    init(hour: Int) {
        switch hour {
        case 5..<12:  self = .morning
        case 12..<18: self = .afternoon
        case 18..<21: self = .evening
        default:      self = .night
        }
    }

    var greeting: String {
        switch self {
        case .morning:   return "tts_greeting_morning".localized
        case .afternoon: return "tts_greeting_afternoon".localized
        case .evening:   return "tts_greeting_evening".localized
        case .night:     return "tts_greeting_night".localized
        }
    }
}

// MARK: - ContextBriefing

/// Routine-aware briefing used by AudioService to build Layer 4 of a recognition reminder.
struct ContextBriefing {
    let timeOfDay: TimeOfDay
    let activeRoutine: RoutineEntry?
    let upcomingRoutine: RoutineEntry?
    let minutesUntilUpcoming: Int?
    let personalNote: String?

    /// Full composed string for TTS, ordered: greeting → routine context → personal note.
    var spokenText: String {
        var parts: [String] = [timeOfDay.greeting + "."]

        if let active = activeRoutine {
            var line = "It's time for your \(active.title.lowercased())"
            if let note = active.note, !note.isEmpty { line += " — \(note)" }
            parts.append(line + ".")

        } else if let upcoming = upcomingRoutine, let mins = minutesUntilUpcoming {
            let timePhrase = mins <= 5 ? "very soon" : "in about \(mins) minutes"
            var line = "Your \(upcoming.title.lowercased()) starts \(timePhrase)"
            if let note = upcoming.note, !note.isEmpty { line += " — \(note)" }
            parts.append(line + ".")
        }

        if let note = personalNote, !note.isEmpty {
            parts.append(note)
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - ContextualBriefing

/// A fully composed spoken message returned by the async `buildBriefing` overload.
/// Contains a single ready-to-speak string, kept under ~200 characters (~15 seconds).
struct ContextualBriefing {
    let fullMessage: String
}

// MARK: - ContextEngine

/// Stores daily routine entries and builds contextual briefings for recognition moments.
///
/// Two `buildBriefing` overloads coexist:
/// - **Sync** → `ContextBriefing`   Used by AudioService to compose Layer 4 routine context.
/// - **Async** → `ContextualBriefing`  Builds a complete, natural-language spoken message
///   with time greeting, person intro, and the single most relevant context anchor.
@MainActor
final class ContextEngine: ObservableObject {
    static let shared = ContextEngine()

    /// All persisted routine entries, sorted by start time.
    @Published private(set) var entries: [RoutineEntry] = []

    /// Entries starting within this many minutes are surfaced as "upcoming".
    var upcomingWindowMinutes: Int = 30

    /// Session-scoped hit counter for per-person phrasing variation.
    /// Incremented each time `buildBriefing` (async) is called for a given person.
    /// Resets on app launch; intentionally not persisted.
    private var sessionSeenCounts: [String: Int] = [:]

    private let storageKey = "context_routine_entries"

    private init() {
        entries = load()
    }

    // MARK: - Sync buildBriefing (routine context for AudioService Layer 4)

    /// Builds a `ContextBriefing` containing routine state for the given moment.
    /// Called synchronously from AudioService's `speakRecognitionReminder`.
    func buildBriefing(for lovedOne: LovedOne, at date: Date = .now) -> ContextBriefing {
        let calendar = Calendar.current
        let hour     = calendar.component(.hour,    from: date)
        let weekday  = calendar.component(.weekday, from: date)

        let todaysSorted = entries
            .filter { $0.applies(on: weekday) }
            .sorted { ($0.startHour * 60 + $0.startMinute) < ($1.startHour * 60 + $1.startMinute) }

        let active = todaysSorted.first { $0.isActive(at: date, calendar: calendar) }

        var upcomingEntry: RoutineEntry?
        var minutesUntil: Int?

        if active == nil {
            for entry in todaysSorted {
                let mins = entry.minutesUntilStart(from: date, calendar: calendar)
                guard mins > 0, mins <= upcomingWindowMinutes else { continue }
                if minutesUntil == nil || mins < minutesUntil! {
                    upcomingEntry = entry
                    minutesUntil  = mins
                }
            }
        }

        return ContextBriefing(
            timeOfDay:            TimeOfDay(hour: hour),
            activeRoutine:        active,
            upcomingRoutine:      upcomingEntry,
            minutesUntilUpcoming: minutesUntil,
            personalNote:         lovedOne.memoryPrompt
        )
    }

    // MARK: - Async buildBriefing (complete spoken message)

    /// Builds a self-contained spoken message for a recognised person.
    ///
    /// Structure (all parts trimmed so total stays ≤ ~200 characters):
    /// 1. **Greeting** — time-appropriate ("Good morning.")
    /// 2. **Intro** — rotates through three phrasings per person per session
    ///    so the same person never sounds identical twice in a row.
    /// 3. **Context anchor** — priority:
    ///    a. `lovedOne.conversationStarter` if set (caregiver-supplied hook)
    ///    b. Last `RecognitionEvent` from history expressed in natural language
    ///    c. `lovedOne.memoryPrompt` as a fallback warm anchor
    func buildBriefing(for lovedOne: LovedOne, at date: Date = .now) async -> ContextualBriefing {
        let hour = Calendar.current.component(.hour, from: date)
        let greeting = TimeOfDay(hour: hour).greeting

        // Variation — cycle through 3 intro phrasings per person
        let count = sessionSeenCounts[lovedOne.id, default: 0]
        sessionSeenCounts[lovedOne.id] = count + 1

        let name = lovedOne.displayName
        let rel  = lovedOne.relationship
        let intro: String
        switch count % 3 {
        case 0:  intro = "That's \(name), your \(rel)."
        case 1:  intro = "\(name) is here — your \(rel)."
        default: intro = "You know \(name), your \(rel)."
        }

        // Context anchor (first non-empty source wins)
        let anchor: String?
        if let starter = lovedOne.conversationStarter, !starter.isEmpty {
            anchor = starter
        } else if let event = RecognitionHistoryService.shared.lastRecognition(forPersonId: lovedOne.id) {
            let phrase = naturalTimePhrase(for: event.timestamp, relativeTo: date)
            anchor = "You last saw \(name) \(phrase)."
        } else if let memory = lovedOne.memoryPrompt, !memory.isEmpty {
            anchor = memory
        } else {
            anchor = nil
        }

        // Assemble — keep total under 200 characters
        var parts: [String] = [greeting, intro]
        if let a = anchor {
            parts.append(a)
        }
        var full = parts.joined(separator: " ")
        if full.count > 200 {
            full = String(full.prefix(197)) + "..."
        }

        return ContextualBriefing(fullMessage: full)
    }

    // MARK: - CRUD

    func add(_ entry: RoutineEntry) {
        entries.append(entry)
        save()
    }

    func update(_ entry: RoutineEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
        save()
    }

    func delete(id: String) {
        entries.removeAll { $0.id == id }
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() -> [RoutineEntry] {
        guard
            let data    = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([RoutineEntry].self, from: data)
        else { return [] }
        return decoded
    }

    // MARK: - Time phrase helper

    /// Converts a past timestamp into a natural-language relative phrase.
    /// e.g. same day → "earlier today", 1 day back → "yesterday", etc.
    private func naturalTimePhrase(for timestamp: Date, relativeTo now: Date) -> String {
        let calendar = Calendar.current
        let fromDay  = calendar.startOfDay(for: timestamp)
        let toDay    = calendar.startOfDay(for: now)
        let components = calendar.dateComponents([.day], from: fromDay, to: toDay)
        switch components.day ?? 0 {
        case ...0:   return "earlier today"
        case 1:      return "yesterday"
        case 2:      return "two days ago"
        case 3:      return "three days ago"
        case 4:      return "four days ago"
        case 5:      return "five days ago"
        case 6:      return "six days ago"
        case 7:      return "a week ago"
        case let d:  return "\(d) days ago"
        }
    }
}
