import Foundation
import Combine
import UIKit

// MARK: - Environment Event

/// A discrete environmental observation emitted by EnvironmentObserver.
/// Each case carries enough information for AudioService to speak
/// without needing a second lookup.
enum EnvironmentEvent: Equatable {
    /// A medication container is visible with at least `confidence`% certainty.
    case medicationVisible(confidence: Float)

    /// A known tracked item (keys, wallet, etc.) is visible.
    case knownItemVisible(label: String, confidence: Float)

    /// A door or entrance is visible in close proximity.
    case doorVisible(confidence: Float)
}

// MARK: - EnvironmentObserver

/// Passively watches glasses camera frames and emits EnvironmentEvents
/// when objects relevant to dementia patient safety or orientation are detected.
///
/// ## Frame pipeline (Option A — zero changes to existing code)
///
///   GlassesCameraManager.$currentVideoFrame  (@Published, fires on MainActor at 24fps)
///       → .receive(on: processingQueue)       (hop off main thread immediately)
///       → .throttle(every scanInterval)       (reduces to ~0.5 fps by default)
///       → analyze(_:)                         (AWS DetectLabels on processingQueue)
///       → emit EnvironmentEvent on main thread
///
/// ## QoS
///   processingQueue runs at .utility — deliberately below FaceDetectionManager's
///   .userInteractive queue, so face recognition always preempts object detection
///   when the CPU is under pressure.
///
/// ## Usage
///   Call startObserving() when glasses streaming begins.
///   Call stopObserving() when the session ends.
///   Observe `lastEvent` or subscribe to `eventPublisher` for events.
final class EnvironmentObserver: ObservableObject {
    static let shared = EnvironmentObserver()

    // MARK: - Public State

    /// The most recent event, published on the main thread.
    @Published private(set) var lastEvent: EnvironmentEvent?

    /// True while the Combine subscription is active.
    @Published private(set) var isScanning: Bool = false

    // MARK: - Configuration

    /// How often (in seconds) to send a frame for analysis. Changing this after
    /// startObserving() has no effect until the next stop/start cycle.
    var scanInterval: TimeInterval = 2.0

    /// Master on/off switch. When false, frames are received but not analyzed.
    var isEnabled: Bool = true

    /// How long (seconds) to suppress repeated events of the same category
    /// so the same object doesn't fire continuously while in view.
    var eventCooldown: TimeInterval = 10.0

    // MARK: - Label Watchlists
    // Caregivers can extend these per patient in a future settings screen.

    var medicationLabels: Set<String> = [
        "Pill", "Pills", "Medicine", "Medication",
        "Bottle", "Prescription", "Drug", "Tablet", "Capsule"
    ]

    var doorLabels: Set<String> = [
        "Door", "Entrance", "Exit", "Door Handle",
        "Doorknob", "Gate", "Doorway"
    ]

    var trackedItemLabels: Set<String> = [
        "Key", "Keys", "Keychain", "Wallet",
        "Purse", "Glasses", "Eyeglasses", "Phone"
    ]

    // MARK: - Private

    private let processingQueue = DispatchQueue(
        label: "com.rinku.environment.observer",
        qos: .utility   // yields to FaceDetectionManager's .userInteractive
    )

    private var cancellables = Set<AnyCancellable>()

    /// Tracks the last time each event category fired, for cooldown enforcement.
    /// Keyed by category string (e.g. "medication", "door", "item_Key").
    private var lastEventTimes: [String: Date] = [:]

    private init() {}

    // MARK: - Lifecycle

    /// Begin watching the glasses frame stream.
    /// Safe to call multiple times — subsequent calls are no-ops.
    func startObserving() {
        guard cancellables.isEmpty else { return }

        GlassesCameraManager.shared.$currentVideoFrame
            .compactMap { $0 }                                             // skip nil frames
            .receive(on: processingQueue)                                  // hop off main thread
            .throttle(for: .seconds(scanInterval),                         // limit API call rate
                      scheduler: processingQueue,
                      latest: true)
            .filter { [weak self] _ in self?.isEnabled == true }
            .sink { [weak self] frame in
                self?.analyze(frame)
            }
            .store(in: &cancellables)

        DispatchQueue.main.async { self.isScanning = true }
        print("[EnvironmentObserver] Started scanning (interval: \(scanInterval)s)")
    }

    /// Stop watching and cancel the Combine subscription.
    func stopObserving() {
        cancellables.removeAll()
        DispatchQueue.main.async { self.isScanning = false }
        print("[EnvironmentObserver] Stopped scanning")
    }

    // MARK: - Analysis

    private func analyze(_ image: UIImage) {
        guard AWSConfig.isConfigured else {
            // AWS not configured: object detection is unavailable.
            // EnvironmentObserver is silent rather than producing low-quality guesses.
            return
        }

        Task {
            do {
                let labels = try await AWSRekognitionService.shared.detectLabels(
                    in: image,
                    maxLabels: 20,
                    minConfidence: 65.0
                )
                process(labels: labels)
            } catch AWSRekognitionService.RekognitionError.notConfigured {
                // Already guarded above; ignore.
                return
            } catch {
                // Network errors, throttling, etc. — log and continue.
                print("[EnvironmentObserver] DetectLabels failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Event Routing

    private func process(labels: [AWSRekognitionService.DetectedLabel]) {
        // Check scenarios in priority order: medication > door > items.
        // Only one event fires per analysis cycle — highest priority wins.

        if let event = medicationEvent(from: labels) { fire(event); return }
        if let event = doorEvent(from: labels)       { fire(event); return }
        if let event = itemEvent(from: labels)       { fire(event); return }
    }

    private func medicationEvent(from labels: [AWSRekognitionService.DetectedLabel]) -> EnvironmentEvent? {
        guard !isCoolingDown(key: "medication") else { return nil }
        let match = labels.first { medicationLabels.contains($0.name) }
        guard let best = match else { return nil }
        return .medicationVisible(confidence: best.confidence)
    }

    private func doorEvent(from labels: [AWSRekognitionService.DetectedLabel]) -> EnvironmentEvent? {
        guard !isCoolingDown(key: "door") else { return nil }
        let match = labels.first { doorLabels.contains($0.name) }
        guard let best = match else { return nil }
        return .doorVisible(confidence: best.confidence)
    }

    private func itemEvent(from labels: [AWSRekognitionService.DetectedLabel]) -> EnvironmentEvent? {
        let match = labels.first { trackedItemLabels.contains($0.name) }
        guard let best = match else { return nil }
        let key = "item_\(best.name)"
        guard !isCoolingDown(key: key) else { return nil }
        return .knownItemVisible(label: best.name, confidence: best.confidence)
    }

    // MARK: - Helpers

    private func fire(_ event: EnvironmentEvent) {
        let key = cooldownKey(for: event)
        lastEventTimes[key] = Date()
        DispatchQueue.main.async { self.lastEvent = event }
    }

    private func isCoolingDown(key: String) -> Bool {
        guard let last = lastEventTimes[key] else { return false }
        return Date().timeIntervalSince(last) < eventCooldown
    }

    private func cooldownKey(for event: EnvironmentEvent) -> String {
        switch event {
        case .medicationVisible:               return "medication"
        case .doorVisible:                     return "door"
        case .knownItemVisible(let label, _):  return "item_\(label)"
        }
    }
}
