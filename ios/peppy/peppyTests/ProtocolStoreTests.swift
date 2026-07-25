import Foundation
import XCTest
@testable import peppy

@MainActor
final class ProtocolStoreTests: XCTestCase {

    // MARK: - Endpoint contracts

    func testAddCompoundEndpoint() {
        let id = UUID()
        let endpoint = Endpoint.addCompound(protocolID: id, .fixture)

        XCTAssertEqual(endpoint.path, "/protocols/\(id)/compounds")
        XCTAssertEqual(endpoint.method, .post)
    }

    func testUpdateCompoundEndpoint() {
        let id = UUID()
        let endpoint = Endpoint.updateCompound(id: id, UpdateCompoundRequest(doseMg: 5))

        XCTAssertEqual(endpoint.path, "/protocols/compounds/\(id)")
        XCTAssertEqual(endpoint.method, .patch)
    }

    func testRemoveCompoundEndpoint() {
        let id = UUID()
        let endpoint = Endpoint.removeCompound(id: id)

        XCTAssertEqual(endpoint.path, "/protocols/compounds/\(id)")
        XCTAssertEqual(endpoint.method, .delete)
    }

    func testGetDoseLogsEndpoint() {
        let id = UUID()
        let endpoint = Endpoint.getDoseLogs(protocolID: id)

        XCTAssertEqual(endpoint.path, "/protocols/\(id)/dose-logs")
        XCTAssertEqual(endpoint.method, .get)
    }

    func testCreateDoseLogEndpoint() {
        let endpoint = Endpoint.createDoseLog(.fixture)

        XCTAssertEqual(endpoint.path, "/dose-logs")
        XCTAssertEqual(endpoint.method, .post)
    }

    // MARK: - Request encoding

    func testCreateCompoundRequestEncodesBackendKeys() throws {
        let request = CreateCompoundRequest(
            name: "Retatrutide",
            doseMg: 2.5,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            notes: "Titrate up monthly"
        )

        let object = try encodedObject(request)

        XCTAssertEqual(object["name"] as? String, "Retatrutide")
        XCTAssertEqual(object["dose_mg"] as? Double, 2.5)
        XCTAssertEqual(object["dose_unit"] as? String, "mg")
        XCTAssertEqual(object["frequency"] as? String, "weekly")
        XCTAssertEqual(object["administration_route"] as? String, "subcutaneous")
        XCTAssertEqual(object["notes"] as? String, "Titrate up monthly")
    }

    func testUpdateCompoundRequestOmitsMissingFields() throws {
        let object = try encodedObject(UpdateCompoundRequest(doseMg: 5.0))

        XCTAssertEqual(object["dose_mg"] as? Double, 5.0)
        XCTAssertEqual(Set(object.keys), ["dose_mg"])
    }

    func testUpdateCompoundRequestCanExplicitlyClearNotes() throws {
        let object = try encodedObject(UpdateCompoundRequest(notes: nil, clearNotes: true))

        XCTAssertTrue(object["notes"] is NSNull)
        XCTAssertEqual(Set(object.keys), ["notes"])
    }

    func testCreateDoseLogRequestEncodesIdentifiersAndTimestamp() throws {
        let request = CreateDoseLogRequest(
            protocolID: ProtocolModel.fixture.id,
            compoundID: Compound.fixture.id,
            dose: 2.5,
            unit: "mg",
            administeredAt: isoDate("2026-07-08T14:30:00Z"),
            route: "subcutaneous",
            notes: "Left abdomen"
        )

        let object = try encodedObject(request)

        XCTAssertEqual(object["protocol_id"] as? String, ProtocolModel.fixture.id.uuidString)
        XCTAssertEqual(object["compound_id"] as? String, Compound.fixture.id.uuidString)
        XCTAssertEqual(object["dose"] as? Double, 2.5)
        XCTAssertEqual(object["unit"] as? String, "mg")
        XCTAssertEqual(object["administered_at"] as? String, "2026-07-08T14:30:00Z")
        XCTAssertEqual(object["route"] as? String, "subcutaneous")
        XCTAssertEqual(object["notes"] as? String, "Left abdomen")
    }

    func testCreateProtocolRequestEncodesDateOnlyDates() throws {
        let request = CreateProtocolRequest(
            name: "Retatrutide Titration",
            startDate: isoDate("2026-07-08T14:30:00Z"),
            endDate: isoDate("2026-10-08T09:00:00Z"),
            notes: nil,
            compounds: [.fixture]
        )

        let object = try encodedObject(request)

        XCTAssertEqual(object["name"] as? String, "Retatrutide Titration")
        XCTAssertEqual(object["start_date"] as? String, "2026-07-08")
        XCTAssertEqual(object["end_date"] as? String, "2026-10-08")
        XCTAssertNil(object["notes"])
        let compounds = object["compounds"] as? [[String: Any]]
        XCTAssertEqual(compounds?.count, 1)
        XCTAssertEqual(compounds?.first?["dose_mg"] as? Double, 2.5)
    }

