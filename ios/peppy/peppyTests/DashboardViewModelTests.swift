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
}
