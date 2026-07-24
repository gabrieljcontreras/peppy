import XCTest
@testable import peppy

@MainActor
final class AccountSecurityViewModelTests: XCTestCase {
    func testPasswordMismatchIsRejectedBeforeCallingServer() async {
        let fixture = Fixture()
        fixture.model.currentPassword = "old-pass-1"
        fixture.model.newPassword = "replacement-2"
        fixture.model.confirmNewPassword = "different-3"

        await fixture.model.changePassword()

        XCTAssertTrue(fixture.api.requestLog.isEmpty)
        XCTAssertEqual(
            fixture.model.errorMessage,
            "New passwords do not match."
        )
        XCTAssertEqual(fixture.finishSignedOutCallCount, 0)
    }

    func testShortPasswordIsRejectedBeforeCallingServer() async {
        let fixture = Fixture()
        fixture.model.currentPassword = "old-pass-1"
        fixture.model.newPassword = "short"
        fixture.model.confirmNewPassword = "short"

        await fixture.model.changePassword()

        XCTAssertTrue(fixture.api.requestLog.isEmpty)
        XCTAssertEqual(
            fixture.model.errorMessage,
            "New password must be at least 8 characters."
        )
        XCTAssertEqual(fixture.finishSignedOutCallCount, 0)
    }

    func testPasswordServerFailureRetainsSignedInSessionAndFields() async {
        let fixture = Fixture()
        fixture.model.currentPassword = "old-pass-1"
        fixture.model.newPassword = "replacement-2"
        fixture.model.confirmNewPassword = "replacement-2"
        fixture.api.setMockError(
            .validationFailed(["Current password is incorrect."]),
            for: .changePassword(
                ChangePasswordRequest(
                    currentPassword: "old-pass-1",
                    newPassword: "replacement-2"
                )
            )
        )

        await fixture.model.changePassword()

        XCTAssertEqual(fixture.finishSignedOutCallCount, 0)
        XCTAssertEqual(fixture.removeDeviceSettingsCallCount, 0)
        XCTAssertEqual(fixture.model.currentPassword, "old-pass-1")
        XCTAssertEqual(fixture.model.newPassword, "replacement-2")
        XCTAssertEqual(
            fixture.model.errorMessage,
            "Current password is incorrect."
        )
    }

    func testSuccessfulPasswordChangeFinishesSignedOutSessionOnce() async {
        let fixture = Fixture()
        fixture.model.currentPassword = "old-pass-1"
        fixture.model.newPassword = "replacement-2"
        fixture.model.confirmNewPassword = "replacement-2"

        await fixture.model.changePassword()

        XCTAssertEqual(fixture.finishSignedOutCallCount, 1)
        XCTAssertEqual(fixture.removeDeviceSettingsCallCount, 0)
        XCTAssertEqual(
            fixture.api.requestLog.map(\.requestID),
            ["POST /auth/change-password"]
        )
    }

    func testAccountActionsAreMutuallyExclusiveWhileRequestIsInFlight() async {
        let fixture = Fixture()
        let requestStarted = expectation(description: "password request started")
        var releaseRequest: CheckedContinuation<Void, Never>?
        fixture.model.currentPassword = "old-pass-1"
        fixture.model.newPassword = "replacement-2"
        fixture.model.confirmNewPassword = "replacement-2"
        fixture.model.deletionPassword = "old-pass-1"
        fixture.api.onRequest = { endpoint in
            guard case .changePassword = endpoint else { return }
            requestStarted.fulfill()
            await withCheckedContinuation { continuation in
                releaseRequest = continuation
            }
        }

        let passwordChange = Task {
            await fixture.model.changePassword()
        }
        await fulfillment(of: [requestStarted])

        XCTAssertTrue(fixture.model.isAccountActionInFlight)
        fixture.model.requestAccountDeletion()
        XCTAssertFalse(fixture.model.isDeleteConfirmationPresented)

        releaseRequest?.resume()
        await passwordChange.value

        XCTAssertFalse(fixture.model.isAccountActionInFlight)
    }

    func testDeleteRequiresPasswordAndSeparateFinalConfirmation() async {
        let fixture = Fixture()

        fixture.model.requestAccountDeletion()

        XCTAssertFalse(fixture.model.isDeleteConfirmationPresented)
        XCTAssertEqual(
            fixture.model.errorMessage,
            "Enter your current password to continue."
        )
        XCTAssertTrue(fixture.api.requestLog.isEmpty)

        fixture.model.deletionPassword = "old-pass-1"
        fixture.model.requestAccountDeletion()

        XCTAssertTrue(fixture.model.isDeleteConfirmationPresented)
        XCTAssertTrue(fixture.api.requestLog.isEmpty)
        XCTAssertEqual(fixture.finishSignedOutCallCount, 0)
    }

    func testDeleteFailurePreservesConfirmationAndSignedInState() async {
        let fixture = Fixture()
        fixture.model.deletionPassword = "old-pass-1"
        fixture.model.requestAccountDeletion()
        fixture.api.setMockError(
            .validationFailed(["Current password is incorrect."]),
            for: .deleteAccount(
                DeleteAccountRequest(currentPassword: "old-pass-1")
            )
        )

        await fixture.model.confirmAccountDeletion()

        XCTAssertTrue(fixture.model.isDeleteConfirmationPresented)
        XCTAssertEqual(fixture.model.deletionPassword, "old-pass-1")
        XCTAssertEqual(fixture.finishSignedOutCallCount, 0)
        XCTAssertEqual(fixture.removeDeviceSettingsCallCount, 0)
        XCTAssertEqual(
            fixture.model.errorMessage,
            "Current password is incorrect."
        )
    }

    func testSuccessfulDeleteClearsDeviceSettingsAndFinishesSession() async {
        let fixture = Fixture()
        fixture.model.deletionPassword = "old-pass-1"
        fixture.model.requestAccountDeletion()

        await fixture.model.confirmAccountDeletion()

        XCTAssertEqual(
            fixture.api.requestLog.map(\.requestID),
            ["DELETE /auth/account"]
        )
        XCTAssertEqual(fixture.removeDeviceSettingsCallCount, 1)
        XCTAssertEqual(fixture.finishSignedOutCallCount, 1)
    }

    private final class Fixture {
        let api = MockAPIClient()
        private(set) var finishSignedOutCallCount = 0
        private(set) var removeDeviceSettingsCallCount = 0
        lazy var model = AccountSecurityViewModel(
            api: api,
            finishSignedOutSession: { [weak self] in
                self?.finishSignedOutCallCount += 1
            },
            removeDeviceSettings: { [weak self] in
                self?.removeDeviceSettingsCallCount += 1
            }
        )
    }
}
