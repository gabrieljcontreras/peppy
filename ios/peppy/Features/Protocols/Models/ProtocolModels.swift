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

extension Protocol {
    /// The compound with the soonest upcoming dose across the whole protocol,
    /// or `nil` if there are no compounds or none has a computable schedule
    /// (e.g. an unrecognized frequency string).
    func nextDueCompound(
        doseLogs: [DoseLog],
        calendar: Calendar = .current
    ) -> (compound: Compound, dueDate: Date)? {
        compounds
            .compactMap { compound -> (Compound, Date)? in
                guard let due = DoseScheduleCalculator.nextDueDate(
                    frequency: compound.frequency,
                    protocolStartDate: startDate,
                    doseLogs: doseLogs,
                    for: compound.id,
                    calendar: calendar
                ) else { return nil }
                return (compound, due)
            }
            .min { $0.1 < $1.1 }
            .map { (compound: $0.0, dueDate: $0.1) }
    }
}
