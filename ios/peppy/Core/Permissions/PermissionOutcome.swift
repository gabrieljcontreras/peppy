import Foundation

enum PermissionOutcome: String, Codable {
    case notDetermined
    case requested
    case authorized
    case denied
    case unavailable
    case failed
}
