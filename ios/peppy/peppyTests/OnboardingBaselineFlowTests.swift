import SwiftUI
import XCTest
@testable import peppy

@MainActor
final class OnboardingBaselineFlowTests: XCTestCase {
    func testIntroStoresPrimaryAndSignInActions() {
        var didContinue = false
        var didSignIn = false

        let intro = OnboardingIntroView(
            continueAction: { didContinue = true },
            signInAction: { didSignIn = true }
        )

        intro.continueAction()
        intro.signInAction()

        XCTAssertTrue(didContinue)
        XCTAssertTrue(didSignIn)
    }

    func testAgeStepDefaultsAndClamps() {
        var age: Int?
        let view = AgeStepView(age: Binding(get: { age }, set: { age = $0 }))

        XCTAssertEqual(view.displayedAge, 32)

        view.decrementAge()
        XCTAssertEqual(age, 31)

        age = 13
        view.decrementAge()
        XCTAssertEqual(age, 13)

        age = 120
        view.incrementAge()
        XCTAssertEqual(age, 120)
    }

    func testAgeStepAcceptsDirectNumericEntryAndClamps() {
        XCTAssertEqual(AgeStepView.clampedAge(44), 44)
        XCTAssertEqual(AgeStepView.clampedAge(9), 13)
        XCTAssertEqual(AgeStepView.clampedAge(140), 120)
    }

    func testHeightStepConvertsPersistedCentimetersToImperialDisplay() {
        let parts = HeightStepView.imperialParts(
            from: OnboardingDraft.centimeters(feet: 6, inches: 2)
        )

        XCTAssertEqual(parts.feet, 6)
        XCTAssertEqual(parts.inches, 2)
        XCTAssertEqual(
            HeightStepView.centimeters(feet: parts.feet, inches: parts.inches),
            187.96,
            accuracy: 0.001
        )
    }

    func testHeightStepAcceptsDirectNumericEntryAndFitsPhoneWidth() {
        let contentWidth: CGFloat = 393 - 48

        XCTAssertLessThanOrEqual(HeightStepView.imperialCardsMinimumWidth, contentWidth)
        XCTAssertEqual(HeightStepView.clampedFeet(7), 7)
        XCTAssertEqual(HeightStepView.clampedFeet(12), 8)
        XCTAssertEqual(HeightStepView.clampedInches(9), 9)
        XCTAssertEqual(HeightStepView.clampedInches(14), 11)
        XCTAssertEqual(HeightStepView.clampedCentimeters(188), 188)
        XCTAssertEqual(HeightStepView.clampedCentimeters(80), 100)
        XCTAssertEqual(HeightStepView.clampedCentimeters(280), 250)
    }

    func testWeightStepDisplaysAndNormalizesSelectedUnit() {
        let kilograms = OnboardingDraft.kilograms(pounds: 165)

        XCTAssertEqual(WeightStepView.displayedValue(from: kilograms, unit: .pounds), 165)
        XCTAssertEqual(WeightStepView.displayedValue(from: kilograms, unit: .kilograms), 75)
        XCTAssertEqual(
            WeightStepView.kilograms(from: 166, unit: .pounds),
            OnboardingDraft.kilograms(pounds: 166),
            accuracy: 0.001
        )
        XCTAssertEqual(WeightStepView.kilograms(from: 76, unit: .kilograms), 76)
    }

    func testWeightStepAcceptsDirectNumericEntryAndClamps() {
        XCTAssertEqual(WeightStepView.clampedDisplayedValue(190, unit: .pounds), 190)
        XCTAssertEqual(WeightStepView.clampedDisplayedValue(40, unit: .pounds), 60)
        XCTAssertEqual(WeightStepView.clampedDisplayedValue(900, unit: .pounds), 700)
        XCTAssertEqual(WeightStepView.clampedDisplayedValue(86, unit: .kilograms), 86)
        XCTAssertEqual(WeightStepView.clampedDisplayedValue(20, unit: .kilograms), 27)
        XCTAssertEqual(WeightStepView.clampedDisplayedValue(400, unit: .kilograms), 318)
    }

    func testFlowScreenMetadataMatchesBaselineSteps() {
        XCTAssertEqual(OnboardingFlowView.screen(for: .intro), .intro)
        XCTAssertEqual(
            OnboardingFlowView.screen(for: .age),
            .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 1,
                    title: "How old are you?",
                    subtitle: "Your age helps peppy contextualize your health patterns and personalize your insights."
                )
            )
        )
        XCTAssertEqual(
            OnboardingFlowView.screen(for: .height),
            .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 2,
                    title: "What's your height?",
                    subtitle: "Your height helps peppy contextualize your health patterns and trends."
                )
            )
        )
        XCTAssertEqual(
            OnboardingFlowView.screen(for: .weight),
            .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 3,
                    title: "What is your current weight?",
                    subtitle: "This creates your starting point. You can update it during daily check-ins."
                )
            )
        )
    }

    func testFlowScreenMetadataMatchesQuestionnaireCompletionSteps() {
        XCTAssertEqual(
            OnboardingFlowView.screen(for: .peptides),
            .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 4,
                    title: "What peptides are you taking?",
                    subtitle: "Select any you're currently using or planning to start. You can always update this later."
                )
            )
        )
        XCTAssertEqual(
            OnboardingFlowView.screen(for: .medications),
            .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 5,
                    title: "Any other medications?",
                    subtitle: "This is optional. It helps peppy flag potential interactions and provide safer insights."
                )
            )
        )
        XCTAssertEqual(
            OnboardingFlowView.screen(for: .workout),
            .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 6,
                    title: "How often do you work out?",
                    subtitle: "This helps peppy understand your activity level and tailor recovery insights."
                )
            )
        )
        XCTAssertEqual(
            OnboardingFlowView.screen(for: .goals),
            .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 7,
                    title: "What do you hope to get out of peppy?",
                    subtitle: "Pick as many as you'd like. This helps us shape your experience."
                )
            )
        )
    }

    func testFlowScreenMetadataMatchesPermissionSteps() {
        XCTAssertEqual(OnboardingFlowView.screen(for: .health), .healthPermission)
        XCTAssertEqual(OnboardingFlowView.screen(for: .notifications), .notificationPermission)
    }
}
