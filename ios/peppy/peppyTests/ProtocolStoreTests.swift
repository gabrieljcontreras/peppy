import Foundation
import XCTest
@testable import peppy

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

    private func makeProtocol(setupStatus: String?, isActive: Bool) -> ProtocolModel {
        ProtocolModel(
            id: UUID(),
            name: "Retatrutide Titration",
            startDate: Date(timeIntervalSince1970: 1_780_000_000),
            endDate: nil,
            notes: nil,
            isActive: isActive,
            setupStatus: setupStatus,
            isStarter: false,
            compounds: [.fixture]
        )
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
