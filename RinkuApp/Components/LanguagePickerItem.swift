import SwiftUI

/// A settings item that allows users to select their preferred language
struct LanguagePickerItem: View {
    @ObservedObject var languageManager = LanguageManager.shared
    @State private var showPicker = false
    
    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primaryLight)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "globe")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.primary)
                }
                
                // Label and current language
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings_language".localized)
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Text("settings_language_subtitle".localized)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Current language badge
                HStack(spacing: 6) {
                    Text(languageManager.currentLanguage.flag)
                        .font(.system(size: 16))
                    
                    Text(languageManager.currentLanguage.displayName)
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(Theme.Colors.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.Colors.primaryLight)
                .cornerRadius(12)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(16)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
        }
        .sheet(isPresented: $showPicker) {
            LanguageSelectionSheet(languageManager: languageManager)
        }
    }
}

/// Sheet view for selecting a language
struct LanguageSelectionSheet: View {
    @ObservedObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header illustration
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.primaryLight)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "globe")
                            .font(.system(size: 36))
                            .foregroundColor(Theme.Colors.primary)
                    }
                    
                    Text("settings_language".localized)
                        .font(.system(size: Theme.FontSize.h2, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Text("settings_language_subtitle".localized)
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(.vertical, 32)
                
                // Language options
                VStack(spacing: 12) {
                    ForEach(AppLanguage.allCases) { language in
                        LanguageOptionButton(
                            language: language,
                            isSelected: languageManager.currentLanguage == language,
                            action: {
                                languageManager.setLanguage(language)
                                // Small delay before dismissing to show selection
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    dismiss()
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Info text
                Text("app_tagline".localized)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.bottom, 32)
            }
            .background(Theme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action_done".localized) {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }
}

/// Individual language option button
struct LanguageOptionButton: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Flag
                Text(language.flag)
                    .font(.system(size: 32))
                
                // Language name
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Text(language == .english ? "English" : "Spanish")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.Colors.primary : Theme.Colors.border, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Theme.Colors.primary)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(20)
            .background(isSelected ? Theme.Colors.primaryLight : Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(isSelected ? Theme.Colors.primary : Theme.Colors.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

/// Quick language toggle button (compact version for toolbar)
struct LanguageToggleButton: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                languageManager.toggleLanguage()
            }
        } label: {
            HStack(spacing: 4) {
                Text(languageManager.currentLanguage.flag)
                    .font(.system(size: 16))
                
                Text(languageManager.currentLanguage.rawValue.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.Colors.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.Colors.primaryLight)
            .cornerRadius(8)
        }
    }
}

#Preview("Language Picker Item") {
    VStack {
        LanguagePickerItem()
            .padding()
        Spacer()
    }
    .background(Theme.Colors.background)
}

#Preview("Language Selection Sheet") {
    LanguageSelectionSheet(languageManager: LanguageManager.shared)
}

#Preview("Language Toggle Button") {
    LanguageToggleButton()
        .padding()
}
