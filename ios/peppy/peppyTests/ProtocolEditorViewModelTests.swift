import XCTest
@testable import peppy

@MainActor
final class ProtocolEditorViewModelTests: XCTestCase {
    func testProtocolRequiresOneValidCompound() {
        let model = ProtocolEditorViewModel(mode: .create, store: ProtocolStore(api: MockAPIClient()))
        model.name = "Retatrutide Titration"
        model.startDate = Date()

        XCTAssertFalse(model.canSubmit)
        XCTAssertEqual(model.validation.nameOrForm, "Add at least one compound.")
    }

    func testProtocolRejectsEndDateBeforeStartDate() {
        let model = ProtocolEditorViewModel(mode: .create, store: ProtocolStore(api: MockAPIClient()))
        model.name = "Retatrutide Titration"
        model.startDate = Date(timeIntervalSince1970: 200)
        model.endDate = Date(timeIntervalSince1970: 100)
        model.compounds = [.validFixture]

        XCTAssertFalse(model.canSubmit)
        XCTAssertEqual(model.validation.dateRange, "End date must be after start date.")
    }

    func testProtocolBuildsCreateRequestWithTrimmedValues() throws {
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        let model = ProtocolEditorViewModel(mode: .create, store: ProtocolStore(api: MockAPIClient()))
        model.name = " Retatrutide Titration "
        model.startDate = start
        model.notes = " Starter plan "
        model.compounds = [.validFixture]

        let request = try XCTUnwrap(model.createRequest())

        XCTAssertEqual(request.name, "Retatrutide Titration")
        XCTAssertEqual(request.startDate, start)
        XCTAssertNil(request.endDate)
        XCTAssertEqual(request.notes, "Starter plan")
        XCTAssertEqual(request.compounds.count, 1)
        XCTAssertEqual(request.compounds.first?.name, "Retatrutide")
        XCTAssertEqual(request.compounds.first?.doseMg, 2.5)
        XCTAssertEqual(request.compounds.first?.doseUnit, "mg")
        XCTAssertEqual(request.compounds.first?.frequency, "weekly")
        XCTAssertEqual(request.compounds.first?.administrationRoute, "subcutaneous")
        XCTAssertNil(request.compounds.first?.notes)
    }

    func testProtocolEditBuildsRequestThatClearsOptionalFields() throws {
        let protocolValue = makeProtocol(
            endDate: Date(timeIntervalSince1970: 1_790_000_000),
            notes: "Existing notes",
            compounds: [.fixture]
        )
        let model = ProtocolEditorViewModel(
            mode: .edit(protocolValue),
            store: ProtocolStore(api: MockAPIClient())
        )
        model.endDate = nil
        model.notes = " "

        let request = try XCTUnwrap(model.updateRequest())
        let object = try encodedObject(request)

        XCTAssertTrue(object["end_date"] is NSNull)
        XCTAssertTrue(object["notes"] is NSNull)
    }

    func testProtocolEditBuildsCompoundRequestThatClearsNotes() throws {
        let compound = Compound(
            id: UUID(),
            name: "Retatrutide",
            doseMg: 2.5,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            notes: "Existing notes"
        )
        let protocolValue = makeProtocol(compounds: [compound])
        let model = ProtocolEditorViewModel(
            mode: .edit(protocolValue),
            store: ProtocolStore(api: MockAPIClient())
        )
        model.compounds[0].notes = " "

        let request = try XCTUnwrap(model.compounds[0].updateRequest)
        let object = try encodedObject(request)

        XCTAssertTrue(object["notes"] is NSNull)
    }

    func testProtocolEditPrepopulatesFieldsAndCompounds() {
        let protocolValue = ProtocolModel.fixture
        let model = ProtocolEditorViewModel(
            mode: .edit(protocolValue),
            store: ProtocolStore(api: MockAPIClient())
        )

        XCTAssertEqual(model.name, protocolValue.name)
        XCTAssertEqual(model.startDate, protocolValue.startDate)
        XCTAssertEqual(model.endDate, protocolValue.endDate)
        XCTAssertEqual(model.notes, "")
        XCTAssertEqual(model.compounds.count, 1)
        XCTAssertEqual(model.compounds.first?.persistedID, Compound.fixture.id)
        XCTAssertEqual(model.compounds.first?.name, Compound.fixture.name)
        XCTAssertTrue(model.canSubmit)
    }

