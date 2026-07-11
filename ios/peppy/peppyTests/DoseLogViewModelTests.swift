import XCTest
@testable import peppy

@MainActor
final class DoseLogViewModelTests: XCTestCase {
    private var api: MockAPIClient!
    private var store: ProtocolStore!

    override func setUp() async throws {
        try await super.setUp()
        api = MockAPIClient()
        store = ProtocolStore(api: api)
    }

    override func tearDown() async throws {
        api = nil
        store = nil
        try await super.tearDown()
    }

    // MARK: - Preselected context

    func testPreselectedContextPrefillsDraftFromCompound() {
        let now = Date(timeIntervalSince1970: 1_783_953_000)
        let model = DoseLogViewModel(
            protocol: .fixture,
            compound: .fixture,
            store: store,
            now: now
        )

        XCTAssertEqual(model.doseText, "2.5")
        XCTAssertEqual(model.unit, "mg")
        XCTAssertEqual(model.route, "subcutaneous")
        XCTAssertEqual(model.notes, "")
        XCTAssertEqual(model.administeredAt, now)
        XCTAssertEqual(model.compoundName, "Retatrutide")
        XCTAssertEqual(model.protocolName, "Retatrutide Titration")
        XCTAssertEqual(model.scheduledAmountText, "Scheduled amount: 2.5 mg")
    }

    func testPrefilledLargeDoseOmitsGroupingSeparators() {
        let compound = Compound(
            id: UUID(),
            name: "NAD+",
            doseMg: 1000,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            notes: nil
        )

        let model = DoseLogViewModel(protocol: .fixture, compound: compound, store: store)

        XCTAssertEqual(model.doseText, "1000")
        XCTAssertTrue(model.canSubmit)
    }

    func testWeekProgressUsesProtocolDates() {
        let start = ProtocolModel.fixture.startDate
        let bounded = ProtocolModel(
            id: ProtocolModel.fixture.id,
            name: ProtocolModel.fixture.name,
            startDate: start,
            endDate: start.addingTimeInterval(12 * 7 * 86_400),
            notes: nil,
            isActive: true,
            setupStatus: "active",
            isStarter: false,
            compounds: [.fixture]
        )
        // 5 full weeks elapsed puts the user inside week 6.
        let now = start.addingTimeInterval(5 * 7 * 86_400 + 3_600)

        let boundedModel = DoseLogViewModel(protocol: bounded, compound: .fixture, store: store, now: now)
        XCTAssertEqual(boundedModel.weekProgressText, "Week 6 of 12")

        let openEnded = DoseLogViewModel(protocol: .fixture, compound: .fixture, store: store, now: now)
        XCTAssertEqual(openEnded.weekProgressText, "Week 6")
    }

    // MARK: - Validation

    func testValidationRequiresPositiveDose() {
        let model = DoseLogViewModel(protocol: .fixture, compound: .fixture, store: store)

        model.doseText = ""
        XCTAssertFalse(model.canSubmit)
        XCTAssertEqual(model.validation.dose, "Enter a positive dose.")

        model.doseText = "0"
        XCTAssertFalse(model.canSubmit)
        XCTAssertEqual(model.validation.dose, "Enter a positive dose.")

        model.doseText = "-1"
        XCTAssertFalse(model.canSubmit)

        model.doseText = "abc"
        XCTAssertFalse(model.canSubmit)

        model.doseText = "2.5"
        XCTAssertTrue(model.canSubmit)
        XCTAssertNil(model.validation.dose)
    }

    func testValidationRequiresUnitAndRoute() {
        let model = DoseLogViewModel(protocol: .fixture, compound: .fixture, store: store)

        model.unit = "  "
        XCTAssertFalse(model.canSubmit)
        XCTAssertEqual(model.validation.unit, "Unit is required.")

        model.unit = "mg"
        model.route = " "
        XCTAssertFalse(model.canSubmit)
        XCTAssertEqual(model.validation.route, "Route is required.")

        model.route = "subcutaneous"
        XCTAssertTrue(model.canSubmit)
        XCTAssertTrue(model.validation.isValid)
    }

    // MARK: - Request construction

    func testSubmissionUsesSelectedContext() async {
        let fixtureDate = Date(timeIntervalSince1970: 1_783_953_000)
        api.setMockResponse(makeLoggedDose(), for: "/dose-logs")
        let model = DoseLogViewModel(
            protocol: .fixture,
            compound: .fixture,
            store: store
        )
        model.doseText = "2.5"
        model.administeredAt = fixtureDate

        let submitted = await model.submit()

        XCTAssertTrue(submitted)
        XCTAssertEqual(api.requestLog.last?.path, "/dose-logs")
        XCTAssertEqual(api.requestLog.last?.method, .post)
    }

