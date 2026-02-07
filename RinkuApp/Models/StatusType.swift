import SwiftUI

enum StatusType {
    case info
    case success
    case warning
    case danger

    var backgroundColor: Color {
        switch self {
        case .info:
            return Theme.Colors.primaryLight
        case .success:
            return Theme.Colors.successLight
        case .warning:
            return Theme.Colors.warningLight
        case .danger:
            return Theme.Colors.dangerLight
        }
    }

    var foregroundColor: Color {
        switch self {
        case .info:
            return Theme.Colors.primaryDark
        case .success:
            return Theme.Colors.success
        case .warning:
            return Theme.Colors.warning
        case .danger:
            return Theme.Colors.danger
        }
    }

    var iconName: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .danger:
            return "xmark.circle.fill"
        }
    }
}
