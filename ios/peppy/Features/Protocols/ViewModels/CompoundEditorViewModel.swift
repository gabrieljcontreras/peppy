import Foundation
import Observation

struct CompoundDraft: Identifiable, Equatable {
    var id = UUID()
    var persistedID: UUID?
    var name = ""
    var doseText = ""
    var unit = "mg"
    var frequency = ""
    var route = "subcutaneous"
    var notes = ""
    var clearsPersistedNotes = false
}

enum CompoundEditorMode: Equatable {
    case create
    case edit(CompoundDraft)
}

struct CompoundEditorValidation: Equatable {
    var name: String?
    var dose: String?
    var unit: String?
    var frequency: String?
    var route: String?

    var isValid: Bool {
        name == nil &&
            dose == nil &&
            unit == nil &&
            frequency == nil &&
            route == nil
    }
}

@MainActor
@Observable
final class CompoundEditorViewModel {
    private let draftID: UUID
    private(set) var persistedID: UUID?

    var name: String
    var doseText: String
    var unit: String
    var frequency: String
    var route: String
    var notes: String

    init(mode: CompoundEditorMode) {
        switch mode {
        case .create:
            let draft = CompoundDraft()
            draftID = draft.id
            persistedID = draft.persistedID
            name = draft.name
            doseText = draft.doseText
            unit = draft.unit
            frequency = draft.frequency
            route = draft.route
            notes = draft.notes
        case .edit(let draft):
            draftID = draft.id
            persistedID = draft.persistedID
            name = draft.name
            doseText = draft.doseText
            unit = draft.unit
            frequency = draft.frequency
            route = draft.route
            notes = draft.notes
        }
    }

    var validation: CompoundEditorValidation {
        CompoundEditorValidation(
            name: normalizedName.isEmpty ? "Compound name is required." : nil,
            dose: normalizedDose.map { $0 > 0 } == true ? nil : "Enter a positive dose.",
            unit: normalizedUnit.isEmpty ? "Unit is required." : nil,
            frequency: normalizedFrequency.isEmpty ? "Frequency is required." : nil,
            route: normalizedRoute.isEmpty ? "Route is required." : nil
        )
    }

    var canSubmit: Bool {
        validation.isValid
    }

    func submitDraft() -> CompoundDraft? {
        guard canSubmit else { return nil }

        return CompoundDraft(
            id: draftID,
            persistedID: persistedID,
            name: normalizedName,
            doseText: normalizedDoseText,
            unit: normalizedUnit,
            frequency: normalizedFrequency,
            route: normalizedRoute,
            notes: normalizedNotes ?? ""
        )
    }

    private var normalizedName: String {
        name.trimmed
    }

    private var normalizedDoseText: String {
        doseText.trimmed
    }

    private var normalizedDose: Double? {
        Double(normalizedDoseText)
    }

    private var normalizedUnit: String {
        unit.trimmed
    }

    private var normalizedFrequency: String {
        frequency.trimmed
    }

    private var normalizedRoute: String {
        route.trimmed
    }

    private var normalizedNotes: String? {
        notes.nilIfTrimmedEmpty
    }
}

extension CompoundDraft {
    init(compound: Compound) {
        self.init(
            persistedID: compound.id,
            name: compound.name,
            doseText: NumberFormatter.protocolDose.string(from: NSNumber(value: compound.doseMg)) ?? "\(compound.doseMg)",
            unit: compound.doseUnit,
            frequency: compound.frequency,
            route: compound.administrationRoute,
            notes: compound.notes ?? "",
            clearsPersistedNotes: compound.notes != nil
        )
    }

    var createRequest: CreateCompoundRequest? {
        guard let doseMg, doseMg > 0 else { return nil }
        let name = name.trimmed
        let unit = unit.trimmed
        let frequency = frequency.trimmed
        let route = route.trimmed
        guard !name.isEmpty, !unit.isEmpty, !frequency.isEmpty, !route.isEmpty else {
            return nil
        }

        return CreateCompoundRequest(
            name: name,
            doseMg: doseMg,
            doseUnit: unit,
            frequency: frequency,
            administrationRoute: route,
            notes: notes.nilIfTrimmedEmpty
        )
    }

    var updateRequest: UpdateCompoundRequest? {
        guard let createRequest else { return nil }
        return UpdateCompoundRequest(
            name: createRequest.name,
            doseMg: createRequest.doseMg,
            doseUnit: createRequest.doseUnit,
            frequency: createRequest.frequency,
            administrationRoute: createRequest.administrationRoute,
            notes: createRequest.notes,
            clearNotes: clearsPersistedNotes && createRequest.notes == nil
        )
    }

    var doseMg: Double? {
        Double(doseText.trimmed)
    }

    func matches(_ compound: Compound) -> Bool {
        guard let createRequest else { return false }
        return createRequest.name == compound.name &&
            createRequest.doseMg == compound.doseMg &&
            createRequest.doseUnit == compound.doseUnit &&
            createRequest.frequency == compound.frequency &&
            createRequest.administrationRoute == compound.administrationRoute &&
            createRequest.notes == compound.notes
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfTrimmedEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}

private extension NumberFormatter {
    static let protocolDose: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
