import Foundation
import Observation

enum CheckinEditorMode: Equatable {
    case create(Date)
    case edit(Checkin)
}

enum CheckinEditorOutcome: Equatable {
    case saved(UUID)
    case existing(UUID)
}

@MainActor
@Observable
final class CheckinViewModel {
    private let store: CheckinStore
    private let preferences: WeightUnitPreferences
    private let editingID: UUID?
    let date: Date

    var weightText = ""
    var energyLevel: Int?
    var sleepQuality: Int?
    var appetiteLevel: Int?
    var mood: Int?
    var nausea = 0
    var injectionSiteReaction = 0
    var fatigue = 0
    var headache = 0
    var giIssues = 0
    var notes = ""
    var isSaving = false
    var errorMessage: String?

    init(
        store: CheckinStore,
        preferences: WeightUnitPreferences,
        mode: CheckinEditorMode
    ) {
        self.store = store
        self.preferences = preferences

        switch mode {
        case .create(let date):
            self.date = date
            editingID = nil
        case .edit(let checkin):
            date = checkin.date
            editingID = checkin.id
            weightText = checkin.weightKg.map {
                String(format: "%.1f", preferences.unit.displayValue(kilograms: $0))
            } ?? ""
            energyLevel = checkin.energyLevel
            sleepQuality = checkin.sleepQuality
            appetiteLevel = checkin.appetiteLevel
            mood = checkin.mood
            nausea = checkin.nausea ?? 0
            injectionSiteReaction = checkin.injectionSiteReaction ?? 0
            fatigue = checkin.fatigue ?? 0
            headache = checkin.headache ?? 0
            giIssues = checkin.giIssues ?? 0
            notes = checkin.notes ?? ""
        }
    }

    var canSave: Bool {
        !hasInvalidWeight && createRequest.hasUserSignal && !isSaving
    }

    var selectedWeightUnit: WeightUnit {
        preferences.unit
    }

    func changeWeightUnit(to newUnit: WeightUnit) {
        guard newUnit != preferences.unit else { return }
        let oldUnit = preferences.unit
        let trimmed = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.hasSuffix("."), let value = Double(trimmed) {
            let kilograms = oldUnit.kilograms(from: value)
            weightText = String(
                format: "%.1f",
                newUnit.displayValue(kilograms: kilograms)
            )
        }
        preferences.select(newUnit)
    }

    func save() async -> CheckinEditorOutcome? {
        guard !hasInvalidWeight else {
            errorMessage = "Enter a valid weight in \(selectedWeightUnit.symbol)."
            return nil
        }
        guard createRequest.hasUserSignal else {
            errorMessage = "Add at least one metric, symptom, or note."
            return nil
        }
        guard !isSaving else { return nil }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        if let editingID {
            guard let updated = await store.update(id: editingID, request: updateRequest) else {
                errorMessage = store.errorMessage
                return nil
            }
            return .saved(updated.id)
        }

        switch await store.create(createRequest) {
        case .saved(let checkin):
            return .saved(checkin.id)
        case .existing(let checkin):
            return .existing(checkin.id)
        case .failed:
            errorMessage = store.errorMessage
            return nil
        }
    }

    private var createRequest: CreateCheckinRequest {
        CreateCheckinRequest(
            date: date,
            weightKg: normalizedWeight,
            energyLevel: energyLevel,
            sleepQuality: sleepQuality,
            appetiteLevel: appetiteLevel,
            mood: mood,
            nausea: severityOrNil(nausea),
            injectionSiteReaction: severityOrNil(injectionSiteReaction),
            fatigue: severityOrNil(fatigue),
            headache: severityOrNil(headache),
            giIssues: severityOrNil(giIssues),
            notes: normalizedNotes
        )
    }

    private var updateRequest: UpdateCheckinRequest {
        UpdateCheckinRequest(
            date: date,
            weightKg: normalizedWeight,
            energyLevel: energyLevel,
            sleepQuality: sleepQuality,
            appetiteLevel: appetiteLevel,
            mood: mood,
            nausea: severityOrNil(nausea),
            injectionSiteReaction: severityOrNil(injectionSiteReaction),
            fatigue: severityOrNil(fatigue),
            headache: severityOrNil(headache),
            giIssues: severityOrNil(giIssues),
            notes: normalizedNotes
        )
    }

    private var normalizedWeight: Double? {
        let trimmed = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasSuffix("."),
              let displayValue = Double(trimmed) else { return nil }
        let kilograms = selectedWeightUnit.kilograms(from: displayValue)
        guard kilograms > 0, kilograms <= 500 else { return nil }
        return kilograms
    }

    private var hasInvalidWeight: Bool {
        let trimmed = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && normalizedWeight == nil
    }

    private var normalizedNotes: String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func severityOrNil(_ value: Int) -> Int? {
        value > 0 ? value : nil
    }
}

private extension CreateCheckinRequest {
    var hasUserSignal: Bool {
        weightKg != nil ||
            energyLevel != nil ||
            sleepQuality != nil ||
            appetiteLevel != nil ||
            mood != nil ||
            nausea != nil ||
            injectionSiteReaction != nil ||
            fatigue != nil ||
            headache != nil ||
            giIssues != nil ||
            notes != nil
    }
}
