import Foundation
import Observation

struct DashboardState: Equatable {
    var isLoading = false
    var summary: DashboardSummary?
    var errorMessage: String?
    var showsProfileSyncRecovery = false
}

@MainActor
@Observable
final class DashboardViewModel {
    private let api: APIClientProtocol
    private let protocolStore: ProtocolStore?
    private let hasProfileAttachFailure: () -> Bool
    private var lastSeenProtocolRevision: Int

    var state = DashboardState()

    init(
        api: APIClientProtocol,
        protocolStore: ProtocolStore? = nil,
        hasProfileAttachFailure: @autoclosure @escaping () -> Bool
    ) {
        self.api = api
        self.protocolStore = protocolStore
        self.hasProfileAttachFailure = hasProfileAttachFailure
        self.lastSeenProtocolRevision = protocolStore?.revision ?? 0
    }

    /// Reloads only when the protocol store has reconciled a successful mutation
    /// since the last load; failed mutations leave `revision` untouched.
    func refreshIfProtocolStateChanged() async {
        guard let protocolStore,
              protocolStore.revision != lastSeenProtocolRevision else { return }
        await load()
    }

    func load() async {
        state.isLoading = true
        state.errorMessage = nil
        defer { state.isLoading = false }

        // Captured before the fetch so a mutation racing this load still bumps
        // past the recorded revision and triggers a follow-up refresh.
        lastSeenProtocolRevision = protocolStore?.revision ?? 0

        do {
            let summary: DashboardSummary = try await api.execute(.getDashboardSummary)
            state.summary = summary
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        } catch let error as APIError {
            state.errorMessage = error.userMessage
            state.summary = .mockMissingProfile
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        } catch {
            state.errorMessage = error.localizedDescription
            state.summary = .mockMissingProfile
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        }
    }
}
