import XCTest
@testable import peppy

@MainActor
final class ProtocolListViewModelTests: XCTestCase {
    func testProtocolRoutesAreHashableAndPreserveValues() {
        let protocolID = UUID()
        let compoundID = UUID()

        XCTAssertEqual(ProtocolRoute.detail(protocolID), ProtocolRoute.detail(protocolID))
        XCTAssertEqual(ProtocolRoute.create, ProtocolRoute.create)
        XCTAssertEqual(ProtocolRoute.edit(protocolID), ProtocolRoute.edit(protocolID))
        XCTAssertEqual(ProtocolRoute.addCompound(protocolID), ProtocolRoute.addCompound(protocolID))
        XCTAssertEqual(
            ProtocolRoute.editCompound(protocolID: protocolID, compoundID: compoundID),
            ProtocolRoute.editCompound(protocolID: protocolID, compoundID: compoundID)
        )
        XCTAssertEqual(
            ProtocolRoute.logDose(protocolID: protocolID, compoundID: compoundID),
            ProtocolRoute.logDose(protocolID: protocolID, compoundID: compoundID)
        )
        XCTAssertEqual(
            ProtocolRoute.starterSetup(protocolID: protocolID, compounds: ["Retatrutide"]),
            ProtocolRoute.starterSetup(protocolID: protocolID, compounds: ["Retatrutide"])
        )
    }

    func testInitialLoadShowsLoadingThenLoadedRows() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let store = ProtocolStore(api: api)
        let model = ProtocolListViewModel(store: store)
        let gate = RequestGate()
        let started = expectation(description: "load started")
        api.onRequest = { endpoint in
            if case .getProtocols = endpoint {
                started.fulfill()
                await gate.wait()
            }
        }

        let load = Task { await model.loadIfNeeded() }
        await fulfillment(of: [started], timeout: 2)

        XCTAssertEqual(model.state, .loading)

