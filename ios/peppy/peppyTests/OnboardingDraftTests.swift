import XCTest
@testable import peppy

final class OnboardingDraftTests: XCTestCase {
    func testFeetAndInchesNormalizeToCentimeters() {
        XCTAssertEqual(
            OnboardingDraft.centimeters(feet: 5, inches: 8),
            172.72,
            accuracy: 0.001
        )
    }

    func testPoundsNormalizeToKilograms() {
        XCTAssertEqual(
            OnboardingDraft.kilograms(pounds: 165),
            74.84268,
            accuracy: 0.001
        )
    }

    func testNextStepAdvancesThroughPermissionScreens() {
        XCTAssertEqual(OnboardingStep.goals.next, .health)
        XCTAssertEqual(OnboardingStep.health.next, .notifications)
        XCTAssertNil(OnboardingStep.notifications.next)
    }

    func testSkippedValuesRemainNil() {
        let draft = OnboardingDraft()
        XCTAssertNil(draft.age)
        XCTAssertNil(draft.heightCentimeters)
        XCTAssertNil(draft.weightKilograms)
        XCTAssertTrue(draft.selectedPeptides.isEmpty)
    }
}
