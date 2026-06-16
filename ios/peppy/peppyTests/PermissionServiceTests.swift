import XCTest
@testable import peppy

final class PermissionServiceTests: XCTestCase {
    func testMockHealthServiceReturnsConfiguredOutcome() async {
        let service = MockHealthKitService(outcome: .unavailable)
        let outcome = await service.requestReadAccess()

        XCTAssertEqual(outcome, .unavailable)
    }

    func testMockNotificationServiceReturnsConfiguredOutcome() async {
        let service = MockNotificationPermissionService(outcome: .denied)
        let outcome = await service.requestAuthorization()

        XCTAssertEqual(outcome, .denied)
    }
}
