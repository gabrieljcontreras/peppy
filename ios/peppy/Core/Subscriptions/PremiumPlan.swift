import Foundation

/// The three Peppy Premium products. Pure data — this type deliberately does
/// not import StoreKit so it can be used from views, view models, and tests
/// without a store connection.
///
/// `allCases` order is the paywall's display order.
enum PremiumPlan: String, CaseIterable, Sendable {
    case yearly
    case monthly
    case lifetime

    var productID: String {
        switch self {
        case .yearly: return "com.gabriel.peppy.premium.yearly"
        case .monthly: return "com.gabriel.peppy.premium.monthly"
        case .lifetime: return "com.gabriel.peppy.premium.lifetime"
        }
    }

    var title: String {
        switch self {
        case .yearly: return "Yearly"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        }
    }

    /// Secondary lines under the plan title on the paywall card.
    var subtitleLines: [String] {
        switch self {
        case .yearly: return ["Includes", "Family Sharing"]
        case .monthly: return []
        case .lifetime: return ["Pay Once, Use Forever", "Includes Family Sharing"]
        }
    }

    var badgeText: String? {
        switch self {
        case .yearly: return "For You 50% OFF"
        case .monthly, .lifetime: return nil
        }
    }

    /// Lifetime is a non-consumable, so "Cancel Anytime" must not be shown
    /// for it and it never carries an expiry.
    var isRecurring: Bool {
        self != .lifetime
    }

    static func plan(forProductID productID: String) -> PremiumPlan? {
        allCases.first { $0.productID == productID }
    }
}
