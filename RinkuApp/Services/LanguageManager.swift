import Foundation
import SwiftUI
import Combine

/// Supported languages in the app
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .spanish:
            return "Español"
        }
    }
    
    var flag: String {
        switch self {
        case .english:
            return "🇺🇸"
        case .spanish:
            return "🇪🇸"
        }
    }
    
    /// Voice identifier for text-to-speech
    var voiceLanguage: String {
        switch self {
        case .english:
            return "en-US"
        case .spanish:
            return "es-MX" // Mexican Spanish for broader understanding
        }
    }
    
    /// Locale for date/number formatting
    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

/// Manages app language selection and persistence
@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    private let languageKey = "app_language"
    
    /// Current selected language
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            // Post notification for views that need to refresh
            NotificationCenter.default.post(name: .languageDidChange, object: currentLanguage)
        }
    }
    
    private init() {
        // Load saved language or default to English
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Try to detect from device locale
            let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            self.currentLanguage = deviceLanguage.starts(with: "es") ? .spanish : .english
        }
    }
    
    /// Toggle between languages
    func toggleLanguage() {
        currentLanguage = currentLanguage == .english ? .spanish : .english
    }
    
    /// Set a specific language
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
    
    /// Get localized string for current language
    func localizedString(for key: String) -> String {
        let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj")
        let bundle = path != nil ? Bundle(path: path!) ?? Bundle.main : Bundle.main
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - String Extension for Easy Localization

extension String {
    /// Returns the localized version of this string key
    var localized: String {
        return LanguageManager.shared.localizedString(for: self)
    }
    
    /// Returns localized string with format arguments
    func localized(with arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.localizedString(for: self)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - SwiftUI Environment Key

private struct LanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .english
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[LanguageEnvironmentKey.self] }
        set { self[LanguageEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Modifier for Language Updates

struct LocalizedViewModifier: ViewModifier {
    @ObservedObject var languageManager = LanguageManager.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.appLanguage, languageManager.currentLanguage)
            .id(languageManager.currentLanguage) // Force view refresh on language change
    }
}

extension View {
    /// Apply this modifier to refresh view when language changes
    func localized() -> some View {
        modifier(LocalizedViewModifier())
    }
}
