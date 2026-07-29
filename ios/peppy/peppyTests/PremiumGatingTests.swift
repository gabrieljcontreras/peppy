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
    func testPremiumItalicFontResolvesToFraunces() {
        let font = PeppyFonts.premiumItalicUIFont(size: 40)

        // If this fails the .ttf is missing from Copy Bundle Resources and
        // the headline is silently rendering in the system serif fallback.
        XCTAssertEqual(font.familyName, "Fraunces")
        XCTAssertEqual(font.pointSize, 40)
    }
}
