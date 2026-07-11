import Foundation
import Observation

@MainActor
@Observable
final class StarterProtocolViewModel {
    let protocolID: UUID
    let compounds: [String]
    private let store: ProtocolStore

    var doseText = ""
    var frequency = ""
    var route = ""
    var startDate: Date?
    var isSaving = false
    var saveErrorMessage: String?

    init(protocolID: UUID, compounds: [String], store: ProtocolStore) {
        self.protocolID = protocolID
        self.compounds = compounds
        self.store = store
        self.startDate = Date()
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
        guard !isSaving else { return false }
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

        guard await store.activateStarter(id: protocolID, request: request) else {
            saveErrorMessage = store.errorMessage
            return false
        }
        return true
    }

    private var doseMg: Double? {
        Double(doseText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
