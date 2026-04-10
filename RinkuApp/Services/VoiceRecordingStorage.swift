import Foundation

/// Manages local storage of voice recordings for loved ones
actor VoiceRecordingStorage {

    static let shared = VoiceRecordingStorage()

    private let fileManager = FileManager.default
    private var recordingsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("VoiceRecordings", isDirectory: true)

        if !fileManager.fileExists(atPath: recordingsPath.path) {
            try? fileManager.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }

        return recordingsPath
    }

    private init() {}

    // MARK: - Save

    /// Save audio data and return the file name
    func saveRecording(_ data: Data, forPersonId personId: String) throws -> String {
        let fileName = "\(personId)_voice.m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)

        // Overwrite if exists
        try data.write(to: fileURL)
        return fileName
    }

    // MARK: - Load

    /// Get the file URL for a recording (for AVAudioPlayer)
    func recordingURL(fileName: String) -> URL? {
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return fileURL
    }

    /// Get a temporary recording URL for AVAudioRecorder (before saving)
    func tempRecordingURL(forPersonId personId: String) -> URL {
        return recordingsDirectory.appendingPathComponent("\(personId)_voice.m4a")
    }

    // MARK: - Delete

    func deleteRecording(fileName: String) {
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }

    // MARK: - Utilities

    func recordingExists(fileName: String) -> Bool {
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }
}
