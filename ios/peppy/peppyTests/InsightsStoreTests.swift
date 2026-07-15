import Foundation
import XCTest
@testable import peppy

@MainActor
final class InsightsStoreTests: XCTestCase {

    func testLoadInsightsPopulatesInsightsAndCountsOnlyUnread() async {
        let api = MockAPIClient()
        let unread = Insight.fixture(id: UUID())
        let read = Insight.fixture(id: UUID(), readAt: Date(timeIntervalSince1970: 1_700_000_000))
        api.setMockResponse([unread, read], for: insightsEndpoint)
        let store = InsightsStore(api: api)

        await store.loadInsights()

        XCTAssertEqual(store.insights, [unread, read])
        XCTAssertEqual(store.unreadCount, 1)
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.errorMessage)
    }

    func testSecondLoadDoesNotRequestAgainUnlessForced() async {
        let api = MockAPIClient()
        api.setMockResponse([Insight.fixture()], for: insightsEndpoint)
        let store = InsightsStore(api: api)

        await store.loadInsights()
        await store.loadInsights()

        XCTAssertEqual(api.requestLog.map(\.requestID), [insightsEndpoint.requestID])

        await store.loadInsights(force: true)

        XCTAssertEqual(api.requestLog.map(\.requestID), [
            insightsEndpoint.requestID,
            insightsEndpoint.requestID
        ])
    }

    func testConcurrentNonForcedLoadsShareInFlightRequest() async {
        let api = MockAPIClient()
        api.setMockResponse([Insight.fixture()], for: insightsEndpoint)
        let store = InsightsStore(api: api)
        let gate = InsightsRequestGate()
        let firstStarted = expectation(description: "first load is in flight")
        api.onRequest = { endpoint in
            if case .getInsights = endpoint {
                firstStarted.fulfill()
                await gate.wait()
            }
        }

        let firstLoad = Task { await store.loadInsights() }
        await fulfillment(of: [firstStarted], timeout: 2)
        let secondEntered = expectation(description: "second load entered store")
        let secondLoad = Task {
            secondEntered.fulfill()
            await store.loadInsights()
        }
        await fulfillment(of: [secondEntered], timeout: 2)
        await Task.yield()

        XCTAssertEqual(
            api.requestLog.filter { $0.requestID == insightsEndpoint.requestID }.count,
            1
        )

        await gate.open()
        await firstLoad.value
        await secondLoad.value
    }

    func testLoadWeeklySummaryStoresEnvelope() async {
        let api = MockAPIClient()
        let envelope = WeeklySummaryEnvelope(available: false, summary: nil)
        api.setMockResponse(envelope, for: .getWeeklySummary)
        let store = InsightsStore(api: api)

        await store.loadWeeklySummary()

        XCTAssertEqual(store.weekly, envelope)
        XCTAssertEqual(api.requestLog.map(\.requestID), [Endpoint.getWeeklySummary.requestID])
        XCTAssertNil(store.errorMessage)
    }

    func testMarkReadReplacesMatchingInsightFromMethodQualifiedResponse() async {
        let api = MockAPIClient()
        let unread = Insight.fixture(id: UUID())
        let read = Insight.fixture(
            id: unread.id,
            readAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        api.setMockResponse([unread], for: insightsEndpoint)
        api.setMockResponse(read, for: .markInsightRead(id: unread.id))
        let store = InsightsStore(api: api)
        await store.loadInsights()

        await store.markRead(unread.id)

        XCTAssertEqual(store.insights, [read])
        XCTAssertEqual(store.unreadCount, 0)
        XCTAssertEqual(
            api.requestLog.last?.requestID,
            Endpoint.markInsightRead(id: unread.id).requestID
        )
        XCTAssertNil(store.errorMessage)
    }

    func testStaleRefreshDoesNotUndoMarkRead() async {
        let api = MockAPIClient()
        let unread = Insight.fixture(id: UUID())
        let read = Insight.fixture(
            id: unread.id,
            readAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        api.setMockResponse([unread], for: insightsEndpoint)
        api.setMockResponse(read, for: .markInsightRead(id: unread.id))
        let store = InsightsStore(api: api)
        await store.loadInsights()
        let gate = InsightsRequestGate()
        let refreshStarted = expectation(description: "refresh is in flight")
        api.onRequest = { endpoint in
            if case .getInsights = endpoint {
                refreshStarted.fulfill()
                await gate.wait()
            }
        }

        let refresh = Task { await store.loadInsights(force: true) }
        await fulfillment(of: [refreshStarted], timeout: 2)
        await store.markRead(unread.id)
        XCTAssertEqual(store.insights, [read])

        await gate.open()
        await refresh.value

        XCTAssertEqual(store.insights, [read])
        XCTAssertFalse(store.isLoading)
    }

    func testDismissActionRemovesInsight() async {
        let api = MockAPIClient()
        let dismissedID = UUID()
        let dismissed = Insight.fixture(id: dismissedID)
        let retained = Insight.fixture(id: UUID())
        api.setMockResponse([dismissed, retained], for: insightsEndpoint)
        api.setMockResponse(dismissed, for: .insightAction(id: dismissedID, action: "dismiss"))
        let store = InsightsStore(api: api)
        await store.loadInsights()

        let succeeded = await store.act(dismissedID, action: "dismiss")

        XCTAssertTrue(succeeded)
        XCTAssertEqual(store.insights, [retained])
        XCTAssertEqual(
            api.requestLog.last?.requestID,
            Endpoint.insightAction(id: dismissedID, action: "dismiss").requestID
        )
        XCTAssertNil(store.errorMessage)
    }

    func testStaleRefreshDoesNotResurrectDismissedInsight() async {
        await assertStaleRefreshDoesNotUndoRemoval(action: "dismiss")
    }

    func testStaleRefreshDoesNotResurrectSnoozedInsight() async {
        await assertStaleRefreshDoesNotUndoRemoval(action: "snooze")
    }

    func testRefreshErrorKeepsPriorInsightsAndSetsMessage() async {
        let api = MockAPIClient()
        let existing = Insight.fixture()
        api.setMockResponse([existing], for: insightsEndpoint)
        let store = InsightsStore(api: api)
        await store.loadInsights()
        api.setMockError(.serverError, for: insightsEndpoint)

        await store.loadInsights(force: true)

        XCTAssertEqual(store.insights, [existing])
        XCTAssertEqual(store.errorMessage, APIError.serverError.userMessage)
        XCTAssertFalse(store.isLoading)
    }

    func testDependenciesProvideInsightsStore() {
        let dependencies = Dependencies.mock()

        XCTAssertNotNil(dependencies.insightsStore)
    }

    private var insightsEndpoint: Endpoint {
        .getInsights(unreadOnly: nil, type: nil, severity: nil)
    }

    private func assertStaleRefreshDoesNotUndoRemoval(
        action: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let api = MockAPIClient()
        let target = Insight.fixture(id: UUID())
        let retained = Insight.fixture(id: UUID())
        api.setMockResponse([target, retained], for: insightsEndpoint)
        api.setMockResponse(target, for: .insightAction(id: target.id, action: action))
        let store = InsightsStore(api: api)
        await store.loadInsights()
        let gate = InsightsRequestGate()
        let refreshStarted = expectation(description: "refresh is in flight")
        api.onRequest = { endpoint in
            if case .getInsights = endpoint {
                refreshStarted.fulfill()
                await gate.wait()
            }
        }

        let refresh = Task { await store.loadInsights(force: true) }
        await fulfillment(of: [refreshStarted], timeout: 2)
        let succeeded = await store.act(target.id, action: action)
        XCTAssertTrue(succeeded, file: file, line: line)
        XCTAssertEqual(store.insights, [retained], file: file, line: line)

        await gate.open()
        await refresh.value

        XCTAssertEqual(store.insights, [retained], file: file, line: line)
        XCTAssertFalse(store.isLoading, file: file, line: line)
    }
}

private actor InsightsRequestGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuations.append($0) }
    }

    func open() {
        isOpen = true
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }
}
