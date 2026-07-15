import Foundation
import XCTest
@testable import peppy

@MainActor
final class WeeklySummaryViewModelTests: XCTestCase {

    func testWeekRangeTextFormatsFromPayload() async {
        let (model, _, _) = await makeModel(payload: fixturePayload())

        XCTAssertEqual(model.weekRangeText, "Week of May 24 – May 30, 2026")
        XCTAssertEqual(model.weekRangeCaption, "May 24 – May 30")
    }

    func testWeekRangeTextEmptyWhenNoPayload() async {
        let (model, _, _) = await makeModel(payload: nil)

        XCTAssertEqual(model.weekRangeText, "")
    }

    func testHeroDeltaTextSignedOneDecimalNegative() async {
        let (model, _, _) = await makeModel(payload: fixturePayload(weightDeltaKg: -0.8))

        XCTAssertEqual(model.heroDeltaText, "-0.8 kg")
        XCTAssertTrue(model.heroTrendingDown)
    }

    func testHeroDeltaTextSignedPositive() async {
        let (model, _, _) = await makeModel(payload: fixturePayload(weightDeltaKg: 0.4))

        XCTAssertEqual(model.heroDeltaText, "+0.4 kg")
        XCTAssertFalse(model.heroTrendingDown)
    }

    func testHeroDeltaTextNilWhenDeltaMissing() async {
        let (model, _, _) = await makeModel(payload: fixturePayload(weightDeltaKg: nil))

        XCTAssertNil(model.heroDeltaText)
        XCTAssertFalse(model.heroTrendingDown)
    }

    func testChartPointsParseAndSortDateStrings() async {
        let series = [
            WeeklyWeightPoint(date: "2026-05-26", weightKg: 82.9),
            WeeklyWeightPoint(date: "2026-05-24", weightKg: 83.2),
            WeeklyWeightPoint(date: "not-a-date", weightKg: 99.9)
        ]
        let (model, _, _) = await makeModel(payload: fixturePayload(weightSeries: series))

        XCTAssertEqual(model.chartPoints.count, 2)
        XCTAssertEqual(model.chartPoints.first?.weightKg, 83.2)
        XCTAssertEqual(model.chartPoints.last?.weightKg, 82.9)
        XCTAssertLessThan(model.chartPoints[0].date, model.chartPoints[1].date)
    }

    func testHasNarrativeReflectsPayload() async {
        let (withNarrative, _, _) = await makeModel(payload: fixturePayload(narrative: "Great week."))
        let (withoutNarrative, _, _) = await makeModel(payload: fixturePayload(narrative: nil))

        XCTAssertTrue(withNarrative.hasNarrative)
        XCTAssertFalse(withoutNarrative.hasNarrative)
    }

    func testPayloadNilWhenEnvelopeUnavailable() async {
        let api = MockAPIClient()
        api.setMockResponse(
            WeeklySummaryEnvelope(available: false, summary: nil),
            for: .getWeeklySummary
        )
        let store = InsightsStore(api: api)
        let model = WeeklySummaryViewModel(store: store)

        await model.onAppear()

        XCTAssertNil(model.payload)
        XCTAssertTrue(model.hasLoaded)
    }

    func testOnAppearLoadsOnlyWhenWeeklyNil() async {
        let (model, api, _) = await makeModel(payload: fixturePayload())
        let requestsAfterSetup = weeklyRequestCount(api)

        await model.onAppear()

        XCTAssertEqual(weeklyRequestCount(api), requestsAfterSetup)

        let freshAPI = MockAPIClient()
        freshAPI.setMockResponse(
            WeeklySummaryEnvelope(available: true, summary: fixturePayload()),
            for: .getWeeklySummary
        )
        let freshModel = WeeklySummaryViewModel(store: InsightsStore(api: freshAPI))

        await freshModel.onAppear()

        XCTAssertEqual(weeklyRequestCount(freshAPI), 1)
        XCTAssertNotNil(freshModel.payload)
    }

    // MARK: - Helpers

    private func weeklyRequestCount(_ api: MockAPIClient) -> Int {
        api.requestLog.filter { $0.requestID == Endpoint.getWeeklySummary.requestID }.count
    }

    private func makeModel(
        payload: WeeklySummaryPayload?
    ) async -> (WeeklySummaryViewModel, MockAPIClient, InsightsStore) {
        let api = MockAPIClient()
        let store = InsightsStore(api: api)
        if let payload {
            api.setMockResponse(
                WeeklySummaryEnvelope(available: true, summary: payload),
                for: .getWeeklySummary
            )
            await store.loadWeeklySummary()
        }
        return (WeeklySummaryViewModel(store: store), api, store)
    }

    private func fixturePayload(
        weekStart: String = "2026-05-24",
        weekEnd: String = "2026-05-30",
        weightDeltaKg: Double? = -0.8,
        weightSeries: [WeeklyWeightPoint] = [
            WeeklyWeightPoint(date: "2026-05-24", weightKg: 83.2),
            WeeklyWeightPoint(date: "2026-05-30", weightKg: 82.4)
        ],
        narrative: String? = "Great progress. You're trending in the right direction."
    ) -> WeeklySummaryPayload {
        WeeklySummaryPayload(
            weekStart: weekStart,
            weekEnd: weekEnd,
            hero: WeeklySummaryHero(
                weightDeltaKg: weightDeltaKg,
                weightFromKg: 83.2,
                weightToKg: 82.4
            ),
            weightSeries: weightSeries,
            whatChanged: [
                WeeklySummaryMetric(
                    key: "sleep_quality",
                    label: "Sleep",
                    value: "+38 minutes",
                    detail: "7h 23m vs 6h 45m",
                    positive: true
                ),
                WeeklySummaryMetric(
                    key: "checkins",
                    label: "Check-ins",
                    value: "6 of 7 days",
                    detail: "Consistent logging",
                    positive: nil
                )
            ],
            whatToWatch: [
                WeeklyWatchItem(
                    title: "Nausea appears within 24 hours after dose day",
                    detail: "Occurred 3 of 4 times this week"
                )
            ],
            providerQuestions: ["Is the nausea pattern expected with this protocol?"],
            narrative: narrative
        )
    }
}
