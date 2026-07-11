import XCTest
@testable import peppy

@MainActor
final class DashboardViewModelTests: XCTestCase {
    func testLoadDashboardSummaryShowsLoadedState() async {
        let api = MockAPIClient()
        let summary = DashboardSummary.mockPendingStarter
        api.setMockResponse(summary, for: "/dashboard/summary")
        let model = DashboardViewModel(api: api, hasProfileAttachFailure: false)

        await model.load()

        XCTAssertEqual(model.state.summary?.protocol.status, "pending_setup")
        XCTAssertFalse(model.state.isLoading)
        XCTAssertNil(model.state.errorMessage)
    }

    func testProfileAttachFailureShowsSyncRecoveryCard() async {
        let api = MockAPIClient()
        api.setMockResponse(DashboardSummary.mockMissingProfile, for: "/dashboard/summary")
        let model = DashboardViewModel(api: api, hasProfileAttachFailure: true)

        await model.load()

        XCTAssertTrue(model.state.showsProfileSyncRecovery)
    }

    func testPendingStarterSummaryPrefersFinishSetupAction() async {
        let api = MockAPIClient()
        api.setMockResponse(DashboardSummary.mockPendingStarter, for: "/dashboard/summary")
        let model = DashboardViewModel(api: api, hasProfileAttachFailure: false)

        await model.load()

        XCTAssertEqual(model.state.summary?.protocol.status, "pending_setup")
        XCTAssertEqual(model.state.summary?.protocol.title, "Starter protocol")
    }

    // MARK: - Protocol card presentation

    func testInactiveSummaryPresentsPastProtocolCard() {
        let summary = DashboardProtocolSummary(
            id: UUID(),
            status: "inactive",
            title: "Retatrutide Titration",
            compounds: ["Retatrutide"]
        )

        XCTAssertEqual(summary.cardTitle, "Past protocol")
        XCTAssertEqual(summary.badgeText, "Inactive")
        XCTAssertEqual(summary.badgeType, .neutral)
        XCTAssertEqual(summary.actionTitle, "View protocol")
    }

    func testActiveSummaryPresentsActiveProtocolCard() {
        let summary = DashboardProtocolSummary(
            id: UUID(),
            status: "active",
            title: "Retatrutide Titration",
            compounds: ["Retatrutide"]
        )

        XCTAssertEqual(summary.cardTitle, "Active protocol")
        XCTAssertEqual(summary.badgeText, "Active")
        XCTAssertEqual(summary.badgeType, .success)
        XCTAssertEqual(summary.actionTitle, "View protocol")
    }

    func testPendingSetupSummaryPresentsStarterCard() {
        let summary = DashboardSummary.mockPendingStarter.protocol

        XCTAssertEqual(summary.cardTitle, "Starter protocol")
        XCTAssertEqual(summary.badgeText, "Needs setup")
        XCTAssertEqual(summary.badgeType, .warning)
        XCTAssertEqual(summary.actionTitle, "Finish setup")
    }
}
