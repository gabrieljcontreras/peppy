import Foundation
import Observation

@MainActor
@Observable
final class CheckinViewModel {
    private let api: APIClientProtocol
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

    init(api: APIClientProtocol, date: Date = Date()) {
        self.api = api
        self.date = date
    }

    var canSave: Bool {
        request.hasUserSignal
    }

    func save() async -> Bool {
        let request = request
        guard request.hasUserSignal else {
            errorMessage = "Add at least one metric, symptom, or note."
            return false
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let _: Checkin = try await api.execute(.createCheckin(request))
            return true
        } catch let error as APIError {
            errorMessage = error.userMessage
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private var request: CreateCheckinRequest {
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

    private var normalizedWeight: Double? {
        let trimmed = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
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
