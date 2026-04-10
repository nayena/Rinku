import AppIntents

// MARK: - ReplayMorningBriefingIntent
//
// Exposes "replay my morning briefing" as a Siri voice command and
// an App Shortcut so a caregiver or the patient can say:
//
//   "Hey Siri, replay my morning briefing"
//   "Hey Siri, play briefing again"
//
// This is the recommended alternative to a hardware gesture trigger,
// since MWDATCore v0.5.0 (the Meta Wearables DAT SDK) does not expose
// any tap, double-tap, head-nod, or IMU gesture API. The SDK surface
// is limited to camera streaming, device state (hinge open/closed,
// battery), and connection management.
//
// AirPods users and anyone with "Hey Siri" enabled can replay without
// touching the phone. This is the lowest-friction hands-free path
// available within the current SDK constraints.

struct ReplayMorningBriefingIntent: AppIntent {

    static var title: LocalizedStringResource = "Replay Morning Briefing"
    static var description = IntentDescription(
        "Replays today's morning briefing for the patient.",
        categoryName: "Rinku"
    )

    /// Run silently in the background — the audio IS the feedback.
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            DailyBriefingService.shared.replayBriefing()
        }
        return .result()
    }
}

// MARK: - App Shortcuts

// Registers the phrase variants that Siri will recognise without the
// user needing to create a shortcut manually. Requires iOS 16+.
struct RinkuShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReplayMorningBriefingIntent(),
            phrases: [
                "Replay my morning briefing with \(.applicationName)",
                "Play briefing again with \(.applicationName)",
                "Repeat my briefing with \(.applicationName)",
            ],
            shortTitle: "Replay Briefing",
            systemImageName: "sunrise.fill"
        )
    }
}
