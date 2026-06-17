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

    func testFlowUsesPlaceholderForLaterStepsUntilTasksNineAndTen() {
        XCTAssertEqual(OnboardingFlowView.screen(for: .peptides), .placeholder)
        XCTAssertEqual(OnboardingFlowView.screen(for: .medications), .placeholder)
        XCTAssertEqual(OnboardingFlowView.screen(for: .workout), .placeholder)
        XCTAssertEqual(OnboardingFlowView.screen(for: .goals), .placeholder)
        XCTAssertEqual(OnboardingFlowView.screen(for: .health), .placeholder)
        XCTAssertEqual(OnboardingFlowView.screen(for: .notifications), .placeholder)
    }
}
