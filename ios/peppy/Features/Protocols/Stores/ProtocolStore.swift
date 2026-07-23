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
    /// Bumped after every successful mutation reconciliation so observers (e.g. the
    /// dashboard) can detect that protocol state changed without polling.
    private(set) var revision = 0
    var errorMessage: String?

    private var hasLoadedProtocols = false
    private var loadToken = 0
    private var selectionToken = 0
    private var doseLogToken = 0
    private var mutatingProtocolIDs: Set<UUID> = []
    private var sessionGeneration = 0

    init(api: APIClientProtocol) {
        self.api = api
    }

    func resetSession() {
        sessionGeneration += 1
        loadToken += 1
        selectionToken += 1
        doseLogToken += 1
        protocols = []
        selectedProtocol = nil
        doseLogs = []
        isLoading = false
        mutatingProtocolID = nil
        mutatingProtocolIDs = []
        hasLoadedProtocols = false
        errorMessage = nil
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
        let generation = sessionGeneration
        errorMessage = nil

        do {
            let created: ProtocolModel = try await api.execute(.createProtocol(request))
            guard generation == sessionGeneration else { return nil }
            reconcile(created, insertAtFront: true, deactivateOthersIfActive: created.isActive)
            hasLoadedProtocols = true
            revision += 1
            return created
        } catch {
            guard generation == sessionGeneration else { return nil }
            errorMessage = message(for: error)
            return nil
        }
    }

    func update(id: UUID, request: UpdateProtocolRequest) async -> ProtocolModel? {
        let generation = sessionGeneration
        guard beginMutation(for: id) else { return nil }
        defer {
            if generation == sessionGeneration {
                endMutation(for: id)
            }
        }

        errorMessage = nil
        do {
            let updated: ProtocolModel = try await api.execute(.updateProtocol(id: id, request))
            guard generation == sessionGeneration else { return nil }
            reconcile(updated)
            revision += 1
            return updated
        } catch {
            guard generation == sessionGeneration else { return nil }
            errorMessage = message(for: error)
            return nil
        }
    }

    func addCompound(protocolID: UUID, request: CreateCompoundRequest) async -> Compound? {
        let generation = sessionGeneration
        guard beginMutation(for: protocolID) else { return nil }
        defer {
            if generation == sessionGeneration {
                endMutation(for: protocolID)
            }
        }

        errorMessage = nil
        do {
            let added: Compound = try await api.execute(.addCompound(protocolID: protocolID, request))
            guard generation == sessionGeneration else { return nil }
            updateProtocol(id: protocolID) { protocolValue in
                protocolValue.replacingCompounds(protocolValue.compounds + [added])
            }
            revision += 1
            return added
        } catch {
            guard generation == sessionGeneration else { return nil }
            errorMessage = message(for: error)
            return nil
        }
    }

    func updateCompound(id: UUID, request: UpdateCompoundRequest) async -> Compound? {
        let generation = sessionGeneration
        guard let protocolID = owningProtocolID(forCompoundID: id),
              beginMutation(for: protocolID) else {
            return nil
        }
        defer {
            if generation == sessionGeneration {
                endMutation(for: protocolID)
            }
        }

        errorMessage = nil
        do {
            let updated: Compound = try await api.execute(.updateCompound(id: id, request))
            guard generation == sessionGeneration else { return nil }
            replaceCompound(updated)
            revision += 1
            return updated
        } catch {
            guard generation == sessionGeneration else { return nil }
            errorMessage = message(for: error)
            return nil
        }
    }

    func removeCompound(id: UUID, protocolID: UUID) async -> Bool {
        let generation = sessionGeneration
        guard beginMutation(for: protocolID) else { return false }
        defer {
            if generation == sessionGeneration {
                endMutation(for: protocolID)
            }
        }

        errorMessage = nil
        do {
            try await api.executeVoid(.removeCompound(id: id))
            guard generation == sessionGeneration else { return false }
            updateProtocol(id: protocolID) { protocolValue in
                protocolValue.replacingCompounds(
                    protocolValue.compounds.filter { $0.id != id }
                )
            }
            revision += 1
            return true
        } catch {
            guard generation == sessionGeneration else { return false }
            errorMessage = message(for: error)
            return false
        }
    }

    func activate(id: UUID) async -> Bool {
        let generation = sessionGeneration
        guard beginMutation(for: id) else { return false }
        defer {
            if generation == sessionGeneration {
                endMutation(for: id)
            }
        }

        errorMessage = nil
        do {
            let activated: ProtocolModel = try await api.execute(.activateProtocol(id: id))
            guard generation == sessionGeneration else { return false }
            reconcile(activated, deactivateOthersIfActive: activated.isActive)
            revision += 1
            return true
        } catch {
            guard generation == sessionGeneration else { return false }
            errorMessage = message(for: error)
            return false
        }
    }

    /// Completes a pending starter protocol's setup and activates it. The endpoint
    /// returns no body, so the store refetches the protocol to reconcile full state.
    ///
    /// These are two distinct failure domains: if the POST fails, activation never
    /// happened and this is a real failure. If the POST succeeds, activation is a
    /// success regardless of the follow-up GET — the protocol *is* active
    /// server-side even when the refetch hits a transient error, so this method
    /// reports success (independent of any local model lookup; the store may not
    /// be loaded when arriving from the Dashboard), reconciles what it can
    /// locally, and does not surface a user-facing error, so a retry doesn't
    /// re-POST an already-active protocol.
    func activateStarter(id: UUID, request: StarterProtocolActivationRequest) async -> Bool {
        let generation = sessionGeneration
        guard beginMutation(for: id) else { return false }
        defer {
            if generation == sessionGeneration {
                endMutation(for: id)
            }
        }

        errorMessage = nil
        do {
            try await api.executeVoid(.activateStarterProtocol(id: id, request))
            guard generation == sessionGeneration else { return false }
        } catch {
            guard generation == sessionGeneration else { return false }
            errorMessage = message(for: error)
            return false
        }

        do {
            let activated: ProtocolModel = try await api.execute(.getProtocol(id: id))
            guard generation == sessionGeneration else { return false }
            reconcile(activated, deactivateOthersIfActive: activated.isActive)
        } catch {
            guard generation == sessionGeneration else { return false }
            applyOptimisticActivation(id: id)
        }
        guard generation == sessionGeneration else { return false }
        revision += 1
        return true
    }

    func deactivate(id: UUID) async -> Bool {
        let generation = sessionGeneration
        guard beginMutation(for: id) else { return false }
        defer {
            if generation == sessionGeneration {
                endMutation(for: id)
            }
        }

        errorMessage = nil
        do {
            let deactivated: ProtocolModel = try await api.execute(.deactivateProtocol(id: id))
            guard generation == sessionGeneration else { return false }
            reconcile(deactivated)
            revision += 1
            return true
        } catch {
            guard generation == sessionGeneration else { return false }
            errorMessage = message(for: error)
            return false
        }
    }

    func deleteSelected() async -> Bool {
        guard let selectedProtocol else { return false }
        let id = selectedProtocol.id
        let generation = sessionGeneration

        guard beginMutation(for: id) else { return false }
        defer {
            if generation == sessionGeneration {
                endMutation(for: id)
            }
        }

        errorMessage = nil
        do {
            try await api.executeVoid(.deleteProtocol(id: id))
            guard generation == sessionGeneration else { return false }
            protocols.removeAll { $0.id == id }
            self.selectedProtocol = nil
            revision += 1
            return true
        } catch {
            guard generation == sessionGeneration else { return false }
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
        let generation = sessionGeneration
        errorMessage = nil

        do {
            let logged: DoseLog = try await api.execute(.createDoseLog(request))
            guard generation == sessionGeneration else { return nil }
            doseLogs.insert(logged, at: 0)
            doseLogs.sort { $0.administeredAt > $1.administeredAt }
            revision += 1
            return logged
        } catch {
            guard generation == sessionGeneration else { return nil }
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

    /// Best-effort local reconciliation for when a mutation succeeded server-side but
    /// its confirming refetch failed: marks `id` active and deactivates any other
    /// locally-active protocol, mirroring what `reconcile(deactivateOthersIfActive:)`
    /// would do with a fresh server value.
    private func applyOptimisticActivation(id: UUID) {
        protocols = protocols.map { existing in
            if existing.id == id {
                return existing.activated()
            }
            return existing.isActive ? existing.deactivated() : existing
        }

        if let selectedProtocol {
            if selectedProtocol.id == id {
                self.selectedProtocol = selectedProtocol.activated()
            } else if selectedProtocol.isActive {
                self.selectedProtocol = selectedProtocol.deactivated()
            }
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

    func activated() -> ProtocolModel {
        ProtocolModel(
            id: id,
            name: name,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            isActive: true,
            setupStatus: "active",
            isStarter: isStarter,
            compounds: compounds
        )
    }
}
