import SwiftUI
import AVFoundation
import Combine

/// Reusable voice recorder component for recording a single audio clip per loved one
struct VoiceRecorderView: View {
    let personId: String
    @Binding var audioFileName: String?

    @StateObject private var recorder = VoiceRecorderModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("voice_recording_label".localized)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(Theme.Colors.textSecondary)

            if recorder.hasRecording || audioFileName != nil {
                // Playback / delete state
                recordedView
            } else if recorder.isRecording {
                // Recording in progress
                recordingView
            } else {
                // Idle - show record button
                idleView
            }
        }
        .onAppear {
            recorder.personId = personId
            if let fileName = audioFileName {
                recorder.loadExisting(fileName: fileName)
            }
        }
        .onChange(of: recorder.savedFileName) { _, newValue in
            if let name = newValue {
                audioFileName = name
            }
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        Button {
            recorder.startRecording()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                Text("voice_recording_record".localized)
                    .font(.system(size: Theme.FontSize.body))
            }
            .foregroundColor(Theme.Colors.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.primaryLight)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Recording State

    private var recordingView: some View {
        HStack(spacing: 12) {
            // Pulsing red dot
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(recorder.recordingPulse ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: recorder.recordingPulse)

            Text(recorder.formattedDuration)
                .font(.system(size: Theme.FontSize.body, design: .monospaced))
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            Button {
                recorder.stopRecording()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.Colors.dangerLight)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.danger.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            recorder.recordingPulse = true
        }
    }

    // MARK: - Recorded State (Playback + Delete)

    private var recordedView: some View {
        HStack(spacing: 12) {
            Button {
                if recorder.isPlaying {
                    recorder.stopPlayback()
                } else {
                    recorder.startPlayback()
                }
            } label: {
                Image(systemName: recorder.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Theme.Colors.primary)
                    .clipShape(Circle())
            }

            Text(recorder.formattedDuration)
                .font(.system(size: Theme.FontSize.caption, design: .monospaced))
                .foregroundColor(Theme.Colors.textSecondary)

            Spacer()

            // Re-record
            Button {
                recorder.deleteAndReset()
                audioFileName = nil
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            // Delete
            Button {
                recorder.deleteAndReset()
                audioFileName = nil
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.danger)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.Colors.primaryLight)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.primary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Voice Recorder Model

final class VoiceRecorderModel: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var hasRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingPulse = false
    @Published var savedFileName: String?

    var personId: String = ""

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var recordingURL: URL?

    private let maxDuration: TimeInterval = 30

    func loadExisting(fileName: String) {
        Task {
            if let url = await VoiceRecordingStorage.shared.recordingURL(fileName: fileName) {
                await MainActor.run {
                    self.recordingURL = url
                    self.hasRecording = true
                    self.savedFileName = fileName
                    // Get duration
                    if let player = try? AVAudioPlayer(contentsOf: url) {
                        self.recordingDuration = player.duration
                    }
                }
            }
        }
    }

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session for recording: \(error)")
            return
        }

        Task {
            let url = await VoiceRecordingStorage.shared.tempRecordingURL(forPersonId: personId)
            await MainActor.run {
                self.recordingURL = url

                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]

                do {
                    let recorder = try AVAudioRecorder(url: url, settings: settings)
                    recorder.delegate = self
                    recorder.record(forDuration: self.maxDuration)
                    self.audioRecorder = recorder
                    self.isRecording = true
                    self.recordingDuration = 0
                    self.startTimer()
                } catch {
                    print("Failed to start recording: \(error)")
                }
            }
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        recordingPulse = false
        stopTimer()

        // Save the recording
        guard let url = recordingURL else { return }
        Task {
            do {
                let data = try Data(contentsOf: url)
                let fileName = try await VoiceRecordingStorage.shared.saveRecording(data, forPersonId: personId)
                await MainActor.run {
                    self.savedFileName = fileName
                    self.hasRecording = true
                }
            } catch {
                print("Failed to save recording: \(error)")
            }
        }
    }

    func startPlayback() {
        // Switch to playback mode
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session for playback: \(error)")
        }

        guard let url = recordingURL else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.play()
            audioPlayer = player
            isPlaying = true
        } catch {
            print("Failed to play recording: \(error)")
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    func deleteAndReset() {
        stopPlayback()
        stopTimer()
        audioRecorder?.stop()
        audioRecorder = nil

        if let fileName = savedFileName {
            Task {
                await VoiceRecordingStorage.shared.deleteRecording(fileName: fileName)
            }
        }

        isRecording = false
        isPlaying = false
        hasRecording = false
        recordingDuration = 0
        recordingPulse = false
        savedFileName = nil
        recordingURL = nil
    }

    var formattedDuration: String {
        let seconds = Int(recordingDuration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.audioRecorder else { return }
            DispatchQueue.main.async {
                self.recordingDuration = recorder.currentTime
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag && isRecording {
            // Max duration reached
            DispatchQueue.main.async {
                self.stopRecording()
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}
