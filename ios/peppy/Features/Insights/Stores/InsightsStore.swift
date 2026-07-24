import Foundation
import Observation

@MainActor
@Observable
final class InsightsStore {
    private let api: APIClientProtocol

    private(set) var insights: [Insight] = []
    private(set) var weekly: WeeklySummaryEnvelope?
    private(set) var isLoading = false
    var errorMessage: String?

    private var hasLoadedInsights = false
    private var insightsLoadToken = 0
    private var weeklyLoadToken = 0

    var unreadCount: Int {
        insights.filter(\.isUnread).count
    }

    init(api: APIClientProtocol) {
        self.api = api
    }

    func loadInsights(force: Bool = false) async {
        guard force || (!hasLoadedInsights && !isLoading) else { return }

        insightsLoadToken += 1
        let token = insightsLoadToken
        isLoading = true
        errorMessage = nil

        do {
            let loaded: [Insight] = try await api.execute(
                .getInsights(unreadOnly: nil, type: nil, severity: nil)
            )
            guard token == insightsLoadToken else { return }
            insights = loaded
            hasLoadedInsights = true
            isLoading = false
        } catch {
            guard token == insightsLoadToken else { return }
            errorMessage = message(for: error)
            isLoading = false
        }
    }

    func loadWeeklySummary() async {
        weeklyLoadToken += 1
        let token = weeklyLoadToken
        errorMessage = nil

        do {
            let loaded: WeeklySummaryEnvelope = try await api.execute(.getWeeklySummary)
            guard token == weeklyLoadToken else { return }
            weekly = loaded
        } catch {
            guard token == weeklyLoadToken else { return }
            errorMessage = message(for: error)
        }
    }

    func markRead(_ id: UUID) async {
        errorMessage = nil

        do {
            let updated: Insight = try await api.execute(.markInsightRead(id: id))
            invalidateInsightsLoad()
            replace(updated)
        } catch {
            errorMessage = message(for: error)
        }
    }

    func resetSession() {
        insightsLoadToken += 1
        weeklyLoadToken += 1
        insights = []
        weekly = nil
        isLoading = false
        errorMessage = nil
        hasLoadedInsights = false
    }

    @discardableResult
    func act(_ id: UUID, action: String) async -> Bool {
        errorMessage = nil

        do {
            let updated: Insight = try await api.execute(
                .insightAction(id: id, action: action)
            )
            invalidateInsightsLoad()

            if action == "dismiss" || action == "snooze" {
                insights.removeAll { $0.id == id }
            } else {
                replace(updated)
            }
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    private func replace(_ updated: Insight) {
        guard let index = insights.firstIndex(where: { $0.id == updated.id }) else {
            return
        }
        insights[index] = updated
    }

    private func invalidateInsightsLoad() {
        guard isLoading else { return }
        insightsLoadToken += 1
        isLoading = false
    }

    private func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.userMessage
        }
        return error.localizedDescription
    }
}

extension Insight {
    static func fixture(
        id: UUID = UUID(),
        type: String = "trend",
        severity: String = "info",
        title: String = "Weight trending down",
        description: String = "Your average weekly weight change is -0.4 kg.",
        explanation: String = "Computed from 5 weight check-ins.",
        confidence: Double = 0.83,
        createdAt: Date = Date(),
        readAt: Date? = nil,
        supportingData: [InsightSupportingItem]? = [
            .init(
                iconKey: "weight",
                label: "Weight trend",
                sublabel: "Compared to prior 2 weeks",
                value: "-0.4 kg / week"
            )
        ]
    ) -> Insight {
        Insight(
            id: id,
            type: type,
            severity: severity,
            title: title,
            description: description,
            explanation: explanation,
            confidence: confidence,
            createdAt: createdAt,
            readAt: readAt,
            supportingData: supportingData
        )
    }
}
