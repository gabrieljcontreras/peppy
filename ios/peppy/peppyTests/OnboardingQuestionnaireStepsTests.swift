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

    func testHealthPermissionListsReadOnlyCategories() {
        XCTAssertEqual(
            HealthPermissionView.readCategories,
            [
                "Sleep analysis",
                "Heart rate variability",
                "Resting heart rate",
                "Step count",
                "Active energy burned",
                "Body mass",
                "Workouts"
            ]
        )
    }

    func testNotificationPermissionCardsMatchReminderScope() {
        XCTAssertEqual(
            NotificationPermissionView.cards.map(\.title),
            ["Dose reminders", "Daily check-ins", "Important insights"]
        )
    }

    func testReadySummaryRowsOnlyIncludeProvidedValuesAndPermissionStatus() {
        var draft = OnboardingDraft()
        draft.age = 32
        draft.selectedPeptides = ["Retatrutide"]
        draft.workoutDaysPerWeek = 3
        draft.goals = [.buildHabits]
        draft.healthOutcome = .requested
        draft.notificationOutcome = .authorized

        let rows = ReadySummaryView.rows(for: draft)

        XCTAssertEqual(
            rows.map(\.title),
            ["Baseline", "Peptides", "Activity", "Goals", "Apple Health", "Notifications"]
        )
        XCTAssertEqual(rows.first { $0.title == "Apple Health" }?.value, "Requested")
        XCTAssertEqual(rows.first { $0.title == "Notifications" }?.value, "Enabled")
        XCTAssertFalse(rows.contains { $0.title == "Protocol" || $0.title == "Check-ins" })
    }

    func testReadySummaryOmitsSkippedOptionalAnswers() {
        let rows = ReadySummaryView.rows(for: OnboardingDraft())

        XCTAssertEqual(rows.map(\.title), ["Apple Health", "Notifications"])
        XCTAssertEqual(rows.first { $0.title == "Apple Health" }?.value, "Not connected")
        XCTAssertEqual(rows.first { $0.title == "Notifications" }?.value, "Not enabled")
    }
}