    func testUpdateProtocolRequestEncodesDateOnlyDatesAndOmitsNil() throws {
        let request = UpdateProtocolRequest(
            name: nil,
            startDate: isoDate("2026-07-09T20:00:00Z"),
            endDate: nil,
            notes: nil
        )

        let object = try encodedObject(request)

        XCTAssertEqual(object["start_date"] as? String, "2026-07-09")
        XCTAssertEqual(Set(object.keys), ["start_date"])
    }

    func testUpdateProtocolRequestCanExplicitlyClearOptionalFields() throws {
        let request = UpdateProtocolRequest(
            name: nil,
            startDate: nil,
            endDate: nil,
            notes: nil,
            clearEndDate: true,
            clearNotes: true
        )

        let object = try encodedObject(request)

        XCTAssertTrue(object["end_date"] is NSNull)
        XCTAssertTrue(object["notes"] is NSNull)
        XCTAssertEqual(Set(object.keys), ["end_date", "notes"])
    }

    // MARK: - Response decoding

    func testCompoundDecodesBackendPayload() throws {
        let json = """
        {
            "id": "5D2B0A1E-4C1F-4E8A-9B2D-1A2B3C4D5E6F",
            "name": "Retatrutide",
            "dose_mg": 2.5,
            "dose_unit": "mg",
            "frequency": "weekly",
            "administration_route": "subcutaneous",
            "notes": "Rotate injection sites",
            "created_at": "2026-07-08T18:44:10.123456+00:00",
            "updated_at": "2026-07-08T18:44:10.123456+00:00"
        }
        """

        let compound = try decode(Compound.self, from: json)

        XCTAssertEqual(compound.id.uuidString, "5D2B0A1E-4C1F-4E8A-9B2D-1A2B3C4D5E6F")
        XCTAssertEqual(compound.name, "Retatrutide")
        XCTAssertEqual(compound.doseMg, 2.5)
        XCTAssertEqual(compound.doseUnit, "mg")
        XCTAssertEqual(compound.frequency, "weekly")
        XCTAssertEqual(compound.administrationRoute, "subcutaneous")
        XCTAssertEqual(compound.notes, "Rotate injection sites")
    }

    func testProtocolDecodesDateOnlyBackendPayload() throws {
        let json = """
        {
            "id": "5D2B0A1E-4C1F-4E8A-9B2D-1A2B3C4D5E60",
            "name": "Retatrutide Titration",
            "start_date": "2026-07-01",
            "end_date": null,
            "is_active": true,
            "setup_status": "active",
            "is_starter": false,
            "notes": null,
            "compounds": [
                {
                    "id": "5D2B0A1E-4C1F-4E8A-9B2D-1A2B3C4D5E6F",
                    "name": "Retatrutide",
                    "dose_mg": 2.5,
                    "dose_unit": "mg",
                    "frequency": "weekly",
                    "administration_route": "subcutaneous",
                    "notes": null,
                    "created_at": "2026-07-08T18:44:10.123456+00:00",
                    "updated_at": "2026-07-08T18:44:10.123456+00:00"
                }
            ],
            "created_at": "2026-07-08T18:44:10.123456+00:00",
            "updated_at": "2026-07-08T18:44:10.123456+00:00"
        }
        """

        let protocolValue = try decode(ProtocolModel.self, from: json)

        XCTAssertEqual(protocolValue.name, "Retatrutide Titration")
        XCTAssertEqual(protocolValue.startDate, isoDate("2026-07-01T00:00:00Z"))
        XCTAssertNil(protocolValue.endDate)
        XCTAssertTrue(protocolValue.isActive)
        XCTAssertEqual(protocolValue.setupStatus, "active")
        XCTAssertEqual(protocolValue.isStarter, false)
        XCTAssertEqual(protocolValue.compounds.count, 1)
        XCTAssertEqual(protocolValue.compounds.first?.doseMg, 2.5)
        XCTAssertEqual(protocolValue.compounds.first?.administrationRoute, "subcutaneous")
    }

