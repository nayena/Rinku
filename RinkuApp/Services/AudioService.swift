import Foundation
import AVFoundation
import Combine

/// Available speech rate options
enum SpeechRate: String, CaseIterable, Identifiable {
    case slow = "slow"
    case normal = "normal"
    case fast = "fast"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .slow: return "speech_rate_slow".localized
        case .normal: return "speech_rate_normal".localized
        case .fast: return "speech_rate_fast".localized
        }
    }

    var rate: Float {
        switch self {
        case .slow: return AVSpeechUtteranceDefaultSpeechRate * 0.7
        case .normal: return AVSpeechUtteranceDefaultSpeechRate * 0.9
        case .fast: return AVSpeechUtteranceDefaultSpeechRate * 1.1
        }
    }
}

/// Voice option with identifier and display name
struct VoiceOption: Identifiable, Equatable {
    let id: String
    let name: String
    let language: String
    let quality: String

    static func == (lhs: VoiceOption, rhs: VoiceOption) -> Bool {
        lhs.id == rhs.id
    }
}

/// Service for text-to-speech audio reminders with bilingual support
final class AudioService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    static let shared = AudioService()

    @Published var isSpeaking = false
    @Published var isEnabled = true
    @Published var speechRate: SpeechRate = .normal
    @Published var pitch: Float = 1.0 // Range: 0.5 - 2.0
    @Published var selectedVoiceId: String? = nil

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var pendingAudioFile: String?
    private let languageManager = LanguageManager.shared

    private let enabledKey = "audio_reminders_enabled"
    private let speechRateKey = "audio_speech_rate"
    private let pitchKey = "audio_pitch"
    private let voiceIdKey = "audio_voice_id"

    private override init() {
        super.init()

        // Load saved preferences
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }

        if let rateString = UserDefaults.standard.string(forKey: speechRateKey),
           let rate = SpeechRate(rawValue: rateString) {
            speechRate = rate
        }

        if UserDefaults.standard.object(forKey: pitchKey) != nil {
            pitch = UserDefaults.standard.float(forKey: pitchKey)
            // Clamp to valid range
            pitch = max(0.5, min(2.0, pitch))
        }

        selectedVoiceId = UserDefaults.standard.string(forKey: voiceIdKey)

        // Set up delegate
        synthesizer.delegate = self

        // Configure audio session for playback
        configureAudioSession()
    }

    /// Get available voices for a language
    func availableVoices(for language: AppLanguage) -> [VoiceOption] {
        let langPrefix = language.voiceLanguage.prefix(2) // "en" or "es"
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(String(langPrefix)) }
            .map { voice in
                let quality = voice.quality == .enhanced ? "Enhanced" : "Default"
                return VoiceOption(
                    id: voice.identifier,
                    name: voice.name,
                    language: voice.language,
                    quality: quality
                )
            }
            .sorted { $0.quality == "Enhanced" && $1.quality != "Enhanced" }
    }

    /// Set speech rate
    func setSpeechRate(_ rate: SpeechRate) {
        speechRate = rate
        UserDefaults.standard.set(rate.rawValue, forKey: speechRateKey)
    }

    /// Set pitch (0.5 - 2.0)
    func setPitch(_ newPitch: Float) {
        pitch = max(0.5, min(2.0, newPitch))
        UserDefaults.standard.set(pitch, forKey: pitchKey)
    }

    /// Set selected voice by identifier
    func setVoice(_ voiceId: String?) {
        selectedVoiceId = voiceId
        if let voiceId = voiceId {
            UserDefaults.standard.set(voiceId, forKey: voiceIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: voiceIdKey)
        }
    }

    /// Get current voice name for display
    func currentVoiceName(for language: AppLanguage) -> String {
        if let voiceId = selectedVoiceId,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            return voice.name
        }
        // Return default voice name
        if let voice = AVSpeechSynthesisVoice(language: language.voiceLanguage) {
            return voice.name
        }
        return "voice_system_default".localized
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Toggle audio reminders on/off
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        
        if !enabled {
            stop()
        }
    }
    
    /// Speak a recognition reminder for a loved one (uses current app language)
    /// If a voice recording exists, plays the intro via TTS then the recorded audio.
    /// Otherwise falls back to TTS of intro + text memory prompt.
    @MainActor func speakRecognitionReminder(for lovedOne: LovedOne) {
        guard isEnabled else { return }

        // Build the intro message
        let introFormat = "tts_this_is".localized
        let intro = String(format: introFormat, lovedOne.displayName, lovedOne.relationship)

        if let audioFile = lovedOne.audioFileName, !audioFile.isEmpty {
            // Has voice recording: speak intro, then play audio after TTS finishes
            pendingAudioFile = audioFile
            speak(intro)
        } else {
            // No voice recording: speak intro + text memory prompt
            var message = intro
            if let memoryPrompt = lovedOne.memoryPrompt, !memoryPrompt.isEmpty {
                message += " \(memoryPrompt)"
            }
            pendingAudioFile = nil
            speak(message)
        }
    }
    
    /// Speak custom text (uses current app language for voice)
    @MainActor func speak(_ text: String) {
        guard isEnabled else { return }

        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Activate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }

        // Create utterance
        let utterance = AVSpeechUtterance(string: text)

        // Configure voice settings with user preferences
        utterance.rate = speechRate.rate
        utterance.pitchMultiplier = pitch
        utterance.volume = 1.0

        // Use selected voice if available, otherwise use language default
        if let voiceId = selectedVoiceId,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            let voiceLanguage = LanguageManager.shared.currentLanguage.voiceLanguage
            if let voice = AVSpeechSynthesisVoice(language: voiceLanguage) {
                utterance.voice = voice
            }
        }

        // Add slight pauses for better comprehension
        utterance.preUtteranceDelay = 0.3
        utterance.postUtteranceDelay = 0.2

        DispatchQueue.main.async {
            self.isSpeaking = true
        }
        synthesizer.speak(utterance)
    }

    /// Speak text in a specific language (overrides app language)
    func speak(_ text: String, in language: AppLanguage) {
        guard isEnabled else { return }

        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Activate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }

        // Create utterance
        let utterance = AVSpeechUtterance(string: text)

        // Configure voice settings with user preferences
        utterance.rate = speechRate.rate
        utterance.pitchMultiplier = pitch
        utterance.volume = 1.0

        // Use selected voice if available and matches language, otherwise use language default
        if let voiceId = selectedVoiceId,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId),
           voice.language.hasPrefix(String(language.voiceLanguage.prefix(2))) {
            utterance.voice = voice
        } else if let voice = AVSpeechSynthesisVoice(language: language.voiceLanguage) {
            utterance.voice = voice
        }

        // Add slight pauses for better comprehension
        utterance.preUtteranceDelay = 0.3
        utterance.postUtteranceDelay = 0.2

        DispatchQueue.main.async {
            self.isSpeaking = true
        }
        synthesizer.speak(utterance)
    }

    /// Preview the current voice settings with sample text
    @MainActor func previewVoice() {
        let sampleText = "voice_preview_text".localized
        speak(sampleText)
    }
    
    /// Stop speaking and audio playback
    func stop() {
        pendingAudioFile = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        audioPlayer?.stop()
        audioPlayer = nil
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if let audioFile = pendingAudioFile {
            pendingAudioFile = nil
            playRecordedAudio(fileName: audioFile)
        } else {
            DispatchQueue.main.async {
                self.isSpeaking = false
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        pendingAudioFile = nil
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    // MARK: - Recorded Audio Playback

    private func playRecordedAudio(fileName: String) {
        Task {
            guard let url = await VoiceRecordingStorage.shared.recordingURL(fileName: fileName) else {
                DispatchQueue.main.async { self.isSpeaking = false }
                return
            }
            DispatchQueue.main.async {
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.delegate = self
                    player.play()
                    self.audioPlayer = player
                } catch {
                    print("Failed to play recorded audio: \(error)")
                    self.isSpeaking = false
                }
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.audioPlayer = nil
            self.isSpeaking = false
        }
    }
}
