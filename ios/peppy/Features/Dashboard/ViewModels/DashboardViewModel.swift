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
    private let hasProfileAttachFailure: () -> Bool

    var state = DashboardState()

    init(api: APIClientProtocol, hasProfileAttachFailure: @autoclosure @escaping () -> Bool) {
        self.api = api
        self.hasProfileAttachFailure = hasProfileAttachFailure
    }

    func load() async {
        state.isLoading = true
        state.errorMessage = nil
        defer { state.isLoading = false }

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