        await gate.open()
        await load.value

        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.activeRows.map(\.title), ["Retatrutide Titration"])
        XCTAssertTrue(model.historyRows.isEmpty)
    }

    func testLoadedListSeparatesActiveAndHistoryRows() async {
        let inactive = ProtocolModel.fixture.replacing(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Semaglutide Starter",
            endDate: Date(timeIntervalSince1970: 1_780_000_000 + 84 * 86_400),
            isActive: false,
            setupStatus: "inactive"
        )
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture, inactive], for: Endpoint.getProtocols)
        let model = ProtocolListViewModel(store: ProtocolStore(api: api))

        await model.loadIfNeeded()

        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.activeRows.count, 1)
        XCTAssertEqual(model.historyRows.count, 1)
        XCTAssertEqual(model.activeCountText, "1")
        XCTAssertEqual(model.historyCountText, "1")
        XCTAssertEqual(model.activeRows.first?.title, "Retatrutide Titration")
        XCTAssertEqual(model.activeRows.first?.statusText, "Active")
        XCTAssertEqual(model.activeRows.first?.timelineText, "Active plan")
        XCTAssertEqual(model.activeRows.first?.dateRangeText, "Started May 28, 2026")
        XCTAssertEqual(model.activeRows.first?.compoundSummary, "Retatrutide")
        XCTAssertEqual(model.activeRows.first?.doseSummary, "2.5 mg")
        XCTAssertEqual(model.activeRows.first?.scheduleSummary, "weekly")
        XCTAssertEqual(model.activeRows.first?.scheduleDisplayText, "Weekly")
        XCTAssertEqual(model.activeRows.first?.startMarkerText, "May 28")
        XCTAssertEqual(model.activeRows.first?.statusMarkerText, "Active")
        XCTAssertEqual(model.activeRows.first?.endMarkerText, "Ongoing")
        XCTAssertEqual(model.activeRows.first?.completedTimelineSteps, 1)
        XCTAssertEqual(model.historyRows.first?.title, "Semaglutide Starter")
        XCTAssertEqual(model.historyRows.first?.statusText, "Inactive")
        XCTAssertEqual(model.historyRows.first?.timelineText, "12 weeks")
        XCTAssertEqual(model.historyRows.first?.dateRangeText, "May 28, 2026 - Aug 20, 2026")
        XCTAssertEqual(model.historyRows.first?.endMarkerText, "Aug 20")
        XCTAssertEqual(model.historyRows.first?.completedTimelineSteps, 2)
        XCTAssertEqual(model.route(for: ProtocolModel.fixture), .detail(ProtocolModel.fixture.id))
        XCTAssertEqual(model.createRoute, .create)
    }

    func testDateOnlyRowsDisplayInUTCRegardlessOfLocalTimezone() async {
        let startDate = Self.utcDate(year: 2026, month: 7, day: 1)
        let endDate = Self.utcDate(year: 2026, month: 7, day: 29)
        let protocolValue = ProtocolModel.fixture.replacing(
            startDate: startDate,
            endDate: endDate
        )
        let api = MockAPIClient()
        api.setMockResponse([protocolValue], for: Endpoint.getProtocols)
        let model = ProtocolListViewModel(store: ProtocolStore(api: api))

        await model.loadIfNeeded()

        XCTAssertEqual(model.activeRows.first?.dateRangeText, "Jul 1, 2026 - Jul 29, 2026")
        XCTAssertEqual(model.activeRows.first?.timelineText, "Planned for 4 weeks")
        XCTAssertEqual(model.activeRows.first?.startMarkerText, "Jul 1")
        XCTAssertEqual(model.activeRows.first?.endMarkerText, "Jul 29")
    }

    func testPendingSetupRowsRouteToStarterSetup() async {
        let pending = ProtocolModel.fixture.replacing(
            setupStatus: "pending_setup",
            isStarter: true
        )
        let api = MockAPIClient()
        api.setMockResponse([pending], for: Endpoint.getProtocols)
        let model = ProtocolListViewModel(store: ProtocolStore(api: api))

        await model.loadIfNeeded()

        XCTAssertEqual(model.activeRows.first?.statusText, "Needs setup")
        XCTAssertEqual(
            model.activeRows.first?.route,
            .starterSetup(protocolID: pending.id, compounds: ["Retatrutide"])
        )
        XCTAssertEqual(
            model.route(for: pending),
            .starterSetup(protocolID: pending.id, compounds: ["Retatrutide"])
        )
    }

    func testEmptyStateAfterSuccessfulLoad() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel](), for: Endpoint.getProtocols)
        let model = ProtocolListViewModel(store: ProtocolStore(api: api))

        await model.loadIfNeeded()

        XCTAssertEqual(model.state, .empty)
        XCTAssertTrue(model.activeRows.isEmpty)
        XCTAssertTrue(model.historyRows.isEmpty)
    }

    func testRetryStateCanRecoverAfterInitialFailure() async {
        let api = MockAPIClient()
        api.setMockError(.serverError, for: Endpoint.getProtocols)
        let model = ProtocolListViewModel(store: ProtocolStore(api: api))

        await model.loadIfNeeded()

        XCTAssertEqual(model.state, .failed(APIError.serverError.userMessage))

        api.clearMocks()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        await model.retry()

        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.activeRows.map(\.title), ["Retatrutide Titration"])
    }

    func testRefreshFailureRetainsLoadedRowsAndExposesInlineError() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let model = ProtocolListViewModel(store: ProtocolStore(api: api))
        await model.loadIfNeeded()

        api.clearMocks()
        api.setMockError(.networkUnavailable, for: Endpoint.getProtocols)
        await model.refresh()

        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.activeRows.map(\.title), ["Retatrutide Titration"])
        XCTAssertEqual(model.refreshErrorMessage, APIError.networkUnavailable.userMessage)
    }

    func testLoadIfNeededDoesNotRefetchLoadedProtocols() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let model = ProtocolListViewModel(store: ProtocolStore(api: api))

        await model.loadIfNeeded()
        await model.loadIfNeeded()

        XCTAssertEqual(api.requestLog.map(\.requestID), ["GET /protocols"])
    }

    private static func utcDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        return components.date!
    }
}

private actor RequestGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuations.append($0) }
    }

    func open() {
        isOpen = true
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }
}

private extension ProtocolModel {
    func replacing(
        id: UUID? = nil,
        name: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        notes: String? = nil,
        isActive: Bool? = nil,
        setupStatus: String? = nil,
        isStarter: Bool? = nil,
        compounds: [Compound]? = nil
    ) -> ProtocolModel {
        ProtocolModel(
            id: id ?? self.id,
            name: name ?? self.name,
            startDate: startDate ?? self.startDate,
            endDate: endDate ?? self.endDate,
            notes: notes ?? self.notes,
            isActive: isActive ?? self.isActive,
            setupStatus: setupStatus ?? self.setupStatus,
            isStarter: isStarter ?? self.isStarter,
            compounds: compounds ?? self.compounds
        )
    }
}
