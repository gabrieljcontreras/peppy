import SwiftUI
import XCTest
@testable import peppy

@MainActor
final class OnboardingComponentTests: XCTestCase {
    func testProgressProvidesAccessibleStepLabel() {
        let progress = PepOnboardingProgress(currentStep: 3, totalSteps: 7)

        XCTAssertEqual(progress.currentStep, 3)
        XCTAssertEqual(progress.totalSteps, 7)
        XCTAssertEqual(progress.accessibilityText, "Step 3 of 7")
    }

    func testSelectionChipStoresSelectionStateAndAction() {
        var didTap = false

        let chip = PepSelectionChip(title: "Retatrutide", isSelected: true) {
            didTap = true
        }

        XCTAssertEqual(chip.title, "Retatrutide")
        XCTAssertTrue(chip.isSelected)

        chip.action()

        XCTAssertTrue(didTap)
    }

    func testScaffoldDefaultsMatchQuestionnaireNavigation() {
        let scaffold = OnboardingScaffold(
            step: 2,
            title: Text("Height"),
            subtitle: "Tell us your height",
            primaryAction: {},
            backAction: {},
            skipAction: {}
        ) {
            Text("Height picker")
        }

        XCTAssertEqual(scaffold.step, 2)
        XCTAssertEqual(scaffold.primaryTitle, "Continue")
        XCTAssertTrue(scaffold.canGoBack)
        XCTAssertTrue(scaffold.showsSkip)
        XCTAssertFalse(scaffold.isPrimaryLoading)
    }

    func testScaffoldSupportsIntroStyleNavigation() {
        let scaffold = OnboardingScaffold(
            step: nil,
            title: Text("Let's make peppy yours"),
            subtitle: "A quick setup for your baseline.",
            primaryTitle: "Get started",
            canGoBack: false,
            showsSkip: false,
            isPrimaryLoading: true,
            primaryAction: {},
            backAction: {},
            skipAction: {}
        ) {
            Text("Intro content")
        }

        XCTAssertNil(scaffold.step)
        XCTAssertEqual(scaffold.primaryTitle, "Get started")
        XCTAssertFalse(scaffold.canGoBack)
        XCTAssertFalse(scaffold.showsSkip)
        XCTAssertTrue(scaffold.isPrimaryLoading)
    }
}
