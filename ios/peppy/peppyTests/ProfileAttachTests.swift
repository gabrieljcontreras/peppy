import XCTest
@testable import peppy

final class ProfileAttachTests: XCTestCase {
    func testOnboardingDraftBuildsAttachRequestWithServerEnums() {
        var draft = OnboardingDraft()
        draft.age = 32
        draft.heightCentimeters = 172.72
        draft.preferredHeightUnit = .feetAndInches
        draft.weightKilograms = 74.84
        draft.preferredWeightUnit = .pounds
        draft.selectedPeptides = ["Retatrutide"]
        draft.workoutDaysPerWeek = 3
        draft.goals = [.trackProtocols, .seeWhatWorks]
        draft.healthChoice = .requested
        draft.healthOutcome = .requested
        draft.notificationChoice = .requested
        draft.notificationOutcome = .authorized
        draft.isComplete = true

        let request = OnboardingProfileAttachRequest(draft: draft)

        XCTAssertEqual(request.schemaVersion, 1)
        XCTAssertEqual(request.profile.preferredHeightUnit, "ft_in")
        XCTAssertEqual(request.profile.preferredWeightUnit, "lb")
        XCTAssertEqual(request.profile.goals.sorted(), ["see_what_works", "track_protocols"])
        XCTAssertEqual(request.profile.healthkit?.requested, true)
        XCTAssertEqual(request.profile.notifications?.authorized, true)
    }
}