    func testDoseLogDecodesBackendPayload() throws {
        let json = """
        {
            "id": "5D2B0A1E-4C1F-4E8A-9B2D-1A2B3C4D5E61",
            "protocol_id": "5D2B0A1E-4C1F-4E8A-9B2D-1A2B3C4D5E60",
            "compound_id": "5D2B0A1E-4C1F-4E8A-9B2D-1A2B3C4D5E6F",
            "dose": 2.5,
            "unit": "mg",
            "administered_at": "2026-07-08T14:30:00+00:00",
            "route": "subcutaneous",
            "notes": null,
            "created_at": "2026-07-08T18:44:10.123456+00:00",
            "updated_at": "2026-07-08T18:44:10.123456+00:00"
        }
        """

        let log = try decode(DoseLog.self, from: json)

        XCTAssertEqual(log.id.uuidString, "5D2B0A1E-4C1F-4E8A-9B2D-1A2B3C4D5E61")
        XCTAssertEqual(log.protocolID.uuidString, "5D2B0A1E-4C1F-4E8A-9B2D-1A2B3C4D5E60")
        XCTAssertEqual(log.compoundID.uuidString, "5D2B0A1E-4C1F-4E8A-9B2D-1A2B3C4D5E6F")
        XCTAssertEqual(log.dose, 2.5)
        XCTAssertEqual(log.unit, "mg")
        XCTAssertEqual(log.administeredAt, isoDate("2026-07-08T14:30:00Z"))
        XCTAssertEqual(log.route, "subcutaneous")
        XCTAssertNil(log.notes)
    }

    func testDoseLogDecodesFractionalSecondTimestamps() throws {
        let json = """
        {
            "id": "5D2B0A1E-4C1F-4E8A-9B2D-1A2B3C4D5E61",
            "protocol_id": "5D2B0A1E-4C1F-4E8A-9B2D-1A2B3C4D5E60",
            "compound_id": "5D2B0A1E-4C1F-4E8A-9B2D-1A2B3C4D5E6F",
            "dose": 2.5,
            "unit": "mg",
            "administered_at": "2026-07-08T14:30:00.123456+00:00",
            "route": "subcutaneous",
            "notes": "Left abdomen"
        }
        """

        let log = try decode(DoseLog.self, from: json)

        XCTAssertEqual(
            log.administeredAt.timeIntervalSince1970,
            isoDate("2026-07-08T14:30:00Z").timeIntervalSince1970 + 0.123456,
            accuracy: 0.01
        )
        XCTAssertEqual(log.notes, "Left abdomen")
    }

    // MARK: - Protocol status

    func testProtocolStatusDerivation() {
        XCTAssertEqual(makeProtocol(setupStatus: "pending_setup", isActive: false).status, .pendingSetup)
        XCTAssertEqual(makeProtocol(setupStatus: "active", isActive: true).status, .active)
        XCTAssertEqual(makeProtocol(setupStatus: "inactive", isActive: false).status, .inactive)
        XCTAssertEqual(makeProtocol(setupStatus: nil, isActive: true).status, .active)
        XCTAssertEqual(makeProtocol(setupStatus: nil, isActive: false).status, .inactive)
    }

    // MARK: - Mock client request identity

    func testMockClientResolvesResponsesByMethodAndPath() async throws {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        api.setMockResponse(ProtocolModel.fixture, for: Endpoint.createProtocol(.fixture))

        let listed: [ProtocolModel] = try await api.execute(.getProtocols)
        let created: ProtocolModel = try await api.execute(.createProtocol(.fixture))

        XCTAssertEqual(listed, [ProtocolModel.fixture])
        XCTAssertEqual(created, ProtocolModel.fixture)
        XCTAssertEqual(api.requestLog.map(\.requestID), ["GET /protocols", "POST /protocols"])
    }

    func testMockClientFallsBackToPathKeyedResponses() async throws {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: "/protocols")

        let listed: [ProtocolModel] = try await api.execute(.getProtocols)

