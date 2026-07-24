import Foundation
import Observation

@MainActor
@Observable
final class InsightsListViewModel {
    private let store: InsightsStore

    var filter: InsightTypeFilter = .all

    var filtered: [Insight] {
        guard let type = filter.matchesType else { return store.insights }
        return store.insights.filter { $0.type == type }
    }

    var unread: [Insight] {
        filtered.filter(\.isUnread)
    }

    var earlier: [Insight] {
        filtered.filter { !$0.isUnread }
    }

    var showsSummaryCard: Bool {
        store.weekly?.available == true
    }

    var showsLearningState: Bool {
        store.insights.isEmpty && !store.isLoading
    }

    init(store: InsightsStore) {
        self.store = store
    }

    func onAppear() async {
        async let insights: Void = store.loadInsights()
        async let weekly: Void = store.loadWeeklySummary()
        _ = await (insights, weekly)
    }

    func refresh() async {
        async let insights: Void = store.loadInsights(force: true)
        async let weekly: Void = store.loadWeeklySummary()
        _ = await (insights, weekly)
    }
}
