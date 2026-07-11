import XCTest
@testable import peppy

@MainActor
final class ProtocolNavigationTests: XCTestCase {

    // MARK: - Coordinator

    func testShowRouteSwitchesToProtocolsTab() {
        let coordinator = ProtocolNavigationCoordinator()
        XCTAssertEqual(coordinator.selectedTab, .home)

        coordinator.show(.detail(ProtocolModel.fixture.id))

        XCTAssertEqual(coordinator.selectedTab, .protocols)
        XCTAssertEqual(coordinator.path, [.detail(ProtocolModel.fixture.id)])
    }

    func testShowRouteReplacesExistingPath() {
        let coordinator = ProtocolNavigationCoordinator()
        coordinator.path = [.create, .addCompound(ProtocolModel.fixture.id)]

        coordinator.show(.detail(ProtocolModel.fixture.id))

        XCTAssertEqual(coordinator.path, [.detail(ProtocolModel.fixture.id)])
    }

    // MARK: - Dashboard card routing

    func testPendingSetupSummaryRoutesToStarterSetup() throws {
        let summary = DashboardSummary.mockPendingStarter.protocol
        let protocolID = try XCTUnwrap(summary.id)

        XCTAssertEqual(
            summary.protocolRoute,
            .starterSetup(protocolID: protocolID, compounds: ["Retatrutide"])
        )
    }

    func testConfiguredSummaryRoutesToDetail() {
        let id = UUID()
        let summary = DashboardProtocolSummary(
            id: id,
            status: "active",
            title: "Retatrutide Titration",
            compounds: ["Retatrutide"]
        )

        XCTAssertEqual(summary.protocolRoute, .detail(id))
    }

    func testMissingProtocolSummaryRoutesToCreate() {
        let summary = DashboardProtocolSummary(
            id: nil,
            status: "missing",
            title: "Create your protocol",
            compounds: []
        )

        XCTAssertEqual(summary.protocolRoute, .create)
    }

    // MARK: - Dashboard reload signaling

    func testSuccessfulMutationTriggersDashboardReload() async {
        let api = MockAPIClient()
        api.setMockResponse(DashboardSummary.mockPendingStarter, for: Endpoint.getDashboardSummary)
        api.setMockResponse(makeDoseLog(), for: Endpoint.createDoseLog(.fixture))
        let store = ProtocolStore(api: api)
        let model = DashboardViewModel(
            api: api,
            protocolStore: store,
            hasProfileAttachFailure: false
        )
        await model.load()
        XCTAssertEqual(dashboardLoadCount(api), 1)

        let logged = await store.logDose(.fixture)
        XCTAssertNotNil(logged)

        await model.refreshIfProtocolStateChanged()

        XCTAssertEqual(dashboardLoadCount(api), 2)
    }

    func testFailedMutationDoesNotTriggerDashboardReload() async {
        let api = MockAPIClient()
        api.setMockResponse(DashboardSummary.mockPendingStarter, for: Endpoint.getDashboardSummary)
        api.setMockError(.serverError, for: Endpoint.createDoseLog(.fixture))
        let store = ProtocolStore(api: api)
        let model = DashboardViewModel(
            api: api,
            protocolStore: store,
            hasProfileAttachFailure: false
        )
        await model.load()

        let logged = await store.logDose(.fixture)
        XCTAssertNil(logged)

        await model.refreshIfProtocolStateChanged()

        XCTAssertEqual(dashboardLoadCount(api), 1)
    }

    func testRefreshWithoutProtocolChangesDoesNotReload() async {
        let api = MockAPIClient()
        api.setMockResponse(DashboardSummary.mockPendingStarter, for: Endpoint.getDashboardSummary)
        let store = ProtocolStore(api: api)
        let model = DashboardViewModel(
            api: api,
            protocolStore: store,
            hasProfileAttachFailure: false
        )
        await model.load()

        await model.refreshIfProtocolStateChanged()

        XCTAssertEqual(dashboardLoadCount(api), 1)
    }

    func testMutationBeforeFirstLoadStillReloadsOnce() async {
        let api = MockAPIClient()
        api.setMockResponse(DashboardSummary.mockPendingStarter, for: Endpoint.getDashboardSummary)
        api.setMockResponse(makeDoseLog(), for: Endpoint.createDoseLog(.fixture))
        let store = ProtocolStore(api: api)

        // Mutation lands while the Dashboard has not loaded yet (e.g. user went
        // straight to the Protocols tab after launch).
        let logged = await store.logDose(.fixture)
        XCTAssertNotNil(logged)

        let model = DashboardViewModel(
            api: api,
            protocolStore: store,
            hasProfileAttachFailure: false
        )
        await model.load()
        XCTAssertEqual(dashboardLoadCount(api), 1)

        // The load already reflects the mutated state; no second fetch needed.
        await model.refreshIfProtocolStateChanged()
        XCTAssertEqual(dashboardLoadCount(api), 1)
    }

    // MARK: - Helpers

    private func dashboardLoadCount(_ api: MockAPIClient) -> Int {
        api.requestLog.filter { $0.requestID == Endpoint.getDashboardSummary.requestID }.count
    }

    private func makeDoseLog() -> DoseLog {
        DoseLog(
            id: UUID(),
            protocolID: ProtocolModel.fixture.id,
            compoundID: Compound.fixture.id,
            dose: 2.5,
            unit: "mg",
            administeredAt: Date(timeIntervalSince1970: 1_783_953_000),
            route: "subcutaneous",
            notes: nil
        )
    }
}
