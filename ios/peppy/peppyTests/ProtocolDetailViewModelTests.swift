import Foundation
import XCTest
@testable import peppy

@MainActor
final class ProtocolDetailViewModelTests: XCTestCase {

    // MARK: - Initial selection and dose history

    func testLoadSelectsProtocolAndLoadsDoseHistory() async {
        let api = MockAPIClient()
        api.setMockResponse(ProtocolModel.fixture, for: Endpoint.getProtocol(id: ProtocolModel.fixture.id))
        api.setMockResponse(
            [makeDoseLog(administeredAt: Date(timeIntervalSince1970: 1_783_953_000))],
            for: Endpoint.getDoseLogs(protocolID: ProtocolModel.fixture.id)
        )
        let store = ProtocolStore(api: api)
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)

        await model.load()

        XCTAssertEqual(store.selectedProtocol, ProtocolModel.fixture)
        XCTAssertEqual(model.title, "Retatrutide Titration")
        XCTAssertEqual(model.recentDoseRows.count, 1)
        XCTAssertEqual(
            api.requestLog.map(\.path),
            [
                "/protocols/\(ProtocolModel.fixture.id)",
                "/protocols/\(ProtocolModel.fixture.id)/dose-logs",
            ]
        )
    }

    func testLoadFailureSurfacesErrorWithoutContent() async {
        let api = MockAPIClient()
        api.setMockError(.serverError, for: Endpoint.getProtocol(id: ProtocolModel.fixture.id))
        api.setMockError(.serverError, for: Endpoint.getDoseLogs(protocolID: ProtocolModel.fixture.id))
        let store = ProtocolStore(api: api)
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)

        await model.load()

        XCTAssertNil(model.protocolValue)
        XCTAssertNotNil(model.errorMessage)
    }

    func testDoseHistoryRowsAreFormattedAndLimited() async {
        let api = MockAPIClient()
        api.setMockResponse(ProtocolModel.fixture, for: Endpoint.getProtocol(id: ProtocolModel.fixture.id))
        let logs = (0..<5).map { offset in
            makeDoseLog(administeredAt: Date(timeIntervalSince1970: 1_783_953_000 - Double(offset) * 604_800))
        }
        api.setMockResponse(logs, for: Endpoint.getDoseLogs(protocolID: ProtocolModel.fixture.id))
        let store = ProtocolStore(api: api)
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)

        await model.load()

        XCTAssertEqual(model.recentDoseRows.count, 4)
        XCTAssertTrue(model.hasMoreDoseRows)
        XCTAssertEqual(model.allDoseRows.count, 5)
        XCTAssertEqual(model.recentDoseRows.first?.dateText, "Mon, Jul 13, 2026")
        XCTAssertEqual(model.recentDoseRows.first?.doseText, "2.5 mg")
        XCTAssertEqual(model.recentDoseRows.first?.statusText, "Logged")
    }

    // MARK: - Header and compound presentation

    func testHeaderPresentationForActiveProtocol() async {
        let store = await loadedStore(with: ProtocolModel.fixture)
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)
        await model.load()

        XCTAssertEqual(model.statusText, "Active")
        XCTAssertEqual(model.status, .active)
        XCTAssertEqual(model.startDateText, "Started May 28, 2026")
        XCTAssertEqual(model.endDateText, "Ongoing")
        XCTAssertEqual(model.completedTimelineSteps, 1)
    }

    func testCompoundPresentationDerivesFigmaFields() async throws {
        let store = await loadedStore(with: ProtocolModel.fixture)
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)
        await model.load()

        let compound = try XCTUnwrap(model.compoundDetails.first)
        XCTAssertEqual(compound.name, "Retatrutide")
        XCTAssertEqual(compound.doseChipText, "2.5 mg")
        XCTAssertEqual(compound.doseFrequencyText, "2.5 mg once weekly")
        XCTAssertEqual(compound.routeText, "Subcutaneous injection")
    }

    func testNextDoseDerivesFromLatestLogAndFrequency() async {
        let api = MockAPIClient()
        api.setMockResponse(ProtocolModel.fixture, for: Endpoint.getProtocol(id: ProtocolModel.fixture.id))
        api.setMockResponse(
            [makeDoseLog(administeredAt: Date(timeIntervalSince1970: 1_783_953_000))],
            for: Endpoint.getDoseLogs(protocolID: ProtocolModel.fixture.id)
        )
        let store = ProtocolStore(api: api)
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)

        await model.load()

        XCTAssertEqual(model.compoundDetails.first?.nextDoseDateText, "Mon, Jul 20, 2026")
    }

    func testNextDoseFallsBackToStartDateWithoutLogs() async {
        let store = await loadedStore(with: ProtocolModel.fixture)
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)
        await model.load()

        XCTAssertEqual(model.compoundDetails.first?.nextDoseDateText, "Thu, May 28, 2026")
    }

    // MARK: - Action availability by status

    func testActionAvailabilityForActiveProtocol() async {
        let store = await loadedStore(with: ProtocolModel.fixture)
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)
        await model.load()

        XCTAssertTrue(model.canLogDose)
        XCTAssertTrue(model.canDeactivate)
        XCTAssertFalse(model.canActivate)
        XCTAssertTrue(model.canEdit)
        XCTAssertTrue(model.canDelete)
    }

    func testActionAvailabilityForInactiveProtocol() async {
        let inactive = makeProtocol(setupStatus: "inactive", isActive: false)
        let store = await loadedStore(with: inactive)
        let model = ProtocolDetailViewModel(protocolID: inactive.id, store: store)
        await model.load()

        XCTAssertFalse(model.canLogDose)
        XCTAssertFalse(model.canDeactivate)
        XCTAssertTrue(model.canActivate)
        XCTAssertTrue(model.canEdit)
        XCTAssertTrue(model.canDelete)
    }

    // MARK: - Confirmation outcomes

    func testRequestDeleteSetsPendingConfirmationAndCancelClears() async {
        let store = await loadedStore(with: ProtocolModel.fixture)
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)
        await model.load()

        model.requestDelete()
        XCTAssertEqual(model.pendingConfirmation, .delete)

        model.cancelPendingConfirmation()
        XCTAssertNil(model.pendingConfirmation)
    }

    func testConfirmDeactivateReconcilesStatus() async {
        let api = MockAPIClient()
        api.setMockResponse(ProtocolModel.fixture, for: Endpoint.getProtocol(id: ProtocolModel.fixture.id))
        api.setMockResponse(
            makeProtocol(id: ProtocolModel.fixture.id, setupStatus: "inactive", isActive: false),
            for: Endpoint.deactivateProtocol(id: ProtocolModel.fixture.id)
        )
        let store = ProtocolStore(api: api)
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)
        await model.load()

        model.requestDeactivate()
        XCTAssertEqual(model.pendingConfirmation, .deactivate)

        let succeeded = await model.confirmPendingAction()

        XCTAssertTrue(succeeded)
        XCTAssertNil(model.pendingConfirmation)
        XCTAssertEqual(model.status, .inactive)
        XCTAssertTrue(model.canActivate)
        XCTAssertFalse(model.didDelete)
    }

    func testActivateReconcilesStatus() async {
        let inactive = makeProtocol(setupStatus: "inactive", isActive: false)
        let api = MockAPIClient()
        api.setMockResponse(inactive, for: Endpoint.getProtocol(id: inactive.id))
        api.setMockResponse(
            makeProtocol(id: inactive.id, setupStatus: "active", isActive: true),
            for: Endpoint.activateProtocol(id: inactive.id)
        )
        let store = ProtocolStore(api: api)
        let model = ProtocolDetailViewModel(protocolID: inactive.id, store: store)
        await model.load()

        let succeeded = await model.activate()

        XCTAssertTrue(succeeded)
        XCTAssertEqual(model.status, .active)
        XCTAssertTrue(model.canDeactivate)
    }

    // MARK: - Delete outcomes

    func testConfirmDeleteSuccessSetsNavigationIntent() async {
        let store = await loadedStore(with: ProtocolModel.fixture)
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)
        await model.load()

        model.requestDelete()
        let deleted = await model.confirmPendingAction()

        XCTAssertTrue(deleted)
        XCTAssertTrue(model.didDelete)
        XCTAssertNil(store.selectedProtocol)
        XCTAssertTrue(store.protocols.isEmpty)
    }

    func testConfirmDeleteFailureRetainsProtocolAndSurfacesError() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        api.setMockResponse(ProtocolModel.fixture, for: Endpoint.getProtocol(id: ProtocolModel.fixture.id))
        api.setMockError(.serverError, for: Endpoint.deleteProtocol(id: ProtocolModel.fixture.id))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)
        await model.load()

        model.requestDelete()
        let deleted = await model.confirmPendingAction()

        XCTAssertFalse(deleted)
        XCTAssertFalse(model.didDelete)
        XCTAssertEqual(model.protocolValue, ProtocolModel.fixture)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(store.protocols, [ProtocolModel.fixture])
    }

    // MARK: - Mutation locking

    func testOverlappingMutationIsRejectedWhileRequestInFlight() async {
        let api = MockAPIClient()
        api.setMockResponse(ProtocolModel.fixture, for: Endpoint.getProtocol(id: ProtocolModel.fixture.id))
        api.setMockResponse(
            makeProtocol(id: ProtocolModel.fixture.id, setupStatus: "inactive", isActive: false),
            for: Endpoint.deactivateProtocol(id: ProtocolModel.fixture.id)
        )
        let store = ProtocolStore(api: api)
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)
        await model.load()

        let gate = DetailRequestGate()
        api.onRequest = { endpoint in
            if case .deactivateProtocol = endpoint {
                await gate.wait()
            }
        }

        model.requestDeactivate()
        let firstMutation = Task { await model.confirmPendingAction() }
        await Task.yield()
        while store.mutatingProtocolID == nil {
            await Task.yield()
        }

        XCTAssertTrue(model.isMutating)

        model.requestDelete()
        let rejected = await model.confirmPendingAction()
        XCTAssertFalse(rejected)
        XCTAssertFalse(model.didDelete)

        await gate.open()
        let succeeded = await firstMutation.value
        XCTAssertTrue(succeeded)
        XCTAssertFalse(model.isMutating)
        XCTAssertEqual(model.status, .inactive)
    }

    // MARK: - Route intents

    func testRouteIntentsCarryProtocolContext() async {
        let store = await loadedStore(with: ProtocolModel.fixture)
        let model = ProtocolDetailViewModel(protocolID: ProtocolModel.fixture.id, store: store)
        await model.load()

        XCTAssertEqual(model.editRoute, .edit(ProtocolModel.fixture.id))
        XCTAssertEqual(model.addCompoundRoute, .addCompound(ProtocolModel.fixture.id))
        XCTAssertEqual(
            model.logDoseRoute(compoundID: Compound.fixture.id),
            .logDose(protocolID: ProtocolModel.fixture.id, compoundID: Compound.fixture.id)
        )
        XCTAssertEqual(
            model.editCompoundRoute(compoundID: Compound.fixture.id),
            .editCompound(protocolID: ProtocolModel.fixture.id, compoundID: Compound.fixture.id)
        )
    }

    // MARK: - Helpers

    private func loadedStore(with protocolValue: ProtocolModel) async -> ProtocolStore {
        let api = MockAPIClient()
        api.setMockResponse(protocolValue, for: Endpoint.getProtocol(id: protocolValue.id))
        api.setMockResponse([DoseLog](), for: Endpoint.getDoseLogs(protocolID: protocolValue.id))
        return ProtocolStore(api: api)
    }

    private func makeProtocol(
        id: UUID = UUID(),
        name: String = "Retatrutide Titration",
        setupStatus: String? = "active",
        isActive: Bool = true,
        compounds: [Compound] = [.fixture]
    ) -> ProtocolModel {
        ProtocolModel(
            id: id,
            name: name,
            startDate: Date(timeIntervalSince1970: 1_780_000_000),
            endDate: nil,
            notes: nil,
            isActive: isActive,
            setupStatus: setupStatus,
            isStarter: false,
            compounds: compounds
        )
    }

    private func makeDoseLog(
        administeredAt: Date,
        compoundID: UUID = Compound.fixture.id
    ) -> DoseLog {
        DoseLog(
            id: UUID(),
            protocolID: ProtocolModel.fixture.id,
            compoundID: compoundID,
            dose: 2.5,
            unit: "mg",
            administeredAt: administeredAt,
            route: "subcutaneous",
            notes: nil
        )
    }
}

/// Suspends gated requests until opened, so tests can order overlapping responses.
private actor DetailRequestGate {
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