    func testSubmitBuildsNormalizedRequestFromDraft() async throws {
        let administeredAt = Date(timeIntervalSince1970: 1_783_953_000)
        api.setMockResponse(makeLoggedDose(), for: "/dose-logs")
        let model = DoseLogViewModel(protocol: .fixture, compound: .fixture, store: store)
        model.doseText = " 3.75 "
        model.unit = " mcg "
        model.route = " intramuscular "
        model.notes = "  Left abdomen  "
        model.administeredAt = administeredAt

        let submitted = await model.submit()
        XCTAssertTrue(submitted)

        guard case .createDoseLog(let request) = try XCTUnwrap(api.requestLog.last) else {
            return XCTFail("Expected createDoseLog request")
        }
        XCTAssertEqual(request.protocolID, ProtocolModel.fixture.id)
        XCTAssertEqual(request.compoundID, Compound.fixture.id)
        XCTAssertEqual(request.dose, 3.75)
        XCTAssertEqual(request.unit, "mcg")
        XCTAssertEqual(request.route, "intramuscular")
        XCTAssertEqual(request.notes, "Left abdomen")
        XCTAssertEqual(request.administeredAt, administeredAt)
    }

    func testSubmitSendsNilNotesWhenBlank() async throws {
        api.setMockResponse(makeLoggedDose(), for: "/dose-logs")
        let model = DoseLogViewModel(protocol: .fixture, compound: .fixture, store: store)
        model.notes = "   "

        let submitted = await model.submit()
        XCTAssertTrue(submitted)

        guard case .createDoseLog(let request) = try XCTUnwrap(api.requestLog.last) else {
            return XCTFail("Expected createDoseLog request")
        }
        XCTAssertNil(request.notes)
    }

    func testSubmitRejectsInvalidDraftWithoutRequest() async {
        let model = DoseLogViewModel(protocol: .fixture, compound: .fixture, store: store)
        model.doseText = "0"

        let submitted = await model.submit()

        XCTAssertFalse(submitted)
        XCTAssertTrue(api.requestLog.isEmpty)
    }

    // MARK: - Duplicate submission blocking

    func testSubmitBlocksDuplicateWhileInFlight() async {
        let gate = RequestGate()
        api.setMockResponse(makeLoggedDose(), for: "/dose-logs")
        api.onRequest = { _ in await gate.wait() }
        let model = DoseLogViewModel(protocol: .fixture, compound: .fixture, store: store)

        let first = Task { await model.submit() }
        await Task.yield()
        while !model.isSubmitting {
            await Task.yield()
        }

        let second = await model.submit()
        XCTAssertFalse(second)
        XCTAssertTrue(model.isSubmitting)

        await gate.open()
        let firstResult = await first.value
        XCTAssertTrue(firstResult)
        XCTAssertFalse(model.isSubmitting)
        XCTAssertEqual(api.requestLog.count, 1)
    }

    // MARK: - Success

    func testSubmitSuccessPrependsDoseToStore() async {
        let older = makeLoggedDose(administeredAt: Date(timeIntervalSince1970: 1_783_000_000))
        api.setMockResponse([older], for: "/protocols/\(ProtocolModel.fixture.id)/dose-logs")
        await store.loadDoseLogs(protocolID: ProtocolModel.fixture.id)

        let logged = makeLoggedDose()
        api.setMockResponse(logged, for: "/dose-logs")
        let model = DoseLogViewModel(protocol: .fixture, compound: .fixture, store: store)

        let submitted = await model.submit()

        XCTAssertTrue(submitted)
        XCTAssertEqual(store.doseLogs, [logged, older])
        XCTAssertNil(model.errorMessage)
    }

    // MARK: - Failure

    func testSubmitFailureRetainsDraftAndSurfacesError() async {
        api.setMockError(.serverError, for: "/dose-logs")
        let model = DoseLogViewModel(protocol: .fixture, compound: .fixture, store: store)
        model.doseText = "4"
        model.unit = "mcg"
        model.route = "intramuscular"
        model.notes = "Left abdomen"
        let administeredAt = Date(timeIntervalSince1970: 1_783_953_000)
        model.administeredAt = administeredAt

        let submitted = await model.submit()

        XCTAssertFalse(submitted)
        XCTAssertFalse(model.isSubmitting)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.doseText, "4")
        XCTAssertEqual(model.unit, "mcg")
        XCTAssertEqual(model.route, "intramuscular")
        XCTAssertEqual(model.notes, "Left abdomen")
        XCTAssertEqual(model.administeredAt, administeredAt)
    }

    // MARK: - Helpers

    private func makeLoggedDose(
        administeredAt: Date = Date(timeIntervalSince1970: 1_783_953_000)
    ) -> DoseLog {
        DoseLog(
            id: UUID(),
            protocolID: ProtocolModel.fixture.id,
            compoundID: Compound.fixture.id,
            dose: 2.5,
            unit: "mg",
            administeredAt: administeredAt,
            route: "subcutaneous",
            notes: nil
        )
    }
}

/// Suspends gated requests until opened, so tests can hold a submission in flight.
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