    func testProtocolEditSubmitsMetadataBeforeCompoundOperations() async {
        let api = MockAPIClient()
        let store = ProtocolStore(api: api)
        let original = makeProtocol(compounds: [.fixture, .secondFixture])
        let renamed = makeProtocol(id: original.id, name: "Renamed", compounds: original.compounds)
        let updatedCompound = Compound(
            id: Compound.fixture.id,
            name: "Retatrutide",
            doseMg: 5,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            notes: nil
        )
        let addedCompound = Compound(
            id: UUID(),
            name: "BPC-157",
            doseMg: 0.25,
            doseUnit: "mg",
            frequency: "daily",
            administrationRoute: "subcutaneous",
            notes: nil
        )
        let metadataRequest = UpdateProtocolRequest(
            name: "Renamed",
            startDate: original.startDate,
            endDate: nil,
            notes: nil
        )
        let compoundUpdate = UpdateCompoundRequest(
            name: "Retatrutide",
            doseMg: 5,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            notes: nil
        )
        api.setMockResponse([original], for: Endpoint.getProtocols)
        api.setMockResponse(renamed, for: Endpoint.updateProtocol(id: original.id, metadataRequest))
        api.setMockResponse(updatedCompound, for: Endpoint.updateCompound(id: Compound.fixture.id, compoundUpdate))
        api.setMockResponse(addedCompound, for: Endpoint.addCompound(protocolID: original.id, .addedCreateFixture))
        await store.loadProtocols()

        let model = ProtocolEditorViewModel(mode: .edit(original), store: store)
        model.name = " Renamed "
        model.compounds[0].doseText = "5"
        model.compounds.removeAll { $0.persistedID == Compound.secondFixture.id }
        model.compounds.append(.addedFixture)

        let didSubmit = await model.submit()

        XCTAssertTrue(didSubmit)
        XCTAssertEqual(api.requestLog.map(\.method), [.get, .patch, .patch, .post, .delete])
        guard case .updateProtocol = api.requestLog[1],
              case .updateCompound = api.requestLog[2],
              case .addCompound = api.requestLog[3],
              case .removeCompound = api.requestLog[4] else {
            return XCTFail("Expected metadata update, compound update, add, then remove")
        }
    }

    func testProtocolSubmitRejectsDuplicateWhileSaving() async {
        let api = MockAPIClient()
        let store = ProtocolStore(api: api)
        api.setMockResponse(ProtocolModel.fixture, for: Endpoint.createProtocol(.createFixture))
        let model = ProtocolEditorViewModel(mode: .create, store: store)
        model.name = ProtocolModel.fixture.name
        model.startDate = ProtocolModel.fixture.startDate
        model.compounds = [.validFixture]

        let gate = RequestGate()
        let started = expectation(description: "submit started")
        api.onRequest = { endpoint in
            if endpoint.method == .post {
                started.fulfill()
                await gate.wait()
            }
        }

        let firstSubmit = Task { await model.submit() }
        await fulfillment(of: [started], timeout: 2)

        XCTAssertTrue(model.isSubmitting)
        let duplicate = await model.submit()
        XCTAssertFalse(duplicate)
        XCTAssertEqual(api.requestLog.filter { $0.method == .post }.count, 1)

        await gate.open()
        let firstResult = await firstSubmit.value
        XCTAssertTrue(firstResult)
        XCTAssertFalse(model.isSubmitting)
    }

    func testProtocolSubmitRetainsDraftAfterError() async {
        let api = MockAPIClient()
        let store = ProtocolStore(api: api)
        api.setMockError(.serverError, for: Endpoint.createProtocol(.createFixture))
        let model = ProtocolEditorViewModel(mode: .create, store: store)
        model.name = " Retatrutide Titration "
        model.startDate = ProtocolModel.fixture.startDate
        model.compounds = [.validFixture]

        let didSubmit = await model.submit()

        XCTAssertFalse(didSubmit)
        XCTAssertEqual(model.name, " Retatrutide Titration ")
        XCTAssertEqual(model.compounds, [.validFixture])
        XCTAssertNotNil(model.errorMessage)
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

private func encodedObject<T: Encodable>(_ value: T) throws -> [String: Any] {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return try XCTUnwrap(object)
}

private extension CompoundDraft {
    static let validFixture = CompoundDraft(
        name: " Retatrutide ",
        doseText: " 2.5 ",
        unit: " mg ",
        frequency: " weekly ",
        route: " subcutaneous ",
        notes: ""
    )

    static let addedFixture = CompoundDraft(
        name: "BPC-157",
        doseText: "0.25",
        unit: "mg",
        frequency: "daily",
        route: "subcutaneous",
        notes: ""
    )
}

private extension CreateProtocolRequest {
    static let createFixture = CreateProtocolRequest(
        name: ProtocolModel.fixture.name,
        startDate: ProtocolModel.fixture.startDate,
        endDate: nil,
        notes: nil,
        compounds: [
            CreateCompoundRequest(
                name: "Retatrutide",
                doseMg: 2.5,
                doseUnit: "mg",
                frequency: "weekly",
                administrationRoute: "subcutaneous",
                notes: nil
            )
        ]
    )
}

private extension CreateCompoundRequest {
    static let addedCreateFixture = CreateCompoundRequest(
        name: "BPC-157",
        doseMg: 0.25,
        doseUnit: "mg",
        frequency: "daily",
        administrationRoute: "subcutaneous",
        notes: nil
    )
}

private extension Compound {
    static let secondFixture = Compound(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        name: "BPC-157",
        doseMg: 0.25,
        doseUnit: "mg",
        frequency: "daily",
        administrationRoute: "subcutaneous",
        notes: nil
    )
}

private func makeProtocol(
    id: UUID = UUID(),
    name: String = "Retatrutide Titration",
    startDate: Date = Date(timeIntervalSince1970: 1_780_000_000),
    endDate: Date? = nil,
    notes: String? = nil,
    compounds: [Compound]
) -> ProtocolModel {
    ProtocolModel(
        id: id,
        name: name,
        startDate: startDate,
        endDate: endDate,
        notes: notes,
        isActive: true,
        setupStatus: "active",
        isStarter: false,
        compounds: compounds
    )
}
