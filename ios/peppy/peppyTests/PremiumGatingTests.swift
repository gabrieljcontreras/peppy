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
