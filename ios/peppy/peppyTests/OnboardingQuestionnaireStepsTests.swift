import XCTest
@testable import peppy

final class OnboardingQuestionnaireStepsTests: XCTestCase {
    func testPeptideSuggestionsTrimFilterCaseInsensitivelyAndLimitResults() {
        XCTAssertEqual(PeptidesStepView.suggestions(for: " semaglutide "), ["Semaglutide"])
        XCTAssertEqual(PeptidesStepView.suggestions(for: "   "), [])

        let insulinResults = PeptidesStepView.suggestions(for: "in")
        XCTAssertLessThanOrEqual(insulinResults.count, 6)
        XCTAssertTrue(insulinResults.allSatisfy { $0.localizedCaseInsensitiveContains("in") })
    }

    func testPeptideCustomOptionAvoidsCatalogAndSelectedDuplicates() {
        XCTAssertFalse(PeptidesStepView.canAddCustomPeptide("semaglutide", selected: []))
        XCTAssertFalse(PeptidesStepView.canAddCustomPeptide("Custom Peptide", selected: ["custom peptide"]))
        XCTAssertTrue(PeptidesStepView.canAddCustomPeptide("New peptide", selected: []))
    }

    func testMedicationsLimitAndRemainingCount() {
        let longValue = String(repeating: "a", count: 250)

        XCTAssertEqual(MedicationsStepView.limitedText(longValue).count, 200)
        XCTAssertEqual(MedicationsStepView.remainingCharacters(for: "Metformin"), 191)
    }

    func testWorkoutSummaryText() {
        XCTAssertEqual(WorkoutStepView.summary(for: nil), "Choose your weekly rhythm")
        XCTAssertEqual(WorkoutStepView.summary(for: 0), "Rest-focused")
        XCTAssertEqual(WorkoutStepView.summary(for: 1), "1 day per week")
        XCTAssertEqual(WorkoutStepView.summary(for: 3), "2-5 days per week")
        XCTAssertEqual(WorkoutStepView.summary(for: 6), "6 days per week")
        XCTAssertEqual(WorkoutStepView.summary(for: 7), "Daily")
    }

    func testGoalsStepUsesAllOnboardingGoals() {
        XCTAssertEqual(GoalsStepView.options, OnboardingGoal.allCases)
    }
}
