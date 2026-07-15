import Foundation
import Observation

@MainActor
@Observable
final class InsightDetailViewModel {
    private let store: InsightsStore
    private let api: APIClientProtocol
    let insightID: UUID

    /// Fetched via .getInsight when the store doesn't hold the insight (deep link).
    private(set) var loadedFallback: Insight?
    private(set) var isActing = false
    private(set) var completedAction: String?
    var didCompleteAction = false // view pops when this flips
    private var hasMarkedRead = false

    var insight: Insight? {
        store.insights.first { $0.id == insightID } ?? loadedFallback
    }

    var completedActionMessage: String? {
        switch completedAction {
        case "snooze": return "Insight snoozed"
        case "dismiss": return "Insight dismissed"
        case "accept": return "Marked as helpful"
        default: return nil
        }
    }

    init(store: InsightsStore, api: APIClientProtocol, insightID: UUID) {
        self.store = store
        self.api = api
        self.insightID = insightID
    }

    func onAppear() async {
        if insight == nil {
            do {
                loadedFallback = try await api.execute(.getInsight(id: insightID))
            } catch {
                store.errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
            }
        }
        guard !hasMarkedRead else { return }
        hasMarkedRead = true
        await store.markRead(insightID)
    }

    func snooze() async {
        await act("snooze")
    }

    func dismissInsight() async {
        await act("dismiss")
    }

    func accept() async {
        await act("accept")
    }

    private func act(_ action: String) async {
        guard !isActing else { return }
        isActing = true
        let success = await store.act(insightID, action: action)
        isActing = false
        if success {
            completedAction = action
            didCompleteAction = true
        }
    }
}
