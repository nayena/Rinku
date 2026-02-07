import Foundation
import UIKit
import Vision
import CoreImage
import Combine

/// Caches face data for offline recognition
/// Uses Vision framework for local face matching when AWS is unavailable
final class OfflineFaceCache: ObservableObject {
    
    static let shared = OfflineFaceCache()
    
    // MARK: - Types
    
    struct CachedFace: Codable, Identifiable {
        let id: String
        let personId: String
        let personName: String
        let relationship: String
        let timestamp: Date
        let faceGeometry: FaceGeometry?
        var imageData: Data?
        
        init(
            id: String = UUID().uuidString,
            personId: String,
            personName: String,
            relationship: String,
            timestamp: Date = Date(),
            faceGeometry: FaceGeometry? = nil,
            imageData: Data? = nil
        ) {
            self.id = id
            self.personId = personId
            self.personName = personName
            self.relationship = relationship
            self.timestamp = timestamp
            self.faceGeometry = faceGeometry
            self.imageData = imageData
        }
    }
    
    /// Simplified face geometry for comparison
    struct FaceGeometry: Codable {
        let boundingBoxX: Double
        let boundingBoxY: Double
        let boundingBoxWidth: Double
        let boundingBoxHeight: Double
        let roll: Double
        let yaw: Double
        // Face proportions for basic matching
        let aspectRatio: Double
        let relativeEyeDistance: Double?
        let relativeNosePosition: Double?
        let relativeMouthPosition: Double?
        
        var boundingBox: CGRect {
            CGRect(x: boundingBoxX, y: boundingBoxY, width: boundingBoxWidth, height: boundingBoxHeight)
        }
        
        init(boundingBox: CGRect, roll: Double, yaw: Double, aspectRatio: Double, relativeEyeDistance: Double?, relativeNosePosition: Double?, relativeMouthPosition: Double?) {
            self.boundingBoxX = boundingBox.origin.x
            self.boundingBoxY = boundingBox.origin.y
            self.boundingBoxWidth = boundingBox.width
            self.boundingBoxHeight = boundingBox.height
            self.roll = roll
            self.yaw = yaw
            self.aspectRatio = aspectRatio
            self.relativeEyeDistance = relativeEyeDistance
            self.relativeNosePosition = relativeNosePosition
            self.relativeMouthPosition = relativeMouthPosition
        }
    }
    
    struct OfflineMatchResult {
        let personId: String
        let personName: String
        let relationship: String
        let similarity: Double
        let cachedFace: CachedFace
    }
    
    // MARK: - Published State
    
    @Published private(set) var cachedFaces: [CachedFace] = []
    @Published private(set) var isOfflineMode = false
    
    // MARK: - Configuration
    
    /// Maximum cached faces per person
    private let maxFacesPerPerson = 5
    
    /// Total maximum cached faces
    private let maxTotalFaces = 50
    
    /// Cache expiry (7 days)
    private let cacheExpiry: TimeInterval = 7 * 24 * 60 * 60
    
    /// Minimum similarity for offline match (lower than AWS since less accurate)
    private let offlineMatchThreshold: Double = 0.6
    
    // MARK: - Private
    
    private let fileManager = FileManager.default
    private let context = CIContext()
    
