import Foundation
import Combine

/// Manages onboarding state - tracks if user has completed first-time setup
final class OnboardingManager: ObservableObject {
    
    static let shared = OnboardingManager()
    
    // Keys for UserDefaults
    private let hasSeenWelcomeKey = "hasSeenWelcome"  // Global - seen welcome pages
    private let setupCompletedKeyPrefix = "setupCompleted_"  // Per-user - completed role/family setup
    
    /// Has the user seen the welcome pages (global, not per-user)
    @Published var hasSeenWelcome: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenWelcome, forKey: hasSeenWelcomeKey)
        }
    }
    
    /// Has the current user completed setup (role selection, family setup)
    /// This is tracked per-user ID
    @Published var hasCompletedSetup: Bool = false
    
    /// Legacy combined property - true if welcome seen AND setup completed
    var hasCompletedOnboarding: Bool {
        hasSeenWelcome && hasCompletedSetup
    }
    
    private var currentUserId: String?
    
    private init() {
        self.hasSeenWelcome = UserDefaults.standard.bool(forKey: hasSeenWelcomeKey)
        setupAuthObserver()
    }
    
    /// Set up observer for auth state changes
    private func setupAuthObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserSessionChanged),
            name: .userSessionDidChange,
            object: nil
        )
    }
    
    @objc private func handleUserSessionChanged(_ notification: Notification) {
        if let userId = notification.userInfo?["userId"] as? String {
            // User signed in - check their setup status
            checkSetupStatus(for: userId)
        } else {
            // User signed out
            handleSignOut()
        }
    }
    
    /// Call when user signs in to check their setup status
    func checkSetupStatus(for userId: String) {
        currentUserId = userId
        let key = setupCompletedKeyPrefix + userId
        hasCompletedSetup = UserDefaults.standard.bool(forKey: key)
    }
    
    /// Mark welcome pages as seen
    func completeWelcome() {
        hasSeenWelcome = true
    }
    
    /// Mark current user's setup as complete
    func completeSetup() {
        guard let userId = currentUserId else { return }
        let key = setupCompletedKeyPrefix + userId
        UserDefaults.standard.set(true, forKey: key)
        hasCompletedSetup = true
    }
    
    /// Legacy method - completes both welcome and setup
    func completeOnboarding() {
        hasSeenWelcome = true
        completeSetup()
    }
    
    /// For testing - resets all onboarding state
    func resetOnboarding() {
        hasSeenWelcome = false
        hasCompletedSetup = false
        if let userId = currentUserId {
            let key = setupCompletedKeyPrefix + userId
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    /// Called when user signs out
    func handleSignOut() {
        hasCompletedSetup = false
        currentUserId = nil
    }
}
