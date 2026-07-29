import Foundation

/// Whether the current account may use premium features.
///
/// `.unknown` is the pre-resolution state at launch. It is **not** premium for
/// gating purposes, but `isResolved` is false so upsell UI can stay hidden
/// until the real answer arrives — otherwise every launch flashes "locked"
/// at paying customers.
enum PremiumEntitlement: Equatable, Sendable {
    case unknown
    case free
    case premium(plan: PremiumPlan?, expires: Date?)

    var isPremium: Bool {
        if case .premium = self { return true }
        return false
    }

    var isResolved: Bool {
        self != .unknown
    }

    var plan: PremiumPlan? {
        if case .premium(let plan, _) = self { return plan }
        return nil
    }

    var expires: Date? {
        if case .premium(_, let expires) = self { return expires }
        return nil
    }
}