    private var cacheURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("offline_face_cache.json")
    }
    
    // MARK: - Initialization
    
    private init() {
        loadCache()
        checkNetworkStatus()
    }
    
    // MARK: - Public Methods
    
    /// Cache a successfully recognized face for offline use
    func cacheFace(
        person: LovedOne,
        image: UIImage,
        faceObservation: VNFaceObservation? = nil
    ) async {
        // Extract face geometry
        let geometry = await extractFaceGeometry(from: image, existingObservation: faceObservation)
        
        // Create thumbnail
        let imageData = createFaceThumbnail(from: image)
        
        let cachedFace = CachedFace(
            personId: person.id,
            personName: person.displayName,
            relationship: person.relationship,
            faceGeometry: geometry,
            imageData: imageData
        )
        
        // Add to cache
        cachedFaces.append(cachedFace)
        
        // Trim cache
        trimCache(forPersonId: person.id)
        
        // Save
        saveCache()
    }
    
    /// Try to match a face offline using cached data
    func matchOffline(image: UIImage) async -> OfflineMatchResult? {
        guard !cachedFaces.isEmpty else { return nil }
        
        // Extract face geometry from source image
        guard let sourceGeometry = await extractFaceGeometry(from: image, existingObservation: nil) else {
            return nil
        }
        
        // Compare against all cached faces
        var bestMatch: (face: CachedFace, similarity: Double)?
        
        for cachedFace in cachedFaces {
            guard let cachedGeometry = cachedFace.faceGeometry else { continue }
            
            let similarity = calculateSimilarity(source: sourceGeometry, cached: cachedGeometry)
            
            if similarity > offlineMatchThreshold {
                if bestMatch == nil || similarity > bestMatch!.similarity {
                    bestMatch = (cachedFace, similarity)
                }
            }
        }
        
        guard let match = bestMatch else { return nil }
        
        return OfflineMatchResult(
            personId: match.face.personId,
            personName: match.face.personName,
            relationship: match.face.relationship,
            similarity: match.similarity * 100, // Convert to percentage
            cachedFace: match.face
        )
    }
    
    /// Check if we have cached faces for offline mode
    var hasCache: Bool {
        !cachedFaces.isEmpty
    }
    
    /// Get cached faces for a specific person
    func cachedFaces(forPersonId personId: String) -> [CachedFace] {
        cachedFaces.filter { $0.personId == personId }
    }
    
    /// Clear cache for a specific person
    func clearCache(forPersonId personId: String) {
        cachedFaces.removeAll { $0.personId == personId }
        saveCache()
    }
    
    /// Clear all cache
    func clearAllCache() {
        cachedFaces = []
        saveCache()
    }
    
    /// Update offline mode status
    func setOfflineMode(_ offline: Bool) {
        isOfflineMode = offline
    }
    
    // MARK: - Private Methods
    
    private func extractFaceGeometry(from image: UIImage, existingObservation: VNFaceObservation?) async -> FaceGeometry? {
        // If we have an existing observation, use it
        if let observation = existingObservation {
            return geometryFromObservation(observation, imageSize: image.size)
        }
        
        // Otherwise, detect face
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNDetectFaceLandmarksRequest { request, error in
                guard let results = request.results as? [VNFaceObservation],
                      let face = results.first else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let geometry = self.geometryFromObservation(face, imageSize: image.size)
                continuation.resume(returning: geometry)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func geometryFromObservation(_ observation: VNFaceObservation, imageSize: CGSize) -> FaceGeometry {
        let boundingBox = observation.boundingBox
        let aspectRatio = boundingBox.width / boundingBox.height
        
        // Extract landmark-based measurements if available
        var relativeEyeDistance: Double?
        var relativeNosePosition: Double?
        var relativeMouthPosition: Double?
        
        if let landmarks = observation.landmarks {
            // Eye distance relative to face width
            if let leftEye = landmarks.leftEye?.normalizedPoints.first,
               let rightEye = landmarks.rightEye?.normalizedPoints.first {
                let eyeDistance = abs(rightEye.x - leftEye.x)
                relativeEyeDistance = Double(eyeDistance)
            }
            
            // Nose position relative to face
            if let nose = landmarks.nose?.normalizedPoints.first {
                relativeNosePosition = Double(nose.y)
            }
            
            // Mouth position relative to face
            if let mouth = landmarks.innerLips?.normalizedPoints.first {
                relativeMouthPosition = Double(mouth.y)
            }
        }
        
        return FaceGeometry(
            boundingBox: boundingBox,
            roll: observation.roll?.doubleValue ?? 0,
            yaw: observation.yaw?.doubleValue ?? 0,
            aspectRatio: aspectRatio,
            relativeEyeDistance: relativeEyeDistance,
            relativeNosePosition: relativeNosePosition,
            relativeMouthPosition: relativeMouthPosition
        )
    }
    
    private func calculateSimilarity(source: FaceGeometry, cached: FaceGeometry) -> Double {
        var scores: [Double] = []
        
        // Aspect ratio similarity
        let aspectDiff = abs(source.aspectRatio - cached.aspectRatio)
        let aspectScore = max(0, 1 - aspectDiff * 5)
        scores.append(aspectScore)
        
        // Eye distance similarity
        if let sourceEyes = source.relativeEyeDistance,
           let cachedEyes = cached.relativeEyeDistance {
            let eyeDiff = abs(sourceEyes - cachedEyes)
            let eyeScore = max(0, 1 - eyeDiff * 10)
            scores.append(eyeScore * 1.5) // Weight eyes higher
        }
        
        // Nose position similarity
        if let sourceNose = source.relativeNosePosition,
           let cachedNose = cached.relativeNosePosition {
            let noseDiff = abs(sourceNose - cachedNose)
            let noseScore = max(0, 1 - noseDiff * 8)
            scores.append(noseScore)
        }
        
        // Mouth position similarity
        if let sourceMouth = source.relativeMouthPosition,
           let cachedMouth = cached.relativeMouthPosition {
            let mouthDiff = abs(sourceMouth - cachedMouth)
            let mouthScore = max(0, 1 - mouthDiff * 8)
            scores.append(mouthScore)
        }
        
        // Roll/Yaw tolerance (faces should be similarly oriented)
        let rollDiff = abs(source.roll - cached.roll)
        let yawDiff = abs(source.yaw - cached.yaw)
        if rollDiff > 0.5 || yawDiff > 0.5 {
            return 0 // Too different orientation
        }
        
        // Average all scores
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    private func createFaceThumbnail(from image: UIImage) -> Data? {
        let size = CGSize(width: 150, height: 150)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        
        return thumbnail.jpegData(compressionQuality: 0.7)
    }
    
    private func trimCache(forPersonId: String) {
        // Keep only maxFacesPerPerson for this person (most recent)
        let personFaces = cachedFaces.filter { $0.personId == forPersonId }
        if personFaces.count > maxFacesPerPerson {
            let sortedFaces = personFaces.sorted { $0.timestamp > $1.timestamp }
            let facesToRemove = sortedFaces.suffix(from: maxFacesPerPerson)
            let idsToRemove = Set(facesToRemove.map { $0.id })
            cachedFaces.removeAll { idsToRemove.contains($0.id) }
        }
        
        // Remove expired faces
        let cutoff = Date().addingTimeInterval(-cacheExpiry)
        cachedFaces.removeAll { $0.timestamp < cutoff }
        
        // Limit total faces
        if cachedFaces.count > maxTotalFaces {
            cachedFaces = Array(cachedFaces.sorted { $0.timestamp > $1.timestamp }.prefix(maxTotalFaces))
        }
    }
    
    private func loadCache() {
        guard fileManager.fileExists(atPath: cacheURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            cachedFaces = try JSONDecoder().decode([CachedFace].self, from: data)
            
            // Clean expired on load
            let cutoff = Date().addingTimeInterval(-cacheExpiry)
            cachedFaces.removeAll { $0.timestamp < cutoff }
        } catch {
            print("Failed to load offline face cache: \(error)")
            cachedFaces = []
        }
    }
    
    private func saveCache() {
        do {
            let data = try JSONEncoder().encode(cachedFaces)
            try data.write(to: cacheURL)
        } catch {
            print("Failed to save offline face cache: \(error)")
        }
    }
    
    private func checkNetworkStatus() {
        // Simple network check - in production, use NWPathMonitor
        // For now, we'll set this based on AWS call success/failure
    }
}
