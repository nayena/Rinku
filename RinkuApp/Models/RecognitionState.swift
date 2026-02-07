import Foundation

enum RecognitionStatus: Equatable {
    case idle
    case loading
    case extracting
    case enrolled
    case recognized
    case notRecognized

    var message: String {
        switch self {
        case .idle:
            return ""
        case .loading:
            return "Loading models..."
        case .extracting:
            return "Extracting facial features..."
        case .enrolled:
            return "Ready to recognize"
        case .recognized:
            return "Person recognized"
        case .notRecognized:
            return "Person not recognized"
        }
    }

    var statusType: StatusType {
        switch self {
        case .idle, .loading, .extracting:
            return .info
        case .enrolled, .recognized:
            return .success
        case .notRecognized:
            return .warning
        }
    }
}

struct RecognitionState: Equatable {
    var status: RecognitionStatus = .idle
    var recognizedPerson: LovedOne? = nil

    var statusMessage: String {
        if status == .recognized, let person = recognizedPerson {
            return "I think this is \(person.displayName), your \(person.relationship)."
        }
        return status.message
    }
}
