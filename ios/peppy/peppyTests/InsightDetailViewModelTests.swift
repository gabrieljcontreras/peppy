import Foundation
import XCTest
@testable import peppy

@MainActor
final class InsightDetailViewModelTests: XCTestCase {

    func testOnAppearMarksReadExactlyOnce() async {
        let insight = Insight.fixture(id: UUID())
        let (model, api, _) = await makeModel(storeInsights: [insight], insightID: insight.id)

        await model.onAppear()
        await model.onAppear()

        let markReadCount = api.requestLog.filter {
            $0.requestID == Endpoint.markInsightRead(id: insight.id).requestID
        }.count
        XCTAssertEqual(markReadCount, 1)
    }

    func testOnAppearDoesNotFetchFallbackWhenInsightInStore() async {
        let insight = Insight.fixture(id: UUID())
        let (model, api, _) = await makeModel(storeInsights: [insight], insightID: insight.id)

        await model.onAppear()

        XCTAssertEqual(model.insight, insight)
        let fallbackFetches = api.requestLog.filter {
            $0.requestID == Endpoint.getInsight(id: insight.id).requestID
        }.count
        XCTAssertEqual(fallbackFetches, 0)
    }

    func testDeepLinkFallbackFetchWhenStoreEmpty() async {
        let insight = Insight.fixture(id: UUID())
        let (model, api, _) = await makeModel(storeInsights: nil, insightID: insight.id)
        api.setMockResponse(insight, for: .getInsight(id: insight.id))
        api.setMockResponse(insight, for: .markInsightRead(id: insight.id))

        await model.onAppear()

        XCTAssertEqual(model.insight, insight)
        let requestIDs = api.requestLog.map(\.requestID)
        XCTAssertTrue(requestIDs.contains(Endpoint.getInsight(id: insight.id).requestID))
        XCTAssertTrue(requestIDs.contains(Endpoint.markInsightRead(id: insight.id).requestID))
    }

    func testAcceptCallsActionEndpointAndFlipsDidCompleteAction() async {
        let insight = Insight.fixture(id: UUID())
        let (model, api, _) = await makeModel(storeInsights: [insight], insightID: insight.id)
        api.setMockResponse(insight, for: .insightAction(id: insight.id, action: "accept"))

        await model.accept()

        XCTAssertTrue(model.didCompleteAction)
        XCTAssertEqual(model.completedAction, "accept")
        XCTAssertFalse(model.isActing)
        XCTAssertEqual(
            api.requestLog.last?.requestID,
            Endpoint.insightAction(id: insight.id, action: "accept").requestID
        )
    }

    func testSnoozeCallsActionEndpointAndRemovesFromStore() async {
        let insight = Insight.fixture(id: UUID())
        let (model, api, store) = await makeModel(storeInsights: [insight], insightID: insight.id)
        api.setMockResponse(insight, for: .insightAction(id: insight.id, action: "snooze"))

        await model.snooze()

        XCTAssertTrue(model.didCompleteAction)
        XCTAssertEqual(model.completedAction, "snooze")
        XCTAssertEqual(store.insights, [])
        XCTAssertEqual(
            api.requestLog.last?.requestID,
            Endpoint.insightAction(id: insight.id, action: "snooze").requestID
        )
    }

    func testDismissCallsActionEndpointAndRemovesFromStore() async {
        let insight = Insight.fixture(id: UUID())
        let (model, api, store) = await makeModel(storeInsights: [insight], insightID: insight.id)
        api.setMockResponse(insight, for: .insightAction(id: insight.id, action: "dismiss"))

        await model.dismissInsight()

        XCTAssertTrue(model.didCompleteAction)
        XCTAssertEqual(model.completedAction, "dismiss")
        XCTAssertEqual(store.insights, [])
        XCTAssertEqual(
            api.requestLog.last?.requestID,
            Endpoint.insightAction(id: insight.id, action: "dismiss").requestID
        )
    }

    func testFailedActionLeavesDidCompleteActionFalseAndSetsStoreError() async {
        let insight = Insight.fixture(id: UUID())
        let (model, api, store) = await makeModel(storeInsights: [insight], insightID: insight.id)
        api.setMockError(.serverError, for: .insightAction(id: insight.id, action: "accept"))

        await model.accept()

        XCTAssertFalse(model.didCompleteAction)
        XCTAssertNil(model.completedAction)
        XCTAssertFalse(model.isActing)
        XCTAssertEqual(store.errorMessage, APIError.serverError.userMessage)
        XCTAssertEqual(store.insights, [insight])
    }

    // MARK: - Helpers

    /// storeInsights nil = store never loaded (deep-link scenario).
    private func makeModel(
        storeInsights: [Insight]?,
        insightID: UUID
    ) async -> (InsightDetailViewModel, MockAPIClient, InsightsStore) {
        let api = MockAPIClient()
        let store = InsightsStore(api: api)
        if let storeInsights {
            api.setMockResponse(
                storeInsights,
                for: Endpoint.getInsights(unreadOnly: nil, type: nil, severity: nil)
            )
            for insight in storeInsights {
                api.setMockResponse(insight, for: .markInsightRead(id: insight.id))
            }
            await store.loadInsights()
        }
        let model = InsightDetailViewModel(store: store, api: api, insightID: insightID)
        return (model, api, store)
    }
}
