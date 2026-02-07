import Foundation

struct PermissionState: Equatable {
    var camera: Bool = false
    var microphone: Bool = false

    var allGranted: Bool {
        camera && microphone
    }
}