        XCTAssertEqual(listed, [ProtocolModel.fixture])
    }

    // MARK: - Helpers

    private func encodedObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try XCTUnwrap(object)
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(json.utf8))
    }

    private func isoDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
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
        protocolID: UUID,
        compoundID: UUID = Compound.fixture.id,
        administeredAt: Date = Date(timeIntervalSince1970: 1_783_953_000)
    ) -> DoseLog {
        DoseLog(
            id: UUID(),
            protocolID: protocolID,
            compoundID: compoundID,
            dose: 2.5,
            unit: "mg",
            administeredAt: administeredAt,
            route: "subcutaneous",
            notes: nil
        )
    }

    // MARK: - Store: list loading

    func testLoadProtocolsPopulatesList() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let store = ProtocolStore(api: api)

        await store.loadProtocols()

        XCTAssertEqual(store.protocols, [ProtocolModel.fixture])
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.errorMessage)
    }

    func testLoadProtocolsSkipsNetworkWhenAlreadyLoadedUnlessForced() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let store = ProtocolStore(api: api)

        await store.loadProtocols()
        await store.loadProtocols()
        XCTAssertEqual(api.requestLog.count, 1)

        await store.loadProtocols(force: true)
        XCTAssertEqual(api.requestLog.count, 2)
    }

    func testInitialLoadFailureSetsError() async {
        let api = MockAPIClient()
        api.setMockError(.serverError, for: Endpoint.getProtocols)
        let store = ProtocolStore(api: api)

        await store.loadProtocols()

        XCTAssertTrue(store.protocols.isEmpty)
        XCTAssertNotNil(store.errorMessage)
    }

    func testRefreshFailureKeepsLoadedContent() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        api.setMockError(.serverError, for: Endpoint.getProtocols)
        await store.loadProtocols(force: true)

        XCTAssertEqual(store.protocols, [ProtocolModel.fixture])
        XCTAssertNotNil(store.errorMessage)
    }

    // MARK: - Store: selection

    func testSelectLoadsDetailAndReconcilesList() async {
        let api = MockAPIClient()
        let stale = makeProtocol(id: ProtocolModel.fixture.id, name: "Old Name")
        api.setMockResponse([stale], for: Endpoint.getProtocols)
        api.setMockResponse(ProtocolModel.fixture, for: Endpoint.getProtocol(id: ProtocolModel.fixture.id))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        await store.select(ProtocolModel.fixture.id)

        XCTAssertEqual(store.selectedProtocol, ProtocolModel.fixture)
        XCTAssertEqual(store.protocols, [ProtocolModel.fixture])
    }

    func testSelectKeepsLocalCopyWhenDetailRefreshFails() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        await store.select(ProtocolModel.fixture.id)

        XCTAssertEqual(store.selectedProtocol, ProtocolModel.fixture)
    }

    func testStaleDetailResponseDoesNotOverwriteNewerSelection() async {
        let api = MockAPIClient()
        let a = makeProtocol(name: "A")
        let b = makeProtocol(name: "B")
        api.setMockResponse([a, b], for: Endpoint.getProtocols)
        api.setMockResponse(a, for: Endpoint.getProtocol(id: a.id))
        api.setMockResponse(b, for: Endpoint.getProtocol(id: b.id))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        let gate = RequestGate()
        let started = expectation(description: "stale request in flight")
        let stalePath = "/protocols/\(a.id)"
        api.onRequest = { endpoint in
            if endpoint.path == stalePath {
                started.fulfill()
                await gate.wait()
            }
        }

        let firstSelection = Task { await store.select(a.id) }
        await fulfillment(of: [started], timeout: 2)

        await store.select(b.id)
        XCTAssertEqual(store.selectedProtocol?.id, b.id)

        await gate.open()
        await firstSelection.value

        XCTAssertEqual(store.selectedProtocol?.id, b.id)
    }

    // MARK: - Store: mutations

    func testCreateAppendsProtocolAndDeactivatesPrevious() async {
        let api = MockAPIClient()
        let existing = makeProtocol(name: "Existing", isActive: true)
        api.setMockResponse([existing], for: Endpoint.getProtocols)
        let created = makeProtocol(name: "New", isActive: true)
        api.setMockResponse(created, for: Endpoint.createProtocol(.fixture))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        let result = await store.create(.fixture)

        XCTAssertEqual(result, created)
        XCTAssertEqual(store.protocols.first, created)
        let previous = store.protocols.first { $0.id == existing.id }
        XCTAssertEqual(previous?.isActive, false)
        XCTAssertEqual(previous?.setupStatus, "inactive")
        XCTAssertEqual(store.revision, 1)
    }

    func testResetSessionInvalidatesDelayedCreateResponse() async {
        let api = MockAPIClient()
        let created = makeProtocol(name: "Previous user protocol")
        api.setMockResponse(created, for: Endpoint.createProtocol(.fixture))
        let gate = RequestGate()
        let started = expectation(description: "create request in flight")
        api.onRequest = { endpoint in
            guard case .createProtocol = endpoint else { return }
            started.fulfill()
            await gate.wait()
        }
        let store = ProtocolStore(api: api)

        let create = Task {
            await store.create(.fixture)
        }
        await fulfillment(of: [started], timeout: 2)
        store.resetSession()
        await gate.open()
        let result = await create.value

        XCTAssertNil(result)
        XCTAssertTrue(store.protocols.isEmpty)
        XCTAssertNil(store.selectedProtocol)
        XCTAssertEqual(store.revision, 0)
    }

    func testUpdateReplacesProtocolMetadata() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let request = UpdateProtocolRequest(name: "Renamed", startDate: nil, endDate: nil, notes: nil)
        let updated = makeProtocol(id: ProtocolModel.fixture.id, name: "Renamed")
        api.setMockResponse(updated, for: Endpoint.updateProtocol(id: ProtocolModel.fixture.id, request))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()
        await store.select(ProtocolModel.fixture.id)

        let result = await store.update(id: ProtocolModel.fixture.id, request: request)

        XCTAssertEqual(result, updated)
        XCTAssertEqual(store.protocols, [updated])
        XCTAssertEqual(store.selectedProtocol, updated)
        XCTAssertEqual(store.revision, 1)
    }

    func testAddCompoundAppendsToProtocol() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let added = Compound(
            id: UUID(),
            name: "BPC-157",
            doseMg: 0.25,
            doseUnit: "mg",
            frequency: "daily",
            administrationRoute: "subcutaneous",
            notes: nil
        )
        api.setMockResponse(added, for: Endpoint.addCompound(protocolID: ProtocolModel.fixture.id, .fixture))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        let result = await store.addCompound(protocolID: ProtocolModel.fixture.id, request: .fixture)

        XCTAssertEqual(result, added)
        XCTAssertEqual(store.protocols.first?.compounds, [Compound.fixture, added])
        XCTAssertEqual(store.revision, 1)
    }

    func testUpdateCompoundReplacesCompoundInOwningProtocol() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let request = UpdateCompoundRequest(doseMg: 5.0)
        let updated = Compound(
            id: Compound.fixture.id,
            name: Compound.fixture.name,
            doseMg: 5.0,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            notes: nil
        )
        api.setMockResponse(updated, for: Endpoint.updateCompound(id: Compound.fixture.id, request))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        let result = await store.updateCompound(id: Compound.fixture.id, request: request)

        XCTAssertEqual(result, updated)
        XCTAssertEqual(store.protocols.first?.compounds, [updated])
        XCTAssertEqual(store.revision, 1)
    }

    func testRemoveCompoundRemovesFromProtocol() async {
        let api = MockAPIClient()
        let second = Compound(
            id: UUID(),
            name: "BPC-157",
            doseMg: 0.25,
            doseUnit: "mg",
            frequency: "daily",
            administrationRoute: "subcutaneous",
            notes: nil
        )
        let protocolValue = makeProtocol(compounds: [.fixture, second])
        api.setMockResponse([protocolValue], for: Endpoint.getProtocols)
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        let removed = await store.removeCompound(id: second.id, protocolID: protocolValue.id)

        XCTAssertTrue(removed)
        XCTAssertEqual(store.protocols.first?.compounds, [Compound.fixture])
        XCTAssertEqual(store.revision, 1)
    }

    func testActivateAppliesServerStateAndDeactivatesOthers() async {
        let api = MockAPIClient()
        let inactive = makeProtocol(name: "A", setupStatus: "inactive", isActive: false)
        let active = makeProtocol(name: "B", setupStatus: "active", isActive: true)
        api.setMockResponse([inactive, active], for: Endpoint.getProtocols)
        let activated = makeProtocol(id: inactive.id, name: "A", setupStatus: "active", isActive: true)
        api.setMockResponse(activated, for: Endpoint.activateProtocol(id: inactive.id))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        let didActivate = await store.activate(id: inactive.id)

        XCTAssertTrue(didActivate)
        XCTAssertEqual(store.protocols.first { $0.id == inactive.id }, activated)
        XCTAssertEqual(store.protocols.first { $0.id == active.id }?.isActive, false)
        XCTAssertEqual(store.revision, 1)
    }

    func testDeactivateAppliesServerState() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let deactivated = makeProtocol(
            id: ProtocolModel.fixture.id,
            setupStatus: "inactive",
            isActive: false
        )
        api.setMockResponse(deactivated, for: Endpoint.deactivateProtocol(id: ProtocolModel.fixture.id))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        let didDeactivate = await store.deactivate(id: ProtocolModel.fixture.id)

        XCTAssertTrue(didDeactivate)
        XCTAssertEqual(store.protocols, [deactivated])
        XCTAssertEqual(store.revision, 1)
    }

    func testDeleteRemovesProtocolAndClearsSelection() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: "/protocols")
        let store = ProtocolStore(api: api)
        await store.loadProtocols()
        await store.select(ProtocolModel.fixture.id)

        let deleted = await store.deleteSelected()

        XCTAssertTrue(deleted)
        XCTAssertTrue(store.protocols.isEmpty)
        XCTAssertNil(store.selectedProtocol)
        XCTAssertEqual(store.revision, 1)
    }

    func testDeleteFailureKeepsStateAndSetsError() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        api.setMockError(.serverError, for: Endpoint.deleteProtocol(id: ProtocolModel.fixture.id))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()
        await store.select(ProtocolModel.fixture.id)

        let deleted = await store.deleteSelected()

        XCTAssertFalse(deleted)
        XCTAssertEqual(store.protocols, [ProtocolModel.fixture])
        XCTAssertEqual(store.selectedProtocol, ProtocolModel.fixture)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.revision, 0)
    }

    func testOverlappingMutationForSameProtocolIsRejected() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let request = UpdateProtocolRequest(name: "Renamed", startDate: nil, endDate: nil, notes: nil)
        let updated = makeProtocol(id: ProtocolModel.fixture.id, name: "Renamed")
        api.setMockResponse(updated, for: Endpoint.updateProtocol(id: ProtocolModel.fixture.id, request))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        let gate = RequestGate()
        let started = expectation(description: "first mutation in flight")
        api.onRequest = { endpoint in
            if endpoint.method == .patch {
                started.fulfill()
                await gate.wait()
            }
        }

        let firstMutation = Task { await store.update(id: ProtocolModel.fixture.id, request: request) }
        await fulfillment(of: [started], timeout: 2)

        XCTAssertEqual(store.mutatingProtocolID, ProtocolModel.fixture.id)
        let second = await store.update(id: ProtocolModel.fixture.id, request: request)
        XCTAssertNil(second)

        await gate.open()
        let first = await firstMutation.value

        XCTAssertEqual(first, updated)
        XCTAssertNil(store.mutatingProtocolID)
        XCTAssertEqual(api.requestLog.filter { $0.method == .patch }.count, 1)
        XCTAssertEqual(store.revision, 1)
    }

    // MARK: - Store: starter activation

    func testActivateStarterActivatesProtocolAndDeactivatesOthers() async {
        let api = MockAPIClient()
        let other = makeProtocol(name: "Other", setupStatus: "active", isActive: true)
        let pending = makeProtocol(name: "Starter protocol", setupStatus: "pending_setup", isActive: false)
        api.setMockResponse([other, pending], for: Endpoint.getProtocols)
        let request = StarterProtocolActivationRequest(
            doseMg: 2,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            startDate: Date(timeIntervalSince1970: 1_780_000_000)
        )
        let activated = makeProtocol(id: pending.id, name: "Starter protocol", setupStatus: "active", isActive: true)
        api.setMockResponse(activated, for: Endpoint.getProtocol(id: pending.id))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        let result = await store.activateStarter(id: pending.id, request: request)

        XCTAssertTrue(result)
        XCTAssertEqual(store.protocols.first { $0.id == pending.id }, activated)
        XCTAssertEqual(store.protocols.first { $0.id == other.id }?.isActive, false)
        XCTAssertEqual(store.selectedProtocol, nil)
        XCTAssertEqual(store.revision, 1)
        XCTAssertNil(store.errorMessage)
        guard let activationRequest = api.requestLog.first(where: {
            if case .activateStarterProtocol = $0 { return true }
            return false
        }), case .activateStarterProtocol(let id, _) = activationRequest else {
            return XCTFail("Expected activate starter protocol endpoint")
        }
        XCTAssertEqual(id, pending.id)
    }

    func testActivateStarterReportsSuccessWhenPostSucceedsButRefetchFails() async {
        let api = MockAPIClient()
        let other = makeProtocol(name: "Other", setupStatus: "active", isActive: true)
        let pending = makeProtocol(name: "Starter protocol", setupStatus: "pending_setup", isActive: false)
        api.setMockResponse([other, pending], for: Endpoint.getProtocols)
        let request = StarterProtocolActivationRequest(
            doseMg: 2,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            startDate: Date(timeIntervalSince1970: 1_780_000_000)
        )
        // No mock error registered for .activateStarterProtocol, so the POST succeeds.
        // The follow-up GET is made to fail, simulating a transient refetch error.
        api.setMockError(.serverError, for: Endpoint.getProtocol(id: pending.id))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        let result = await store.activateStarter(id: pending.id, request: request)

        XCTAssertTrue(result, "POST succeeded server-side; activation must be reported as success")
        XCTAssertEqual(store.protocols.first { $0.id == pending.id }?.isActive, true)
        XCTAssertEqual(store.protocols.first { $0.id == pending.id }?.setupStatus, "active")
        XCTAssertEqual(store.protocols.first { $0.id == other.id }?.isActive, false)
        XCTAssertEqual(store.revision, 1)
        XCTAssertNil(store.errorMessage)
    }

    func testActivateStarterFailureSetsErrorAndDoesNotBumpRevision() async {
        let api = MockAPIClient()
        let pending = makeProtocol(setupStatus: "pending_setup", isActive: false)
        api.setMockResponse([pending], for: Endpoint.getProtocols)
        let request = StarterProtocolActivationRequest(
            doseMg: 2,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            startDate: Date(timeIntervalSince1970: 1_780_000_000)
        )
        api.setMockError(.serverError, for: Endpoint.activateStarterProtocol(id: pending.id, request))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        let result = await store.activateStarter(id: pending.id, request: request)

        XCTAssertFalse(result)
        XCTAssertEqual(store.protocols, [pending])
        XCTAssertEqual(store.revision, 0)
        XCTAssertEqual(store.errorMessage, APIError.serverError.userMessage)
    }

    func testActivateStarterReportsSuccessOnUnloadedStoreWhenRefetchFails() async {
        let api = MockAPIClient()
        let id = UUID()
        let request = StarterProtocolActivationRequest(
            doseMg: 2,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            startDate: Date(timeIntervalSince1970: 1_780_000_000)
        )
        // Store never loaded: no protocols, no selection (the Dashboard entry path).
        // POST succeeds; the confirming refetch fails.
        api.setMockError(.serverError, for: Endpoint.getProtocol(id: id))
        let store = ProtocolStore(api: api)

        let result = await store.activateStarter(id: id, request: request)

        XCTAssertTrue(result, "Success must not depend on finding a local model")
        XCTAssertEqual(store.revision, 1)
        XCTAssertNil(store.errorMessage)
    }

    func testActivateStarterRejectsOverlappingMutationForSameProtocol() async {
        let api = MockAPIClient()
        let pending = makeProtocol(setupStatus: "pending_setup", isActive: false)
        api.setMockResponse([pending], for: Endpoint.getProtocols)
        let request = StarterProtocolActivationRequest(
            doseMg: 2,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            startDate: Date(timeIntervalSince1970: 1_780_000_000)
        )
        let activated = makeProtocol(id: pending.id, setupStatus: "active", isActive: true)
        api.setMockResponse(activated, for: Endpoint.getProtocol(id: pending.id))
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        let gate = RequestGate()
        let started = expectation(description: "starter activation in flight")
        api.onRequest = { endpoint in
            if case .activateStarterProtocol = endpoint {
                started.fulfill()
                await gate.wait()
            }
        }

        let firstActivation = Task { await store.activateStarter(id: pending.id, request: request) }
        await fulfillment(of: [started], timeout: 2)

        XCTAssertEqual(store.mutatingProtocolID, pending.id)
        let second = await store.activateStarter(id: pending.id, request: request)
        XCTAssertFalse(second)

        await gate.open()
        let first = await firstActivation.value

        XCTAssertTrue(first)
        XCTAssertEqual(store.protocols, [activated])
        XCTAssertNil(store.mutatingProtocolID)
        XCTAssertEqual(store.revision, 1)
        let activationRequests = api.requestLog.filter {
            if case .activateStarterProtocol = $0 { return true }
            return false
        }
        XCTAssertEqual(activationRequests.count, 1)
    }

    // MARK: - Store: dose logs

    func testLoadDoseLogsStoresHistory() async {
        let api = MockAPIClient()
        let log = makeDoseLog(protocolID: ProtocolModel.fixture.id)
        api.setMockResponse([log], for: Endpoint.getDoseLogs(protocolID: ProtocolModel.fixture.id))
        let store = ProtocolStore(api: api)

        await store.loadDoseLogs(protocolID: ProtocolModel.fixture.id)

        XCTAssertEqual(store.doseLogs, [log])
    }

    func testLogDosePrependsToLoadedHistory() async {
        let api = MockAPIClient()
        let older = makeDoseLog(protocolID: ProtocolModel.fixture.id)
        api.setMockResponse([older], for: Endpoint.getDoseLogs(protocolID: ProtocolModel.fixture.id))
        let logged = makeDoseLog(protocolID: ProtocolModel.fixture.id)
        api.setMockResponse(logged, for: Endpoint.createDoseLog(.fixture))
        let store = ProtocolStore(api: api)
        await store.loadDoseLogs(protocolID: ProtocolModel.fixture.id)

        let result = await store.logDose(.fixture)

        XCTAssertEqual(result, logged)
        XCTAssertEqual(store.doseLogs, [logged, older])
        XCTAssertEqual(store.revision, 1)
    }

    func testLogDoseKeepsLoadedHistorySortedByAdministeredAtDescending() async {
        let api = MockAPIClient()
        let newer = makeDoseLog(
            protocolID: ProtocolModel.fixture.id,
            administeredAt: Date(timeIntervalSince1970: 1_783_953_000)
        )
        let older = makeDoseLog(
            protocolID: ProtocolModel.fixture.id,
            administeredAt: Date(timeIntervalSince1970: 1_783_000_000)
        )
        api.setMockResponse([newer], for: Endpoint.getDoseLogs(protocolID: ProtocolModel.fixture.id))
        api.setMockResponse(older, for: Endpoint.createDoseLog(.fixture))
        let store = ProtocolStore(api: api)
        await store.loadDoseLogs(protocolID: ProtocolModel.fixture.id)

        let result = await store.logDose(.fixture)

        XCTAssertEqual(result, older)
        XCTAssertEqual(store.doseLogs, [newer, older])
    }

    func testLogDoseFailureReturnsNilAndSetsError() async {
        let api = MockAPIClient()
        api.setMockError(.serverError, for: Endpoint.createDoseLog(.fixture))
        let store = ProtocolStore(api: api)

        let result = await store.logDose(.fixture)

        XCTAssertNil(result)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.revision, 0)
    }

    // MARK: - Dependencies

    func testDependenciesProvideProtocolStore() {
        let dependencies = Dependencies.mock()

        XCTAssertTrue(dependencies.protocolStore.protocols.isEmpty)
        XCTAssertTrue(dependencies.protocolStore === dependencies.protocolStore)
    }
}

