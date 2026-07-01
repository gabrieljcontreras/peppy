import XCTest
@testable import peppy

@MainActor
final class StarterProtocolViewModelTests: XCTestCase {
    func testActivationRequiresDoseFrequencyRouteAndStartDate() {
        let model = StarterProtocolViewModel(
            protocolID: UUID(),
            compounds: ["Retatrutide"],
            api: MockAPIClient()
        )

        XCTAssertFalse(model.canSave)
        XCTAssertEqual(model.validationMessage, "Dose, frequency, route, and start date are required.")
    }

    func testCompleteCompoundCanSave() {
        let model = StarterProtocolViewModel(
            protocolID: UUID(),
            compounds: ["Retatrutide"],
            api: MockAPIClient()
        )
        model.doseText = "2"
        model.frequency = "weekly"
        model.route = "subcutaneous"
        model.startDate = Date()

        XCTAssertTrue(model.canSave)
        XCTAssertNil(model.validationMessage)
    }

    func testSavePostsActivationRequestWhenValid() async {
        let api = MockAPIClient()
        let protocolID = UUID()
        let startDate = Date(timeIntervalSince1970: 1_788_000_000)
        let model = StarterProtocolViewModel(
            protocolID: protocolID,
            compounds: ["Retatrutide"],
            api: api
        )
        model.doseText = "2"
        model.frequency = "weekly"
        model.route = "subcutaneous"
        model.startDate = startDate

        let didSave = await model.save()

        XCTAssertTrue(didSave)
        XCTAssertEqual(api.requestLog.count, 1)
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
}
