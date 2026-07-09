import Foundation
import Observation

enum ProtocolEditorMode {
    case create
    case edit(ProtocolModel)
}

struct ProtocolEditorValidation: Equatable {
    var nameOrForm: String?
    var dateRange: String?

    var isValid: Bool {
        nameOrForm == nil && dateRange == nil
    }
}

@MainActor
@Observable
final class ProtocolEditorViewModel {
    private let mode: ProtocolEditorMode
    private let store: ProtocolStore
    private let originalCompoundsByID: [UUID: Compound]

    var name: String
    var startDate: Date?
    var endDate: Date?
    var notes: String
    var compounds: [CompoundDraft]
    var isSubmitting = false
    var errorMessage: String?

    init(mode: ProtocolEditorMode, store: ProtocolStore) {
        self.mode = mode
        self.store = store

        switch mode {
        case .create:
            originalCompoundsByID = [:]
            name = ""
            startDate = nil
            endDate = nil
            notes = ""
            compounds = []
        case .edit(let protocolValue):
            originalCompoundsByID = Dictionary(
                uniqueKeysWithValues: protocolValue.compounds.map { ($0.id, $0) }
            )
            name = protocolValue.name
            startDate = protocolValue.startDate
            endDate = protocolValue.endDate
            notes = protocolValue.notes ?? ""
            compounds = protocolValue.compounds.map(CompoundDraft.init(compound:))
        }
    }

    var validation: ProtocolEditorValidation {
        var nameOrForm: String?
        if name.trimmed.isEmpty {
            nameOrForm = "Protocol name is required."
        } else if startDate == nil {
            nameOrForm = "Start date is required."
        } else if compounds.isEmpty {
            nameOrForm = "Add at least one compound."
        } else if compounds.contains(where: { $0.createRequest == nil }) {
            nameOrForm = "Resolve compound validation errors."
        }

        var dateRange: String?
        if let startDate, let endDate, endDate < startDate {
            dateRange = "End date must be after start date."
        }

        return ProtocolEditorValidation(nameOrForm: nameOrForm, dateRange: dateRange)
    }

    var canSubmit: Bool {
        validation.isValid
    }

    func createRequest() -> CreateProtocolRequest? {
        guard canSubmit, let startDate else { return nil }
        let compoundRequests = compounds.compactMap(\.createRequest)
        guard compoundRequests.count == compounds.count else { return nil }

        return CreateProtocolRequest(
            name: name.trimmed,
            startDate: startDate,
            endDate: endDate,
            notes: notes.nilIfTrimmedEmpty,
            compounds: compoundRequests
        )
    }

    func updateRequest() -> UpdateProtocolRequest? {
        guard canSubmit, startDate != nil else { return nil }
        let shouldClearEndDate: Bool
        let shouldClearNotes: Bool
        switch mode {
        case .create:
            shouldClearEndDate = false
            shouldClearNotes = false
        case .edit(let protocolValue):
            shouldClearEndDate = protocolValue.endDate != nil && endDate == nil
            shouldClearNotes = protocolValue.notes != nil && notes.nilIfTrimmedEmpty == nil
        }

        return UpdateProtocolRequest(
            name: name.trimmed,
            startDate: startDate,
            endDate: endDate,
            notes: notes.nilIfTrimmedEmpty,
            clearEndDate: shouldClearEndDate,
            clearNotes: shouldClearNotes
        )
    }

    func submit() async -> Bool {
        guard !isSubmitting else { return false }
        guard canSubmit else {
            errorMessage = validation.nameOrForm ?? validation.dateRange
            return false
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        switch mode {
        case .create:
            guard let request = createRequest(),
                  await store.create(request) != nil else {
                errorMessage = store.errorMessage
                return false
            }
            return true

        case .edit(let protocolValue):
            return await submitEdit(protocolValue: protocolValue)
        }
    }

    private func submitEdit(protocolValue: ProtocolModel) async -> Bool {
        guard let request = updateRequest(),
              await store.update(id: protocolValue.id, request: request) != nil else {
            errorMessage = store.errorMessage
            return false
        }

        for draft in persistedDraftsNeedingUpdate {
            guard let persistedID = draft.persistedID,
                  let request = draft.updateRequest,
                  await store.updateCompound(id: persistedID, request: request) != nil else {
                errorMessage = store.errorMessage
                return false
            }
        }

        for draft in newDrafts {
            guard let request = draft.createRequest,
                  await store.addCompound(protocolID: protocolValue.id, request: request) != nil else {
                errorMessage = store.errorMessage
                return false
            }
        }

        for compoundID in removedCompoundIDs {
            guard await store.removeCompound(id: compoundID, protocolID: protocolValue.id) else {
                errorMessage = store.errorMessage
                return false
            }
        }

        return true
    }

    private var persistedDraftsNeedingUpdate: [CompoundDraft] {
        compounds.filter { draft in
            guard let persistedID = draft.persistedID,
                  let original = originalCompoundsByID[persistedID] else {
                return false
            }
            return !draft.matches(original)
        }
    }

    private var newDrafts: [CompoundDraft] {
        compounds.filter { $0.persistedID == nil }
    }

    private var removedCompoundIDs: [UUID] {
        let currentPersistedIDs = Set(compounds.compactMap(\.persistedID))
        return originalCompoundsByID.keys.filter { !currentPersistedIDs.contains($0) }
    }
}
