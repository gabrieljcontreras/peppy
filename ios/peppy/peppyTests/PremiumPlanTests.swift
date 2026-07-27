import XCTest
@testable import peppy

final class PremiumPlanTests: XCTestCase {
    func testProductIDsMatchStoreKitConfiguration() {
        XCTAssertEqual(PremiumPlan.yearly.productID, "com.gabriel.peppy.premium.yearly")
        XCTAssertEqual(PremiumPlan.monthly.productID, "com.gabriel.peppy.premium.monthly")
        XCTAssertEqual(PremiumPlan.lifetime.productID, "com.gabriel.peppy.premium.lifetime")
    }

    func testPlanLookupByProductID() {
        XCTAssertEqual(
            PremiumPlan.plan(forProductID: "com.gabriel.peppy.premium.monthly"),
            .monthly
        )
        XCTAssertNil(PremiumPlan.plan(forProductID: "com.gabriel.peppy.premium.gold"))
    }

    func testDisplayOrderPutsYearlyFirst() {
        XCTAssertEqual(PremiumPlan.allCases, [.yearly, .monthly, .lifetime])
    }

    func testOnlyYearlyCarriesADiscountBadge() {
        XCTAssertEqual(PremiumPlan.yearly.badgeText, "For You 50% OFF")
        XCTAssertNil(PremiumPlan.monthly.badgeText)
        XCTAssertNil(PremiumPlan.lifetime.badgeText)
    }

    func testLifetimeIsNotRecurring() {
        XCTAssertTrue(PremiumPlan.yearly.isRecurring)
        XCTAssertTrue(PremiumPlan.monthly.isRecurring)
        XCTAssertFalse(PremiumPlan.lifetime.isRecurring)
    }

    func testUnknownEntitlementIsNotPremiumAndNotResolved() {
        XCTAssertFalse(PremiumEntitlement.unknown.isPremium)
        XCTAssertFalse(PremiumEntitlement.unknown.isResolved)
    }

    func testFreeEntitlementIsResolved() {
        XCTAssertFalse(PremiumEntitlement.free.isPremium)
        XCTAssertTrue(PremiumEntitlement.free.isResolved)
    }

    func testPremiumEntitlementIsPremium() {
        let entitlement = PremiumEntitlement.premium(plan: .yearly, expires: nil)
        XCTAssertTrue(entitlement.isPremium)
        XCTAssertTrue(entitlement.isResolved)
    }
}
