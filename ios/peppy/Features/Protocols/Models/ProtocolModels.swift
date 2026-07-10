import Foundation

/// Unambiguous name for the `Protocol` API model. Test targets need it because
/// plain `Protocol` collides with the Objective-C runtime type there.
typealias ProtocolModel = Protocol

/// Lifecycle state derived from the backend `setup_status` and `is_active` contract.
enum ProtocolStatus: String {
    case pendingSetup = "pending_setup"
    case active
    case inactive
}

extension Protocol {
    var status: ProtocolStatus {
        if setupStatus == ProtocolStatus.pendingSetup.rawValue {
            return .pendingSetup
        }
        return isActive ? .active : .inactive
    }
}
