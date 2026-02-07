import Foundation
import CommonCrypto
import UIKit

/// Service for comparing faces using AWS Rekognition
actor AWSRekognitionService {
    
    static let shared = AWSRekognitionService()
    
    private init() {}
    
    // MARK: - Types
    
    struct ComparisonResult {
        let isMatch: Bool
        let similarity: Float
        let personId: String?
    }
    
    enum RekognitionError: Error, LocalizedError {
        case notConfigured
        case imageConversionFailed
        case networkError(Error)
        case apiError(String)
        case noFaceDetected
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "AWS credentials not configured. Please add your AWS access keys in AWSConfig.swift"
            case .imageConversionFailed:
                return "Failed to convert image for upload"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .apiError(let message):
                return "AWS API error: \(message)"
            case .noFaceDetected:
                return "No face detected in the image"
            case .invalidResponse:
                return "Invalid response from AWS"
            }
        }
    }
    
    // MARK: - Public API
    
    /// Compare a source face to a target face
    /// - Parameters:
    ///   - sourceImage: The image from the camera (face to identify)
    ///   - targetImage: The stored image (known person's face)
    ///   - similarityThreshold: Minimum similarity to consider a match (0-100)
    /// - Returns: Similarity score (0-100) or nil if no face match
    func compareFaces(
        sourceImage: UIImage,
        targetImage: UIImage,
        similarityThreshold: Float = 70.0
    ) async throws -> Float? {
        guard AWSConfig.isConfigured else {
            throw RekognitionError.notConfigured
        }
        
        // Convert images to base64
        guard let sourceData = sourceImage.jpegData(compressionQuality: 0.8),
              let targetData = targetImage.jpegData(compressionQuality: 0.8) else {
            throw RekognitionError.imageConversionFailed
        }
        
        let sourceBase64 = sourceData.base64EncodedString()
        let targetBase64 = targetData.base64EncodedString()
        
        // Build request body
        let requestBody: [String: Any] = [
            "SourceImage": ["Bytes": sourceBase64],
            "TargetImage": ["Bytes": targetBase64],
            "SimilarityThreshold": similarityThreshold
        ]
        
        let response = try await makeRekognitionRequest(
            action: "CompareFaces",
            body: requestBody
        )
        
        // Parse response
        guard let faceMatches = response["FaceMatches"] as? [[String: Any]] else {
            // No face matches found
            return nil
        }
        
        // Get the highest similarity match
        var highestSimilarity: Float = 0
        for match in faceMatches {
            if let similarity = match["Similarity"] as? Double {
                highestSimilarity = max(highestSimilarity, Float(similarity))
            }
        }
        
        return highestSimilarity > 0 ? highestSimilarity : nil
    }
    
    /// Find matching person from a list of loved ones
    /// - Parameters:
    ///   - sourceImage: Camera image with face to identify
    ///   - lovedOnes: List of loved ones with stored photos
    ///   - similarityThreshold: Minimum similarity to consider a match
    /// - Returns: Best matching result with person ID and similarity
    func findMatchingPerson(
        sourceImage: UIImage,
        lovedOnes: [LovedOne],
        similarityThreshold: Float = 70.0
    ) async throws -> ComparisonResult {
        guard AWSConfig.isConfigured else {
            throw RekognitionError.notConfigured
        }
        
        var bestMatch: (personId: String, similarity: Float)? = nil
        
        for person in lovedOnes {
            // Compare against each photo of this person
            for photoFileName in person.photoFileNames {
                if let targetImage = await PhotoStorage.shared.loadPhoto(fileName: photoFileName) {
                    do {
                        if let similarity = try await compareFaces(
                            sourceImage: sourceImage,
                            targetImage: targetImage,
                            similarityThreshold: similarityThreshold
                        ) {
                            // Track best match
                            if bestMatch == nil || similarity > bestMatch!.similarity {
                                bestMatch = (person.id, similarity)
                            }
                        }
                    } catch RekognitionError.noFaceDetected {
                        // Skip photos where face detection fails
                        continue
                    }
                }
            }
        }
        
        if let match = bestMatch {
            return ComparisonResult(
                isMatch: true,
                similarity: match.similarity,
                personId: match.personId
            )
        }
        
        return ComparisonResult(
            isMatch: false,
            similarity: 0,
            personId: nil
        )
    }
    
    /// Detect if a face exists in an image
    func detectFace(in image: UIImage) async throws -> Bool {
        guard AWSConfig.isConfigured else {
            throw RekognitionError.notConfigured
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw RekognitionError.imageConversionFailed
        }
        
        let requestBody: [String: Any] = [
            "Image": ["Bytes": imageData.base64EncodedString()],
            "Attributes": ["DEFAULT"]
        ]
        
        let response = try await makeRekognitionRequest(
            action: "DetectFaces",
            body: requestBody
        )
        
        guard let faceDetails = response["FaceDetails"] as? [[String: Any]] else {
            return false
        }
        
        return !faceDetails.isEmpty
    }
    
    // MARK: - Private Methods
    
    private func makeRekognitionRequest(
        action: String,
        body: [String: Any]
    ) async throws -> [String: Any] {
        let url = AWSConfig.rekognitionEndpoint
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Headers
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let amzDate = dateFormatter.string(from: Date())
        
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStamp = dateFormatter.string(from: Date())
        
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("RekognitionService.\(action)", forHTTPHeaderField: "X-Amz-Target")
        request.setValue(url.host!, forHTTPHeaderField: "Host")
        request.setValue(amzDate, forHTTPHeaderField: "X-Amz-Date")
        
        // Body
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = bodyData
        
        // Sign request with AWS Signature Version 4
        let authorization = signRequest(
            request: request,
            bodyData: bodyData,
            amzDate: amzDate,
            dateStamp: dateStamp
        )
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RekognitionError.invalidResponse
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RekognitionError.invalidResponse
        }
        
        // Check for errors
        if httpResponse.statusCode != 200 {
            if let errorType = json["__type"] as? String,
               let message = json["Message"] as? String ?? json["message"] as? String {
                throw RekognitionError.apiError("\(errorType): \(message)")
            }
            throw RekognitionError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        return json
    }
    
    // MARK: - AWS Signature V4
    
    private func signRequest(
        request: URLRequest,
        bodyData: Data,
        amzDate: String,
        dateStamp: String
    ) -> String {
        let method = request.httpMethod ?? "POST"
        let service = "rekognition"
        let region = AWSConfig.region
        let accessKey = AWSConfig.accessKeyId
        let secretKey = AWSConfig.secretAccessKey
        
        // Canonical request
        let canonicalUri = "/"
        let canonicalQuerystring = ""
        
        let payloadHash = sha256Hash(data: bodyData)
        
        let canonicalHeaders = """
        content-type:application/x-amz-json-1.1
        host:\(request.url!.host!)
        x-amz-date:\(amzDate)
        x-amz-target:\(request.value(forHTTPHeaderField: "X-Amz-Target")!)
        """
        
        let signedHeaders = "content-type;host;x-amz-date;x-amz-target"
        
        let canonicalRequest = """
        \(method)
        \(canonicalUri)
        \(canonicalQuerystring)
        \(canonicalHeaders)
        
        \(signedHeaders)
        \(payloadHash)
        """
        
        // String to sign
        let algorithm = "AWS4-HMAC-SHA256"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = """
        \(algorithm)
        \(amzDate)
        \(credentialScope)
        \(sha256Hash(string: canonicalRequest))
        """
        
        // Signing key
        let kDate = hmacSHA256(key: "AWS4\(secretKey)".data(using: .utf8)!, data: dateStamp.data(using: .utf8)!)
        let kRegion = hmacSHA256(key: kDate, data: region.data(using: .utf8)!)
        let kService = hmacSHA256(key: kRegion, data: service.data(using: .utf8)!)
        let kSigning = hmacSHA256(key: kService, data: "aws4_request".data(using: .utf8)!)
        
        // Signature
        let signature = hmacSHA256(key: kSigning, data: stringToSign.data(using: .utf8)!)
            .map { String(format: "%02x", $0) }
            .joined()
        
        // Authorization header
        return "\(algorithm) Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
    }
    
    private func sha256Hash(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func sha256Hash(string: String) -> String {
        return sha256Hash(data: string.data(using: .utf8)!)
    }
    
    private func hmacSHA256(key: Data, data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        key.withUnsafeBytes { keyPtr in
            data.withUnsafeBytes { dataPtr in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                       keyPtr.baseAddress, key.count,
                       dataPtr.baseAddress, data.count,
                       &hash)
            }
        }
        return Data(hash)
    }
}
