import XCTest
@testable import peppy

@MainActor
final class StarterProtocolViewModelTests: XCTestCase {
    func testActivationRequiresDoseFrequencyRouteAndStartDate() {
        let model = StarterProtocolViewModel(
            protocolID: UUID(),
            compounds: ["Retatrutide"],
            store: ProtocolStore(api: MockAPIClient())
        )

        XCTAssertFalse(model.canSave)
        XCTAssertEqual(model.validationMessage, "Dose, frequency, route, and start date are required.")
    }

    func testCompleteCompoundCanSave() {
        let model = StarterProtocolViewModel(
            protocolID: UUID(),
            compounds: ["Retatrutide"],
            store: ProtocolStore(api: MockAPIClient())
        )
        model.doseText = "2"
        model.frequency = "weekly"
        model.route = "subcutaneous"
        model.startDate = Date()

        XCTAssertTrue(model.canSave)
        XCTAssertNil(model.validationMessage)
    }

    func testStartDateDefaultsToTodaySoOnlyDoseFrequencyRouteAreOutstanding() {
        let model = StarterProtocolViewModel(
            protocolID: UUID(),
            compounds: ["Retatrutide"],
            store: ProtocolStore(api: MockAPIClient())
        )

        XCTAssertNotNil(model.startDate)
    }

    func testSavePostsActivationRequestThroughStoreWhenValid() async {
        let api = MockAPIClient()
        let protocolID = UUID()
        let startDate = Date(timeIntervalSince1970: 1_788_000_000)
        let activated = ProtocolModel.fixture
        api.setMockResponse(activated, for: Endpoint.getProtocol(id: protocolID))
        let store = ProtocolStore(api: api)
        let model = StarterProtocolViewModel(
            protocolID: protocolID,
            compounds: ["Retatrutide"],
            store: store
        )
        model.doseText = "2"
        model.frequency = "weekly"
        model.route = "subcutaneous"
        model.startDate = startDate

        let didSave = await model.save()

        XCTAssertTrue(didSave)
        guard let endpoint = api.requestLog.first,
              case .activateStarterProtocol(let id, let request) = endpoint else {
            return XCTFail("Expected activate starter protocol endpoint")
        }
        XCTAssertEqual(id, protocolID)
        XCTAssertEqual(request.doseMg, 2)
        XCTAssertEqual(request.doseUnit, "mg")
        XCTAssertEqual(request.frequency, "weekly")
        XCTAssertEqual(request.administrationRoute, "subcutaneous")
        XCTAssertEqual(request.startDate, startDate)
    }

    func testSaveReconcilesStoreStateOnSuccess() async {
        let api = MockAPIClient()
        let protocolID = ProtocolModel.fixture.id
        api.setMockResponse([], for: Endpoint.getProtocols)
        api.setMockResponse(ProtocolModel.fixture, for: Endpoint.getProtocol(id: protocolID))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()
        let model = StarterProtocolViewModel(
            protocolID: protocolID,
            compounds: ["Retatrutide"],
            store: store
        )
        model.doseText = "2"
        model.frequency = "weekly"
        model.route = "subcutaneous"
        model.startDate = Date()

        let didSave = await model.save()

        XCTAssertTrue(didSave)
        XCTAssertEqual(store.protocols, [ProtocolModel.fixture])
    }

    func testSaveBumpsStoreRevisionOnSuccess() async {
        let api = MockAPIClient()
        let protocolID = ProtocolModel.fixture.id
        api.setMockResponse(ProtocolModel.fixture, for: Endpoint.getProtocol(id: protocolID))
        let store = ProtocolStore(api: api)
        let model = StarterProtocolViewModel(
            protocolID: protocolID,
            compounds: ["Retatrutide"],
            store: store
        )
        model.doseText = "2"
        model.frequency = "weekly"
        model.route = "subcutaneous"
        model.startDate = Date()

        _ = await model.save()

        XCTAssertEqual(store.revision, 1)
    }

    func testSaveSucceedsWhenPostSucceedsButRefetchFailsOnUnloadedStore() async {
        let api = MockAPIClient()
        let protocolID = UUID()
        // The store is never loaded (no protocols, no selection) — the Dashboard
        // entry path, which builds the starter route from its own summary response.
        // POST succeeds (no mock error registered); the confirming refetch fails.
        api.setMockError(.serverError, for: Endpoint.getProtocol(id: protocolID))
        let store = ProtocolStore(api: api)
        let model = StarterProtocolViewModel(
            protocolID: protocolID,
            compounds: ["Retatrutide"],
            store: store
        )
        model.doseText = "2"
        model.frequency = "weekly"
        model.route = "subcutaneous"
        model.startDate = Date()

        let didSave = await model.save()

        XCTAssertTrue(
            didSave,
            "POST succeeded server-side; save must report success even when the store has no local copy"
        )
        XCTAssertNil(model.saveErrorMessage)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.revision, 1)
    }

    func testSaveFailureRetainsDraftSetsErrorAndDoesNotBumpRevision() async {
        let api = MockAPIClient()
        let protocolID = UUID()
        let startDate = Date(timeIntervalSince1970: 1_788_000_000)
        api.setMockError(.serverError, for: Endpoint.activateStarterProtocol(
            id: protocolID,
            StarterProtocolActivationRequest(
                doseMg: 2,
                doseUnit: "mg",
                frequency: "weekly",
                administrationRoute: "subcutaneous",
                startDate: startDate
            )
        ))
        let store = ProtocolStore(api: api)
        let model = StarterProtocolViewModel(
            protocolID: protocolID,
            compounds: ["Retatrutide"],
            store: store
        )
        model.doseText = "2"
        model.frequency = "weekly"
        model.route = "subcutaneous"
        model.startDate = startDate

        let didSave = await model.save()

        XCTAssertFalse(didSave)
        XCTAssertEqual(model.doseText, "2")
        XCTAssertEqual(model.frequency, "weekly")
        XCTAssertEqual(model.route, "subcutaneous")
        XCTAssertEqual(model.startDate, startDate)
        XCTAssertEqual(model.saveErrorMessage, APIError.serverError.userMessage)
        XCTAssertEqual(store.revision, 0)
    }

    func testSaveRejectsDuplicateWhileSaving() async {
        let api = MockAPIClient()
        let protocolID = ProtocolModel.fixture.id
        api.setMockResponse(ProtocolModel.fixture, for: Endpoint.getProtocol(id: protocolID))
        let store = ProtocolStore(api: api)
        let model = StarterProtocolViewModel(
            protocolID: protocolID,
            compounds: ["Retatrutide"],
            store: store
        )
        model.doseText = "2"
        model.frequency = "weekly"
        model.route = "subcutaneous"
        model.startDate = Date()

        let gate = RequestGate()
        let started = expectation(description: "save started")
        api.onRequest = { endpoint in
            if case .activateStarterProtocol = endpoint {
                started.fulfill()
                await gate.wait()
            }
        }

        let firstSave = Task { await model.save() }
        await fulfillment(of: [started], timeout: 2)

        XCTAssertTrue(model.isSaving)
        let duplicate = await model.save()
        XCTAssertFalse(duplicate)
        let activationRequests = api.requestLog.filter {
            if case .activateStarterProtocol = $0 { return true }
            return false
        }
        XCTAssertEqual(activationRequests.count, 1)

        await gate.open()
        let firstResult = await firstSave.value

        XCTAssertTrue(firstResult)
        XCTAssertFalse(model.isSaving)
    }
}

/// Suspends gated requests until opened, so tests can order overlapping saves.
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
