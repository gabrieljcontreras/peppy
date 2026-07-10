import XCTest
@testable import peppy

@MainActor
final class CompoundEditorViewModelTests: XCTestCase {
    func testCompoundRequiresTrimmedNamePositiveDoseAndScheduleFields() {
        let model = CompoundEditorViewModel(mode: .create)

        XCTAssertFalse(model.canSubmit)
        XCTAssertEqual(model.validation.name, "Compound name is required.")
        XCTAssertEqual(model.validation.dose, "Enter a positive dose.")
        XCTAssertNil(model.validation.unit)
        XCTAssertEqual(model.validation.frequency, "Frequency is required.")
        XCTAssertNil(model.validation.route)

        model.name = " Retatrutide "
        model.doseText = "0"
        model.frequency = " weekly "

        XCTAssertFalse(model.canSubmit)
        XCTAssertNil(model.validation.name)
        XCTAssertEqual(model.validation.dose, "Enter a positive dose.")
        XCTAssertNil(model.validation.frequency)
    }

    func testCompoundBuildsTrimmedDraft() throws {
        let model = CompoundEditorViewModel(mode: .create)
        model.name = " Retatrutide "
        model.doseText = " 2.5 "
        model.unit = " mg "
        model.frequency = " weekly "
        model.route = " subcutaneous "
        model.notes = " Rotate sites "

        let draft = try XCTUnwrap(model.submitDraft())

        XCTAssertEqual(draft.name, "Retatrutide")
        XCTAssertEqual(draft.doseText, "2.5")
        XCTAssertEqual(draft.unit, "mg")
        XCTAssertEqual(draft.frequency, "weekly")
        XCTAssertEqual(draft.route, "subcutaneous")
        XCTAssertEqual(draft.notes, "Rotate sites")
        XCTAssertNil(draft.persistedID)
    }

    func testCompoundEditPrepopulatesDraft() {
        let persistedID = UUID()
        let draft = CompoundDraft(
            persistedID: persistedID,
            name: "Retatrutide",
            doseText: "2.5",
            unit: "mg",
            frequency: "weekly",
            route: "subcutaneous",
            notes: "Rotate sites"
        )

        let model = CompoundEditorViewModel(mode: .edit(draft))

        XCTAssertEqual(model.persistedID, persistedID)
        XCTAssertEqual(model.name, "Retatrutide")
        XCTAssertEqual(model.doseText, "2.5")
        XCTAssertEqual(model.unit, "mg")
        XCTAssertEqual(model.frequency, "weekly")
        XCTAssertEqual(model.route, "subcutaneous")
        XCTAssertEqual(model.notes, "Rotate sites")
        XCTAssertTrue(model.canSubmit)
    }

    func testCompoundEditPrepopulatesLargeDoseWithoutGroupingSeparators() throws {
        let compound = Compound(
            id: UUID(),
            name: "NAD+",
            doseMg: 1000,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            notes: nil
        )

        let draft = CompoundDraft(compound: compound)

        XCTAssertEqual(draft.doseText, "1000")
        XCTAssertEqual(try XCTUnwrap(draft.createRequest).doseMg, 1000)
    }
}
