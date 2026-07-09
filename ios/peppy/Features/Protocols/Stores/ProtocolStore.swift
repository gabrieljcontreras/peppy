import Foundation
import Observation

@MainActor
@Observable
final class ProtocolStore {
    private let api: APIClientProtocol

    private(set) var protocols: [ProtocolModel] = []
    private(set) var selectedProtocol: ProtocolModel?
    private(set) var doseLogs: [DoseLog] = []
    private(set) var isLoading = false
    private(set) var mutatingProtocolID: UUID?
    var errorMessage: String?

    private var hasLoadedProtocols = false
    private var loadToken = 0
    private var selectionToken = 0
    private var doseLogToken = 0
    private var mutatingProtocolIDs: Set<UUID> = []

    init(api: APIClientProtocol) {
        self.api = api
    }

    func loadProtocols(force: Bool = false) async {
        guard force || !hasLoadedProtocols else { return }

        loadToken += 1
        let token = loadToken
        isLoading = true
        errorMessage = nil

        do {
            let loaded: [ProtocolModel] = try await api.execute(.getProtocols)
            guard token == loadToken else { return }
            protocols = loaded
            hasLoadedProtocols = true
            isLoading = false
        } catch {
            guard token == loadToken else { return }
            errorMessage = message(for: error)
            isLoading = false
        }
    }

    func select(_ id: UUID) async {
        selectionToken += 1
        let token = selectionToken

        if let local = protocols.first(where: { $0.id == id }) {
            selectedProtocol = local
        }

        do {
            let detail: ProtocolModel = try await api.execute(.getProtocol(id: id))
            guard token == selectionToken else { return }
            selectedProtocol = detail
            reconcile(detail)
            errorMessage = nil
        } catch {
            guard token == selectionToken else { return }
            errorMessage = message(for: error)
        }
    }

