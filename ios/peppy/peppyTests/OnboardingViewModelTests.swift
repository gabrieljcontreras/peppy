import XCTest
@testable import peppy

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    func testResumeLoadsSavedStep() {
        let store = InMemoryOnboardingStore()
        var draft = OnboardingDraft()
        draft.currentStep = .weight
        draft.age = 32
        store.saveAnonymousDraft(draft)

        let model = OnboardingViewModel(
            store: store,
            healthKit: MockHealthKitService(outcome: .requested),
            notifications: MockNotificationPermissionService(outcome: .authorized)
        )

        XCTAssertEqual(model.draft.currentStep, .weight)
        XCTAssertEqual(model.draft.age, 32)
    }

    func testAgeUpdatePersistsImmediately() {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)

        model.setAge(32)

        XCTAssertEqual(store.loadAnonymousDraft()?.age, 32)
    }

    func testCompletingNotificationStepMarksDraftComplete() async {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)
        model.draft.currentStep = .notifications

        await model.requestNotifications()

        XCTAssertTrue(model.draft.isComplete)
        XCTAssertEqual(model.draft.notificationChoice, .requested)
        XCTAssertEqual(model.draft.notificationOutcome, .authorized)
        XCTAssertTrue(store.loadAnonymousDraft()?.isComplete == true)
    }

    func testHeightAndWeightUpdatesPersistNormalizedValuesAndUnits() {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)

        model.setHeightCentimeters(172.72, unit: .feetAndInches)
        model.setWeightKilograms(74.84, unit: .pounds)

        let savedDraft = store.loadAnonymousDraft()
        XCTAssertEqual(savedDraft?.heightCentimeters, 172.72)
        XCTAssertEqual(savedDraft?.preferredHeightUnit, .feetAndInches)
        XCTAssertEqual(savedDraft?.weightKilograms, 74.84)
        XCTAssertEqual(savedDraft?.preferredWeightUnit, .pounds)
    }

    func testPeptideTogglePersistsSelectionAndRemoval() {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)

        model.togglePeptide("Retatrutide")
        XCTAssertEqual(store.loadAnonymousDraft()?.selectedPeptides, ["Retatrutide"])

        model.togglePeptide("Retatrutide")
        XCTAssertEqual(store.loadAnonymousDraft()?.selectedPeptides, [])
    }

    func testOptionalTextUpdatesTrimBlankValues() {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)

        model.setOtherMedications("  metformin  ")
        model.setCustomGoal("   ")

        XCTAssertEqual(store.loadAnonymousDraft()?.otherMedications, "metformin")
        XCTAssertNil(store.loadAnonymousDraft()?.customGoal)
    }

    func testWorkoutAndGoalUpdatesPersistImmediately() {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)

        model.setWorkoutDays(4)
        model.toggleGoal(.buildHabits)
        model.setCustomGoal("Improve recovery")

        let savedDraft = store.loadAnonymousDraft()
        XCTAssertEqual(savedDraft?.workoutDaysPerWeek, 4)
        XCTAssertEqual(savedDraft?.goals, [.buildHabits])
        XCTAssertEqual(savedDraft?.customGoal, "Improve recovery")

        model.toggleGoal(.buildHabits)
        XCTAssertEqual(store.loadAnonymousDraft()?.goals, [])
    }

    func testContinueAndBackTrackNavigationDirection() {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)
        model.draft.currentStep = .age

        model.continueToNextStep()
        XCTAssertEqual(model.draft.currentStep, .height)
        XCTAssertEqual(model.navigationDirection, .forward)

        model.goBack()
        XCTAssertEqual(model.draft.currentStep, .age)
        XCTAssertEqual(model.navigationDirection, .backward)
    }

    func testSkippingLeavesValueAbsent() {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)
        model.draft.currentStep = .age

        model.skipCurrentStep()

        XCTAssertNil(model.draft.age)
        XCTAssertEqual(model.draft.currentStep, .height)
    }

    func testSkippingNotificationsCompletesDraftWithoutOutcome() {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)
        model.draft.currentStep = .notifications

        model.skipCurrentStep()

        XCTAssertTrue(model.draft.isComplete)
        XCTAssertEqual(model.draft.notificationChoice, .skipped)
        XCTAssertEqual(model.draft.notificationOutcome, .notDetermined)
        XCTAssertTrue(store.loadAnonymousDraft()?.isComplete == true)
    }

    func testRequestHealthAccessStoresOutcomeAndAdvances() async {
        let store = InMemoryOnboardingStore()
        let model = OnboardingViewModel(
            store: store,
            healthKit: MockHealthKitService(outcome: .unavailable),
            notifications: MockNotificationPermissionService(outcome: .authorized)
        )
        model.draft.currentStep = .health

        await model.requestHealthAccess()

        XCTAssertEqual(model.draft.currentStep, .notifications)
        XCTAssertEqual(model.draft.healthChoice, .requested)
        XCTAssertEqual(model.draft.healthOutcome, .unavailable)
        XCTAssertEqual(store.loadAnonymousDraft()?.healthOutcome, .unavailable)
    }

    func testCompletePersistsCompletionState() {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)

        model.complete()

        XCTAssertTrue(model.draft.isComplete)
        XCTAssertTrue(store.loadAnonymousDraft()?.isComplete == true)
    }

    private func makeModel(store: InMemoryOnboardingStore) -> OnboardingViewModel {
        OnboardingViewModel(
            store: store,
            healthKit: MockHealthKitService(outcome: .requested),
            notifications: MockNotificationPermissionService(outcome: .authorized)
        )
    }
}
