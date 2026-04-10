import SwiftUI
import AVFoundation

struct VoiceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var audioService = AudioService.shared
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var selectedVoice: VoiceOption?
    @State private var voices: [VoiceOption] = []

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Voice Selection Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "voice_select".localized)

                        VStack(spacing: 8) {
                            // System default option
                            VoiceOptionRow(
                                name: "voice_system_default".localized,
                                quality: "",
                                isSelected: audioService.selectedVoiceId == nil
                            ) {
                                audioService.setVoice(nil)
                            }

                            // Available voices for current language
                            ForEach(voices) { voice in
                                VoiceOptionRow(
                                    name: voice.name,
                                    quality: voice.quality,
                                    isSelected: audioService.selectedVoiceId == voice.id
                                ) {
                                    audioService.setVoice(voice.id)
                                }
                            }
                        }
                    }

                    // Speed Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "voice_speed".localized)

                        HStack(spacing: 8) {
                            ForEach(SpeechRate.allCases) { rate in
                                SpeedOptionButton(
                                    rate: rate,
                                    isSelected: audioService.speechRate == rate
                                ) {
                                    audioService.setSpeechRate(rate)
                                }
                            }
                        }
                    }

                    // Pitch Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "voice_pitch".localized)

                        VStack(spacing: 8) {
                            HStack {
                                Text("pitch_low".localized)
                                    .font(.system(size: Theme.FontSize.caption))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Spacer()
                                Text("pitch_high".localized)
                                    .font(.system(size: Theme.FontSize.caption))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }

                            Slider(value: Binding(
                                get: { Double(audioService.pitch) },
                                set: { audioService.setPitch(Float($0)) }
                            ), in: 0.5...2.0, step: 0.1)
                            .tint(Theme.Colors.primary)

                            Text(pitchLabel)
                                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                                .foregroundColor(Theme.Colors.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(16)
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                .stroke(Theme.Colors.border, lineWidth: 1)
                        )
                    }

                    // Preview Button
                    Button {
                        Task { @MainActor in
                            audioService.previewVoice()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: audioService.isSpeaking ? "stop.fill" : "play.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text("voice_preview".localized)
                                .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.Gradients.primary)
                        .foregroundColor(.white)
                        .cornerRadius(Theme.CornerRadius.medium)
                    }
                    .disabled(audioService.isSpeaking)
                    .opacity(audioService.isSpeaking ? 0.7 : 1)

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("settings_voice".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action_done".localized) {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.primary)
                }
            }
        }
        .onAppear {
            loadVoices()
        }
        .onChange(of: languageManager.currentLanguage) { _, _ in
            loadVoices()
        }
    }

    private var pitchLabel: String {
        if audioService.pitch < 0.8 {
            return "pitch_low".localized
        } else if audioService.pitch > 1.2 {
            return "pitch_high".localized
        } else {
            return "pitch_normal".localized
        }
    }

    private func loadVoices() {
        voices = audioService.availableVoices(for: languageManager.currentLanguage)
    }
}

// MARK: - Section Label

private struct SectionLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Theme.Gradients.primary)
                .frame(width: 3, height: 14)
                .cornerRadius(2)

            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(1)
        }
    }
}

// MARK: - Voice Option Row

private struct VoiceOptionRow: View {
    let name: String
    let quality: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.Colors.primary : Theme.Colors.borderLight, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Theme.Colors.primary)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: Theme.FontSize.body, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if !quality.isEmpty {
                        Text(quality)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(isSelected ? Theme.Colors.primaryLight : Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(isSelected ? Theme.Colors.primary : Theme.Colors.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Speed Option Button

private struct SpeedOptionButton: View {
    let rate: SpeechRate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(rate.displayName)
                .font(.system(size: Theme.FontSize.body, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isSelected ? Theme.Colors.primary : Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(isSelected ? Theme.Colors.primary : Theme.Colors.border, lineWidth: 1)
                )
        }
    }
}

// MARK: - Voice Settings Button (for ProfileView)

struct VoiceSettingsButton: View {
    let onTap: () -> Void
    @ObservedObject private var audioService = AudioService.shared
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primaryLight)
                        .frame(width: 40, height: 40)

                    Image(systemName: "waveform")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.primary)
                }

                // Label and current voice
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings_voice".localized)
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(audioService.currentVoiceName(for: languageManager.currentLanguage))
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

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
    }
}

#Preview {
    VoiceSettingsView()
}