/// Suspends gated requests until opened, so tests can order overlapping responses.
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

// MARK: - Fixtures

extension ProtocolModel {
    static let fixture = ProtocolModel(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Retatrutide Titration",
        startDate: Date(timeIntervalSince1970: 1_780_000_000),
        endDate: nil,
        notes: nil,
        isActive: true,
        setupStatus: "active",
        isStarter: false,
        compounds: [.fixture]
    )
}

extension Compound {
    static let fixture = Compound(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        name: "Retatrutide",
        doseMg: 2.5,
        doseUnit: "mg",
        frequency: "weekly",
        administrationRoute: "subcutaneous",
        notes: nil
    )
}

extension CreateCompoundRequest {
    static let fixture = CreateCompoundRequest(
        name: "Retatrutide",
        doseMg: 2.5,
        doseUnit: "mg",
        frequency: "weekly",
        administrationRoute: "subcutaneous",
        notes: nil
    )
}

extension CreateProtocolRequest {
    static let fixture = CreateProtocolRequest(
        name: "Retatrutide Titration",
        startDate: Date(timeIntervalSince1970: 1_780_000_000),
        endDate: nil,
        notes: nil,
        compounds: [.fixture]
    )
}

extension CreateDoseLogRequest {
    static let fixture = CreateDoseLogRequest(
        protocolID: ProtocolModel.fixture.id,
        compoundID: Compound.fixture.id,
        dose: 2.5,
        unit: "mg",
        administeredAt: Date(timeIntervalSince1970: 1_783_953_000),
        route: "subcutaneous",
        notes: nil
    )
}

