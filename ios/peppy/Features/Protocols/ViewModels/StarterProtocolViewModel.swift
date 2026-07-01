import Foundation
import Observation

@MainActor
@Observable
final class StarterProtocolViewModel {
    let protocolID: UUID
    let compounds: [String]
    private let api: APIClientProtocol

    var doseText = ""
    var frequency = ""
    var route = ""
    var startDate: Date?
    var isSaving = false
    var saveErrorMessage: String?

    init(protocolID: UUID, compounds: [String], api: APIClientProtocol) {
        self.protocolID = protocolID
        self.compounds = compounds
        self.api = api
    }

    var canSave: Bool {
        doseMg.map { $0 > 0 } == true &&
            !frequency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !route.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            startDate != nil
    }

    var validationMessage: String? {
        canSave ? nil : "Dose, frequency, route, and start date are required."
    }

    func save() async -> Bool {
        guard canSave, let doseMg, let startDate else {
            saveErrorMessage = validationMessage
            return false
        }

        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        let request = StarterProtocolActivationRequest(
            doseMg: doseMg,
            doseUnit: "mg",
            frequency: frequency.trimmingCharacters(in: .whitespacesAndNewlines),
            administrationRoute: route.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate
        )

        do {
            try await api.executeVoid(.activateStarterProtocol(id: protocolID, request))
            return true
        } catch let error as APIError {
            saveErrorMessage = error.userMessage
            return false
        } catch {
            saveErrorMessage = error.localizedDescription
            return false
        }
    }

    private var doseMg: Double? {
        Double(doseText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
