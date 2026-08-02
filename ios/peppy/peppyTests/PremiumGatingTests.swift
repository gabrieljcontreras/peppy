import UIKit
import XCTest
@testable import peppy

final class PremiumGatingTests: XCTestCase {
    func testPaymentRequiredHasUserMessage() {
        XCTAssertEqual(
            APIError.paymentRequired.userMessage,
            "Peppy Premium is required for this."
        )
    }

    func testPaymentRequiredIsEquatable() {
        XCTAssertEqual(APIError.paymentRequired, APIError.paymentRequired)
        XCTAssertNotEqual(APIError.paymentRequired, APIError.forbidden)
    }
}

extension PremiumGatingTests {
    func testSubscriptionEndpointPaths() {
        XCTAssertEqual(Endpoint.getSubscription.path, "/subscription")
        XCTAssertEqual(Endpoint.getSubscription.method, .get)

        let sync = Endpoint.syncAppleTransaction(
            AppleTransactionRequest(signedTransaction: "abc")
        )
        XCTAssertEqual(sync.path, "/subscription/apple")
        XCTAssertEqual(sync.method, .post)
        XCTAssertNotNil(sync.body)
    }

    func testSubscriptionResponseDecodesSnakeCase() throws {
        let json = """
        {
          "tier": "premium",
          "product_id": "com.gabriel.peppy.premium.yearly",
          "expires_at": "2027-07-26T00:00:00Z",
          "is_premium": true
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(SubscriptionResponse.self, from: json)

        XCTAssertTrue(response.isPremium)
        XCTAssertEqual(response.entitlement.plan, .yearly)
        XCTAssertTrue(response.entitlement.isPremium)
    }

    func testFreeSubscriptionResponseMapsToFreeEntitlement() throws {
        let json = """
        {"tier": "free", "product_id": null, "expires_at": null, "is_premium": false}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SubscriptionResponse.self, from: json)

        XCTAssertEqual(response.entitlement, .free)
    }
}

extension PremiumGatingTests {
    func testLockIsHiddenUntilEntitlementResolves() {
        // Showing a lock at launch would flash "locked" at paying customers.
        XCTAssertFalse(PremiumGate.showsLock(for: .unknown))
    }

    func testLockShownForFreeAccounts() {
        XCTAssertTrue(PremiumGate.showsLock(for: .free))
    }

    func testLockHiddenForPremiumAccounts() {
        XCTAssertFalse(
            PremiumGate.showsLock(for: .premium(plan: .yearly, expires: nil))
        )
    }
}

extension PremiumGatingTests {
    /// The backend nulls `insight` for free accounts (see DashboardService).
    /// If the iOS model keeps the field non-optional the whole summary fails
    /// to decode, so a free user sees the dashboard error card instead of the
    /// locked insight card.
    func testDashboardSummaryDecodesWithNullInsightForFreeAccounts() throws {
        let summary = try Self.decodeDashboardSummary(insightJSON: "null")

        XCTAssertNil(summary.insight)
        // The rest of the payload must survive: the lock replaces one card,
        // it does not blank the dashboard.
        XCTAssertEqual(summary.protocol.title, "Starter protocol")
        XCTAssertEqual(summary.profileStatus, "present")
    }

    func testDashboardSummaryStillDecodesInsightForPremiumAccounts() throws {
        let summary = try Self.decodeDashboardSummary(
            insightJSON: """
            {"id": null, "title": "Your weight trend is accelerating",
             "severity": "info", "empty_message": null, "confidence": 0.82}
            """
        )

        XCTAssertEqual(summary.insight?.title, "Your weight trend is accelerating")
        XCTAssertEqual(summary.insight?.confidence, 0.82)
        XCTAssertEqual(summary.responseSnapshot.weightTrend.count, 1)
        XCTAssertEqual(
            summary.responseSnapshot.weightTrend.first?.date,
            APIDateOnly.date(from: "2026-07-21")
        )
        XCTAssertEqual(summary.responseSnapshot.weightTrend.first?.weightKg, 74.8)
    }

    private static func decodeDashboardSummary(insightJSON: String) throws -> DashboardSummary {
        let json = """
        {
          "generated_at": "2026-07-30T12:00:00Z",
          "profile_status": "present",
          "protocol": {
            "id": "00000000-0000-0000-0000-000000000001",
            "status": "active",
            "title": "Starter protocol",
            "compounds": ["Retatrutide"],
            "start_date": null
          },
          "today_checkin": {"logged": false, "checkin_id": null},
          "response_snapshot": {
            "weight_trend": [{"date": "2026-07-21", "weight_kg": 74.8}],
            "latest_energy": null,
            "latest_mood": null
          },
          "insight": \(insightJSON),
          "connected_context": {
            "healthkit_requested": true,
            "has_labs": false,
            "has_wearables": false
          },
          "recent_activity": []
        }
        """

        let decoder = JSONDecoder()
        // Matches APIClient's configuration.
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DashboardSummary.self, from: Data(json.utf8))
    }
}

extension PremiumGatingTests {
    func testOnlyDataExportIsPremiumGatedInSettings() {
        XCTAssertEqual(SettingsRootViewModel.premiumOnlyRoutes, [.dataExport])
    }

    func testDataExportRowIsFlaggedPremiumOnly() {
        let row = SettingsRootViewModel.myDataRows.first { $0.route == .dataExport }
        XCTAssertEqual(row?.isPremiumOnly, true)
    }

    func testNotificationsStaysFree() {
        // Dose reminders serve free Protocols; locking them would gut the
        // free tier.
        let row = SettingsRootViewModel.myDataRows.first { $0.route == .notifications }
        XCTAssertEqual(row?.isPremiumOnly, false)
    }
}

extension PremiumGatingTests {
    func testPremiumItalicFontResolvesToFraunces() {
        let font = PeppyFonts.premiumItalicUIFont(size: 40)

        // If this fails the .ttf is missing from Copy Bundle Resources and
        // the headline is silently rendering in the system serif fallback.
        XCTAssertEqual(font.familyName, "Fraunces")
        XCTAssertEqual(font.pointSize, 40)
    }
}
