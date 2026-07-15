import Foundation
import XCTest
@testable import peppy

@MainActor
final class InsightsListViewModelTests: XCTestCase {

    func testFilterAllShowsEveryInsight() async {
        let (model, _, insights) = await loadedModel()

        XCTAssertEqual(model.filter, .all)
        XCTAssertEqual(model.filtered, insights)
    }

    func testAnomaliesFilterShowsOnlyAnomalyType() async {
        let (model, _, insights) = await loadedModel()

        model.filter = .anomalies

        XCTAssertEqual(model.filtered, insights.filter { $0.type == "anomaly" })
        XCTAssertFalse(model.filtered.isEmpty)
    }

    func testEachFilterMapsToItsServerType() {
        XCTAssertNil(InsightTypeFilter.all.matchesType)
        XCTAssertEqual(InsightTypeFilter.trends.matchesType, "trend")
        XCTAssertEqual(InsightTypeFilter.anomalies.matchesType, "anomaly")
        XCTAssertEqual(InsightTypeFilter.suggestions.matchesType, "suggestion")
        XCTAssertEqual(InsightTypeFilter.milestones.matchesType, "milestone")
    }

    func testUnreadAndEarlierSectioning() async {
        let unread = Insight.fixture(id: UUID(), type: "trend")
        let earlier = Insight.fixture(
            id: UUID(),
            type: "trend",
            readAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let (model, _, _) = await loadedModel(insights: [unread, earlier])

        XCTAssertEqual(model.unread, [unread])
        XCTAssertEqual(model.earlier, [earlier])
    }

    func testSectioningRespectsActiveFilter() async {
        let unreadTrend = Insight.fixture(id: UUID(), type: "trend")
        let unreadAnomaly = Insight.fixture(id: UUID(), type: "anomaly")
        let (model, _, _) = await loadedModel(insights: [unreadTrend, unreadAnomaly])

        model.filter = .trends

        XCTAssertEqual(model.unread, [unreadTrend])
        XCTAssertEqual(model.earlier, [])
    }

    func testShowsSummaryCardFalseWhenEnvelopeUnavailable() async {
        let (model, _, _) = await loadedModel(
            weekly: WeeklySummaryEnvelope(available: false, summary: nil)
        )

        XCTAssertFalse(model.showsSummaryCard)
    }

    func testShowsSummaryCardTrueWhenEnvelopeAvailable() async {
        let (model, _, _) = await loadedModel(
            weekly: WeeklySummaryEnvelope(available: true, summary: nil)
        )

        XCTAssertTrue(model.showsSummaryCard)
    }

    func testOnAppearTriggersInsightsAndWeeklySummaryLoads() async {
        let (_, api, _) = await loadedModel()

        let requestIDs = api.requestLog.map(\.requestID)
        XCTAssertTrue(requestIDs.contains(insightsEndpoint.requestID))
        XCTAssertTrue(requestIDs.contains(Endpoint.getWeeklySummary.requestID))
    }

    func testRefreshForcesInsightsReload() async {
        let (model, api, _) = await loadedModel()
        let requestsAfterAppear = api.requestLog.filter {
            $0.requestID == insightsEndpoint.requestID
        }.count

        await model.refresh()

        let requestsAfterRefresh = api.requestLog.filter {
            $0.requestID == insightsEndpoint.requestID
        }.count
        XCTAssertEqual(requestsAfterRefresh, requestsAfterAppear + 1)
    }

    // MARK: - Helpers

    private var insightsEndpoint: Endpoint {
        .getInsights(unreadOnly: nil, type: nil, severity: nil)
    }

    private func loadedModel(
        insights: [Insight]? = nil,
        weekly: WeeklySummaryEnvelope = WeeklySummaryEnvelope(available: false, summary: nil)
    ) async -> (InsightsListViewModel, MockAPIClient, [Insight]) {
        let defaultInsights = [
            Insight.fixture(id: UUID(), type: "trend"),
            Insight.fixture(id: UUID(), type: "anomaly"),
            Insight.fixture(id: UUID(), type: "suggestion"),
            Insight.fixture(id: UUID(), type: "milestone")
        ]
        let loaded = insights ?? defaultInsights
        let api = MockAPIClient()
        api.setMockResponse(loaded, for: insightsEndpoint)
        api.setMockResponse(weekly, for: .getWeeklySummary)
        let store = InsightsStore(api: api)
        let model = InsightsListViewModel(store: store)

        await model.onAppear()

        return (model, api, loaded)
    }
}
