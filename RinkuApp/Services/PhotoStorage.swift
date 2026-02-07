import SwiftUI
import PhotosUI
import CoreImage

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

/// Manages local storage of photos for loved ones
actor PhotoStorage {

    static let shared = PhotoStorage()

    private let fileManager = FileManager.default
    private var photosDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosPath = documentsPath.appendingPathComponent("FacePhotos", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: photosPath.path) {
            try? fileManager.createDirectory(at: photosPath, withIntermediateDirectories: true)
        }

        return photosPath
    }

    private init() {}

    // MARK: - Save Photos

    #if os(iOS)
    /// Save an image and return the file name
    func savePhoto(_ image: UIImage, forPersonId personId: String) async throws -> String {
        let fileName = "\(personId)_\(UUID().uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw PhotoStorageError.compressionFailed
        }

        try data.write(to: fileURL)
        return fileName
    }

    /// Save multiple images and return their file names
    func savePhotos(_ images: [UIImage], forPersonId personId: String) async throws -> [String] {
        var fileNames: [String] = []

        for image in images {
            let fileName = try await savePhoto(image, forPersonId: personId)
            fileNames.append(fileName)
        }

        return fileNames
    }

    /// Load an image by file name
    func loadPhoto(fileName: String) async -> UIImage? {
        let fileURL = photosDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    /// Load all photos for a person
    func loadPhotos(fileNames: [String]) async -> [UIImage] {
        var images: [UIImage] = []

        for fileName in fileNames {
            if let image = await loadPhoto(fileName: fileName) {
                images.append(image)
            }
        }

        return images
    }
    #endif

    /// Get CIImage for face processing
    func loadPhotoAsCIImage(fileName: String) async -> CIImage? {
        let fileURL = photosDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return CIImage(contentsOf: fileURL)
    }

    // MARK: - Delete Photos

    /// Delete a photo by file name
    func deletePhoto(fileName: String) async {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }

    /// Delete all photos for a person
    func deletePhotos(fileNames: [String]) async {
        for fileName in fileNames {
            await deletePhoto(fileName: fileName)
        }
    }

    /// Delete all photos for a person by ID prefix
    func deleteAllPhotos(forPersonId personId: String) async {
        guard let files = try? fileManager.contentsOfDirectory(atPath: photosDirectory.path) else {
            return
        }

        let lowerId = personId.lowercased()
        for file in files where file.lowercased().hasPrefix(lowerId) {
            await deletePhoto(fileName: file)
        }
    }

    // MARK: - Utilities

    /// Check if a photo exists
    func photoExists(fileName: String) async -> Bool {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// Get the URL for a photo (for display)
    func photoURL(fileName: String) -> URL {
        return photosDirectory.appendingPathComponent(fileName)
    }

    enum PhotoStorageError: Error, LocalizedError {
        case compressionFailed
        case saveFailed
        case loadFailed

        var errorDescription: String? {
            switch self {
            case .compressionFailed:
                return "Failed to compress photo"
            case .saveFailed:
                return "Failed to save photo"
            case .loadFailed:
                return "Failed to load photo"
            }
        }
    }
}

// MARK: - UIImage from PhotosPickerItem

#if os(iOS)
extension UIImage {
    static func from(_ item: PhotosPickerItem) async -> UIImage? {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}
#endif
