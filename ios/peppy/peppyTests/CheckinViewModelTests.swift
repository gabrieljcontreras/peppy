import XCTest
@testable import peppy

@MainActor
final class CheckinViewModelTests: XCTestCase {
    func testCheckinRequestUsesBackendFieldNames() {
        let date = Date(timeIntervalSince1970: 1_788_000_000)

        let request = CreateCheckinRequest(
            date: date,
            weightKg: 74.8,
            energyLevel: 7,
            sleepQuality: 6,
            appetiteLevel: 5,
            mood: 8,
            nausea: 1,
            injectionSiteReaction: 0,
            fatigue: 2,
            headache: 0,
            giIssues: 3,
            notes: "Felt steady after morning dose."
        )

        XCTAssertEqual(request.date, date)
        XCTAssertEqual(request.weightKg, 74.8)
        XCTAssertEqual(request.energyLevel, 7)
        XCTAssertEqual(request.sleepQuality, 6)
        XCTAssertEqual(request.appetiteLevel, 5)
        XCTAssertEqual(request.mood, 8)
        XCTAssertEqual(request.nausea, 1)
        XCTAssertEqual(request.injectionSiteReaction, 0)
        XCTAssertEqual(request.fatigue, 2)
        XCTAssertEqual(request.headache, 0)
        XCTAssertEqual(request.giIssues, 3)
        XCTAssertEqual(request.notes, "Felt steady after morning dose.")
    }

    func testCheckinRequestEncodesBackendJSONShape() throws {
        let encoder = JSONEncoder()
        let date = Date(timeIntervalSince1970: 1_788_000_000)
        let request = CreateCheckinRequest(
            date: date,
            weightKg: 74.8,
            energyLevel: 7,
            sleepQuality: nil,
            appetiteLevel: nil,
            mood: 8,
            nausea: 1,
            injectionSiteReaction: nil,
            fatigue: nil,
            headache: nil,
            giIssues: nil,
            notes: nil
        )

        let data = try encoder.encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["date"] as? String, "2026-08-29")
        XCTAssertEqual(json["weight_kg"] as? Double, 74.8)
        XCTAssertEqual(json["energy_level"] as? Int, 7)
        XCTAssertEqual(json["mood"] as? Int, 8)
        XCTAssertEqual(json["nausea"] as? Int, 1)
        XCTAssertNil(json["sleep_quality"])
        XCTAssertNil(json["symptoms"])
        XCTAssertNil(json["weight"])
    }

    func testSavePostsCreateCheckinRequestWhenFormHasSignal() async {
        let api = MockAPIClient()
        let date = Date(timeIntervalSince1970: 1_788_000_000)
        let response = Checkin.mock(date: date, weightKg: 74.8, energyLevel: 7, mood: 8)
        api.setMockResponse(response, for: "/checkins")

        let model = CheckinViewModel(api: api, date: date)
        model.weightText = "74.8"
        model.energyLevel = 7
        model.mood = 8
        model.nausea = 1
        model.fatigue = 2
        model.notes = "Felt steady after morning dose."

        let didSave = await model.save()

        XCTAssertTrue(didSave)
        XCTAssertFalse(model.isSaving)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(api.requestLog.count, 1)
        guard let endpoint = api.requestLog.first,
              case .createCheckin(let request) = endpoint else {
            return XCTFail("Expected create check-in endpoint")
        }
        XCTAssertEqual(request.date, date)
        XCTAssertEqual(request.weightKg, 74.8)
        XCTAssertEqual(request.energyLevel, 7)
        XCTAssertEqual(request.mood, 8)
        XCTAssertEqual(request.nausea, 1)
        XCTAssertEqual(request.fatigue, 2)
        XCTAssertEqual(request.notes, "Felt steady after morning dose.")
    }

    func testSaveRequiresAtLeastOneMetricSymptomOrNote() async {
        let model = CheckinViewModel(api: MockAPIClient(), date: Date())

        let didSave = await model.save()

        XCTAssertFalse(didSave)
        XCTAssertEqual(model.errorMessage, "Add at least one metric, symptom, or note.")
    }
}

private extension Checkin {
    static func mock(
        date: Date,
        weightKg: Double?,
        energyLevel: Int?,
        mood: Int?
    ) -> Checkin {
        Checkin(
            id: UUID(),
            userId: UUID(),
            date: date,
            weightKg: weightKg,
            energyLevel: energyLevel,
            sleepQuality: nil,
            appetiteLevel: nil,
            mood: mood,
            nausea: nil,
            injectionSiteReaction: nil,
            fatigue: nil,
            headache: nil,
            giIssues: nil,
            notes: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }
}