// MARK: - Next dose scheduling (shared with Dashboard)

final class ProtocolNextDueCompoundTests: XCTestCase {
    func testNextDueCompoundFallsBackToStartDateWithoutLogs() {
        let result = ProtocolModel.fixture.nextDueCompound(doseLogs: [])

        XCTAssertEqual(result?.compound.id, Compound.fixture.id)
        XCTAssertEqual(result?.dueDate, ProtocolModel.fixture.startDate)
    }

    func testNextDueCompoundAdvancesPastLatestLogByFrequency() {
        let latest = Date(timeIntervalSince1970: 1_783_953_000)
        let log = DoseLog(
            id: UUID(),
            protocolID: ProtocolModel.fixture.id,
            compoundID: Compound.fixture.id,
            dose: 2.5,
            unit: "mg",
            administeredAt: latest,
            route: "subcutaneous",
            notes: nil
        )

        let result = ProtocolModel.fixture.nextDueCompound(doseLogs: [log])

        XCTAssertEqual(result?.dueDate, latest.addingTimeInterval(7 * 86_400))
    }

    func testNextDueCompoundPicksEarliestAcrossMultipleCompounds() {
        let secondCompound = Compound(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Semaglutide",
            doseMg: 1.0,
            doseUnit: "mg",
            frequency: "daily",
            administrationRoute: "subcutaneous",
            notes: nil
        )
        let twoCompoundProtocol = ProtocolModel(
            id: ProtocolModel.fixture.id,
            name: ProtocolModel.fixture.name,
            startDate: ProtocolModel.fixture.startDate,
            endDate: nil,
            notes: nil,
            isActive: true,
            setupStatus: "active",
            isStarter: false,
            compounds: [Compound.fixture, secondCompound]
        )
        // Fixture compound (weekly) was last dosed further back than the
        // second compound (daily) was, so its +7-day due date lands later
        // than the second compound's +1-day due date — the second compound
        // should win.
        let fixtureLastDose = Date(timeIntervalSince1970: 1_783_000_000)
        let secondCompoundLastDose = Date(timeIntervalSince1970: 1_783_500_000)
        let logs = [
            DoseLog(
                id: UUID(), protocolID: twoCompoundProtocol.id, compoundID: Compound.fixture.id,
                dose: 2.5, unit: "mg", administeredAt: fixtureLastDose,
                route: "subcutaneous", notes: nil
            ),
            DoseLog(
                id: UUID(), protocolID: twoCompoundProtocol.id, compoundID: secondCompound.id,
                dose: 1.0, unit: "mg", administeredAt: secondCompoundLastDose,
                route: "subcutaneous", notes: nil
            ),
        ]

        let result = twoCompoundProtocol.nextDueCompound(doseLogs: logs)

        XCTAssertEqual(result?.compound.id, secondCompound.id)
        XCTAssertEqual(result?.dueDate, secondCompoundLastDose.addingTimeInterval(86_400))
    }

    func testNextDueCompoundReturnsNilForProtocolWithNoCompounds() {
        let empty = ProtocolModel(
            id: ProtocolModel.fixture.id,
            name: ProtocolModel.fixture.name,
            startDate: ProtocolModel.fixture.startDate,
            endDate: nil,
            notes: nil,
            isActive: true,
            setupStatus: "active",
            isStarter: false,
            compounds: []
        )

        XCTAssertNil(empty.nextDueCompound(doseLogs: []))
    }
}
