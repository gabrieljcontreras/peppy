import XCTest
@testable import peppy

final class InsightAPIModelsTests: XCTestCase {
    func testDecodesBackendInsightPayloadWithSupportingDataAndNullableFields() throws {
        let data = Data(
            #"""
            {
              "id": "11111111-2222-3333-4444-555555555555",
              "type": "trend",
              "severity": "warning",
              "title": "Energy dips after dose day",
              "description": "Your logged energy was lower after recent doses.",
              "explanation": "Peppy compared dose-day and non-dose-day check-ins.",
              "confidence": 0.875,
              "created_at": "2026-07-15T14:05:06.123456Z",
              "read_at": "2026-07-15T15:05:06.000000Z",
              "dismissed_at": null,
              "snoozed_until": null,
              "action_taken": "accept",
              "action_notes": null,
              "supporting_data": [
                {
                  "icon_key": "calendar",
                  "label": "Dose timing",
                  "sublabel": null,
                  "value": "3 of 4 dose windows"
                },
                {
                  "icon_key": "bolt",
                  "label": "Average energy",
                  "sublabel": "Dose day + next day",
                  "value": "1.8 points lower"
                }
              ]
            }
            """#.utf8
        )

        let insight = try makeDecoder().decode(Insight.self, from: data)

        XCTAssertEqual(insight.id, UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        XCTAssertEqual(insight.type, "trend")
        XCTAssertEqual(insight.severity, "warning")
        XCTAssertEqual(insight.title, "Energy dips after dose day")
        XCTAssertEqual(insight.description, "Your logged energy was lower after recent doses.")
        XCTAssertEqual(insight.explanation, "Peppy compared dose-day and non-dose-day check-ins.")
        XCTAssertEqual(insight.confidence, 0.875, accuracy: 0.0001)
        XCTAssertNotNil(insight.createdAt)
        XCTAssertNotNil(insight.readAt)
        XCTAssertNil(insight.dismissedAt)
        XCTAssertNil(insight.snoozedUntil)
        XCTAssertEqual(insight.actionTaken, "accept")
        XCTAssertNil(insight.actionNotes)
        XCTAssertEqual(
            insight.supportingData,
            [
                InsightSupportingItem(
                    iconKey: "calendar",
                    label: "Dose timing",
                    sublabel: nil,
                    value: "3 of 4 dose windows"
                ),
                InsightSupportingItem(
                    iconKey: "bolt",
                    label: "Average energy",
                    sublabel: "Dose day + next day",
                    value: "1.8 points lower"
                )
            ]
        )
        XCTAssertFalse(insight.isUnread)
    }

    func testDecodesAvailableWeeklySummaryEnvelope() throws {
        let data = Data(
            #"""
            {
              "available": true,
              "summary": {
                "week_start": "2026-07-06",
                "week_end": "2026-07-12",
                "hero": {
                  "weight_delta_kg": -2.5,
                  "weight_from_kg": 81.0,
                  "weight_to_kg": 78.5
                },
                "weight_series": [
                  { "date": "2026-07-06", "weight_kg": 80.0 },
                  { "date": "2026-07-12", "weight_kg": 77.0 }
                ],
                "what_changed": [
                  {
                    "key": "sleep_quality",
                    "label": "Sleep quality",
                    "value": "+1.0 pts",
                    "detail": "7.0 vs 6.0 prior week",
                    "positive": true
                  },
                  {
                    "key": "checkins",
                    "label": "Check-ins",
                    "value": "4",
                    "detail": null,
                    "positive": null
                  }
                ],
                "what_to_watch": [
                  {
                    "title": "Energy after dose day",
                    "detail": "Keep logging how you feel."
                  }
                ],
                "provider_questions": ["Is this weekly pattern expected?"],
                "narrative": "Your logged trend moved in a positive direction this week."
              }
            }
            """#.utf8
        )

        let envelope = try makeDecoder().decode(WeeklySummaryEnvelope.self, from: data)

        XCTAssertTrue(envelope.available)
        let summary = try XCTUnwrap(envelope.summary)
        XCTAssertEqual(summary.weekStart, "2026-07-06")
        XCTAssertEqual(summary.weekEnd, "2026-07-12")
        XCTAssertEqual(summary.hero.weightDeltaKg, -2.5)
        XCTAssertEqual(summary.hero.weightFromKg, 81.0)
        XCTAssertEqual(summary.hero.weightToKg, 78.5)
        XCTAssertEqual(summary.weightSeries.first?.date, "2026-07-06")
        XCTAssertEqual(summary.weightSeries.first?.weightKg, 80.0)
        XCTAssertEqual(summary.whatChanged.map(\.id), ["sleep_quality", "checkins"])
        XCTAssertEqual(summary.whatChanged.first?.positive, true)
        XCTAssertNil(summary.whatChanged.last?.detail)
        XCTAssertNil(summary.whatChanged.last?.positive)
        XCTAssertEqual(summary.whatToWatch.first?.title, "Energy after dose day")
        XCTAssertEqual(summary.providerQuestions, ["Is this weekly pattern expected?"])
        XCTAssertEqual(
            summary.narrative,
            "Your logged trend moved in a positive direction this week."
        )
    }

    func testDecodesUnavailableWeeklySummaryEnvelopeWithNullSummary() throws {
        let data = Data(#"{"available":false,"summary":null}"#.utf8)

        let envelope = try makeDecoder().decode(WeeklySummaryEnvelope.self, from: data)

        XCTAssertFalse(envelope.available)
        XCTAssertNil(envelope.summary)
    }

    func testWeeklySummaryEndpointIsAuthenticatedGetWithoutPayload() {
        let endpoint = Endpoint.getWeeklySummary

        XCTAssertEqual(endpoint.path, "/insights/summary/weekly")
        XCTAssertEqual(endpoint.method.rawValue, "GET")
        XCTAssertNil(endpoint.body)
        XCTAssertNil(endpoint.queryItems)
        XCTAssertTrue(endpoint.requiresAuth)
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