    func create(_ request: CreateProtocolRequest) async -> ProtocolModel? {
        errorMessage = nil

        do {
            let created: ProtocolModel = try await api.execute(.createProtocol(request))
            reconcile(created, insertAtFront: true, deactivateOthersIfActive: created.isActive)
            hasLoadedProtocols = true
            return created
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func update(id: UUID, request: UpdateProtocolRequest) async -> ProtocolModel? {
        guard beginMutation(for: id) else { return nil }
        defer { endMutation(for: id) }

        errorMessage = nil
        do {
            let updated: ProtocolModel = try await api.execute(.updateProtocol(id: id, request))
            reconcile(updated)
            return updated
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func addCompound(protocolID: UUID, request: CreateCompoundRequest) async -> Compound? {
        guard beginMutation(for: protocolID) else { return nil }
        defer { endMutation(for: protocolID) }

        errorMessage = nil
        do {
            let added: Compound = try await api.execute(.addCompound(protocolID: protocolID, request))
            updateProtocol(id: protocolID) { protocolValue in
                protocolValue.replacingCompounds(protocolValue.compounds + [added])
            }
            return added
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func updateCompound(id: UUID, request: UpdateCompoundRequest) async -> Compound? {
        guard let protocolID = owningProtocolID(forCompoundID: id),
              beginMutation(for: protocolID) else {
            return nil
        }
        defer { endMutation(for: protocolID) }

        errorMessage = nil
        do {
            let updated: Compound = try await api.execute(.updateCompound(id: id, request))
            replaceCompound(updated)
            return updated
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func removeCompound(id: UUID, protocolID: UUID) async -> Bool {
        guard beginMutation(for: protocolID) else { return false }
        defer { endMutation(for: protocolID) }

        errorMessage = nil
        do {
            try await api.executeVoid(.removeCompound(id: id))
            updateProtocol(id: protocolID) { protocolValue in
                protocolValue.replacingCompounds(
                    protocolValue.compounds.filter { $0.id != id }
                )
            }
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    func activate(id: UUID) async -> Bool {
        guard beginMutation(for: id) else { return false }
        defer { endMutation(for: id) }

        errorMessage = nil
        do {
            let activated: ProtocolModel = try await api.execute(.activateProtocol(id: id))
            reconcile(activated, deactivateOthersIfActive: activated.isActive)
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    func deactivate(id: UUID) async -> Bool {
        guard beginMutation(for: id) else { return false }
        defer { endMutation(for: id) }

        errorMessage = nil
        do {
            let deactivated: ProtocolModel = try await api.execute(.deactivateProtocol(id: id))
            reconcile(deactivated)
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    func deleteSelected() async -> Bool {
        guard let selectedProtocol else { return false }
        let id = selectedProtocol.id

        guard beginMutation(for: id) else { return false }
        defer { endMutation(for: id) }

        errorMessage = nil
        do {
            try await api.executeVoid(.deleteProtocol(id: id))
            protocols.removeAll { $0.id == id }
            self.selectedProtocol = nil
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    func loadDoseLogs(protocolID: UUID) async {
        doseLogToken += 1
        let token = doseLogToken
        errorMessage = nil

        do {
            let logs: [DoseLog] = try await api.execute(.getDoseLogs(protocolID: protocolID))
            guard token == doseLogToken else { return }
            doseLogs = logs
        } catch {
            guard token == doseLogToken else { return }
            errorMessage = message(for: error)
        }
    }

    func logDose(_ request: CreateDoseLogRequest) async -> DoseLog? {
        errorMessage = nil

        do {
            let logged: DoseLog = try await api.execute(.createDoseLog(request))
            doseLogs.insert(logged, at: 0)
            return logged
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    private func beginMutation(for id: UUID) -> Bool {
        guard !mutatingProtocolIDs.contains(id) else { return false }
        mutatingProtocolIDs.insert(id)
        if mutatingProtocolID == nil {
            mutatingProtocolID = id
        }
        return true
    }

    private func endMutation(for id: UUID) {
        mutatingProtocolIDs.remove(id)
        if mutatingProtocolID == id {
            mutatingProtocolID = mutatingProtocolIDs.first
        }
    }

    private func reconcile(
        _ protocolValue: ProtocolModel,
        insertAtFront: Bool = false,
        deactivateOthersIfActive: Bool = false
    ) {
        if deactivateOthersIfActive {
            protocols = protocols.map { existing in
                existing.id == protocolValue.id || !existing.isActive ? existing : existing.deactivated()
            }
            if let selectedProtocol,
               selectedProtocol.id != protocolValue.id,
               selectedProtocol.isActive {
                self.selectedProtocol = selectedProtocol.deactivated()
            }
        }

        if let index = protocols.firstIndex(where: { $0.id == protocolValue.id }) {
            protocols[index] = protocolValue
        } else if insertAtFront {
            protocols.insert(protocolValue, at: 0)
        } else {
            protocols.append(protocolValue)
        }

        if selectedProtocol?.id == protocolValue.id {
            selectedProtocol = protocolValue
        }
    }

    private func updateProtocol(
        id: UUID,
        transform: (ProtocolModel) -> ProtocolModel
    ) {
        if let index = protocols.firstIndex(where: { $0.id == id }) {
            let updated = transform(protocols[index])
            protocols[index] = updated
            if selectedProtocol?.id == id {
                selectedProtocol = updated
            }
        } else if selectedProtocol?.id == id, let selectedProtocol {
            self.selectedProtocol = transform(selectedProtocol)
        }
    }

    private func replaceCompound(_ compound: Compound) {
        protocols = protocols.map { protocolValue in
            guard protocolValue.compounds.contains(where: { $0.id == compound.id }) else {
                return protocolValue
            }
            return protocolValue.replacingCompounds(
                protocolValue.compounds.map { $0.id == compound.id ? compound : $0 }
            )
        }

        if let selectedProtocol,
           selectedProtocol.compounds.contains(where: { $0.id == compound.id }) {
            self.selectedProtocol = selectedProtocol.replacingCompounds(
                selectedProtocol.compounds.map { $0.id == compound.id ? compound : $0 }
            )
        }
    }

    private func owningProtocolID(forCompoundID compoundID: UUID) -> UUID? {
        if let protocolValue = protocols.first(where: { protocolValue in
            protocolValue.compounds.contains { $0.id == compoundID }
        }) {
            return protocolValue.id
        }

        if let selectedProtocol,
           selectedProtocol.compounds.contains(where: { $0.id == compoundID }) {
            return selectedProtocol.id
        }

        return nil
    }

    private func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.userMessage
        }
        return error.localizedDescription
    }
}

private extension ProtocolModel {
    func replacingCompounds(_ compounds: [Compound]) -> ProtocolModel {
        ProtocolModel(
            id: id,
            name: name,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            isActive: isActive,
            setupStatus: setupStatus,
            isStarter: isStarter,
            compounds: compounds
        )
    }

    func deactivated() -> ProtocolModel {
        ProtocolModel(
            id: id,
            name: name,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            isActive: false,
            setupStatus: "inactive",
            isStarter: isStarter,
            compounds: compounds
        )
    }
}
