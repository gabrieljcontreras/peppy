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

    func testDashboardFailureUsesActiveProtocolFromStore() async {
        let api = MockAPIClient()
        api.setMockError(.serverError, for: Endpoint.getDashboardSummary)
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let store = ProtocolStore(api: api)
        let model = DashboardViewModel(
            api: api,
            protocolStore: store,
            hasProfileAttachFailure: false
        )

        await model.load()

        XCTAssertEqual(model.state.summary?.protocol.id, ProtocolModel.fixture.id)
        XCTAssertEqual(model.state.summary?.protocol.status, "active")
        XCTAssertEqual(model.state.summary?.protocol.title, ProtocolModel.fixture.name)
        XCTAssertEqual(
            model.state.summary?.protocol.compounds,
            ProtocolModel.fixture.compounds.map(\.name)
        )
    }

    func testMissingDashboardSummaryUsesActiveProtocolFromStore() async {
        let api = MockAPIClient()
        api.setMockResponse(DashboardSummary.mockMissingProfile, for: Endpoint.getDashboardSummary)
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let store = ProtocolStore(api: api)
        let model = DashboardViewModel(
            api: api,
            protocolStore: store,
            hasProfileAttachFailure: false
        )

        await model.load()

        XCTAssertEqual(model.state.summary?.protocol.id, ProtocolModel.fixture.id)
        XCTAssertEqual(model.state.summary?.protocol.status, "active")
        XCTAssertEqual(model.state.summary?.protocol.title, ProtocolModel.fixture.name)
    }

    func testMissingDashboardSummaryRefreshesPreviouslyEmptyProtocolStore() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel](), for: Endpoint.getProtocols)
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        api.setMockResponse(DashboardSummary.mockMissingProfile, for: Endpoint.getDashboardSummary)
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let model = DashboardViewModel(
            api: api,
            protocolStore: store,
            hasProfileAttachFailure: false
        )

        await model.load()

        XCTAssertEqual(model.state.summary?.protocol.id, ProtocolModel.fixture.id)
        XCTAssertEqual(model.state.summary?.protocol.status, "active")
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

    func testMissingSummaryPresentsCreateProtocolCard() {
        let summary = DashboardSummary.mockMissingProfile.protocol

        XCTAssertEqual(summary.cardTitle, "Protocol")
        XCTAssertEqual(summary.badgeText, "Not started")
        XCTAssertEqual(summary.badgeType, .neutral)
        XCTAssertEqual(summary.actionTitle, "Create protocol")
    }

    func testPendingSetupSummaryPresentsStarterCard() {
        let summary = DashboardSummary.mockPendingStarter.protocol

        XCTAssertEqual(summary.cardTitle, "Starter protocol")
        XCTAssertEqual(summary.badgeText, "Needs setup")
        XCTAssertEqual(summary.badgeType, .warning)
        XCTAssertEqual(summary.actionTitle, "Finish setup")
    }
}
