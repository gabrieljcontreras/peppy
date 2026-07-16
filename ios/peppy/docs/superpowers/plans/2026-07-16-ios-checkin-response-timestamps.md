# Peppy iOS Check-in Response Timestamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a successful check-in POST decode cleanly on the first attempt so the form completes normally instead of reporting an error after the backend has already saved the row.

**Architecture:** Keep the backend contract, global `APIClient` decoder, check-in form, and duplicate protection unchanged. Add a private timestamp decoder to the iOS `Checkin` response model that accepts timezone-aware API timestamps and timezone-less SQLite timestamps for both `created_at` and `updated_at`, interpreting timezone-less values as UTC.

**Tech Stack:** Swift 5, Foundation `JSONDecoder`, `ISO8601DateFormatter`, XCTest, Xcode 26.6, iOS 17 minimum deployment target

## Global Constraints

- Limit production changes to the iOS `Checkin` response model.
- Add no backend changes, global API date-decoder changes, form changes, or new dependencies.
- Preserve the existing date-only decoding for the check-in `date` field.
- Accept timestamps with a timezone, with or without fractional seconds.
- Accept SQLite-style timestamps without a timezone, with or without fractional seconds, and interpret them as UTC.
- Preserve `nil` for missing or `null` `created_at` and `updated_at` fields.
- Continue to reject malformed non-null timestamps instead of hiding bad server data.
- Preserve genuine HTTP, authorization, validation, and duplicate-submission errors.
- Follow test-driven development: observe the SQLite regression test fail before editing production code.

---

### Task 1: Decode Check-in Response Timestamps Across Local and Production Formats

**Files:**
- Modify: `ios/peppy/peppyTests/CheckinViewModelTests.swift:5-110`
- Modify: `ios/peppy/Core/Network/APIModels.swift:561-590`

**Interfaces:**
- Consumes: `Checkin.init(from:)`, `JSONDecoder.dateDecodingStrategy = .iso8601`, the `created_at` and `updated_at` JSON keys, and the existing optional `Checkin.createdAt` and `Checkin.updatedAt` properties.
- Produces: `Checkin.decodeTimestampIfPresent(forKey:from:) -> Date?` and `Checkin.timestamp(from:) -> Date?`, both private implementation details of the `Checkin` model.

- [ ] **Step 1: Add response-decoding regression and compatibility tests**

In `CheckinViewModelTests.swift`, add these methods inside `CheckinViewModelTests`, immediately after `testSaveRequiresAtLeastOneMetricSymptomOrNote()` and before the class's closing brace:

```swift
func testCheckinResponseDecodesSQLiteTimestampsAsUTC() throws {
    let checkin = try decodeCheckin(
        createdAt: "2026-07-16T14:25:31.123456",
        updatedAt: "2026-07-16T14:26:32"
    )

    XCTAssertEqual(
        try XCTUnwrap(checkin.createdAt).timeIntervalSince1970,
        1_784_211_931.123,
        accuracy: 0.001
    )
    XCTAssertEqual(
        try XCTUnwrap(checkin.updatedAt).timeIntervalSince1970,
        1_784_211_992,
        accuracy: 0.001
    )
}

func testCheckinResponseDecodesTimezoneAwareTimestamps() throws {
    let checkin = try decodeCheckin(
        createdAt: "2026-07-16T10:25:31.123456-04:00",
        updatedAt: "2026-07-16T14:26:32Z"
    )

    XCTAssertEqual(
        try XCTUnwrap(checkin.createdAt).timeIntervalSince1970,
        1_784_211_931.123,
        accuracy: 0.001
    )
    XCTAssertEqual(
        try XCTUnwrap(checkin.updatedAt).timeIntervalSince1970,
        1_784_211_992,
        accuracy: 0.001
    )
}

func testCheckinResponsePreservesNullTimestamps() throws {
    let checkin = try decodeCheckin(
        createdAt: NSNull(),
        updatedAt: NSNull()
    )

    XCTAssertNil(checkin.createdAt)
    XCTAssertNil(checkin.updatedAt)
}

func testCheckinResponsePreservesMissingTimestamps() throws {
    let checkin = try decodeCheckin()

    XCTAssertNil(checkin.createdAt)
    XCTAssertNil(checkin.updatedAt)
}

func testCheckinResponseRejectsMalformedTimestamp() throws {
    XCTAssertThrowsError(
        try decodeCheckin(
            createdAt: "not-a-timestamp",
            updatedAt: "2026-07-16T14:26:32Z"
        )
    ) { error in
        guard case DecodingError.dataCorrupted = error else {
            return XCTFail("Expected dataCorrupted, got \(error)")
        }
    }
}

private func decodeCheckin(
    createdAt: Any? = nil,
    updatedAt: Any? = nil
) throws -> Checkin {
    var response: [String: Any] = [
        "id": "11111111-1111-1111-1111-111111111111",
        "user_id": "22222222-2222-2222-2222-222222222222",
        "date": "2026-07-16",
        "weight_kg": 74.8,
        "energy_level": 7,
        "sleep_quality": 6,
        "appetite_level": 5,
        "mood": 8,
        "nausea": 1,
        "injection_site_reaction": 0,
        "fatigue": 2,
        "headache": 0,
        "gi_issues": 1,
        "notes": "Felt steady after morning dose."
    ]

    if let createdAt {
        response["created_at"] = createdAt
    }
    if let updatedAt {
        response["updated_at"] = updatedAt
    }

    let data = try JSONSerialization.data(withJSONObject: response)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Checkin.self, from: data)
}
```

The fixture deliberately includes a complete check-in body so the tests exercise the same model shape returned by `POST /checkins`. The first test covers timezone-less SQLite values for both fields and uses one fractional and one whole-second timestamp. The second covers timezone-aware values with and without fractional seconds. The remaining tests preserve optional semantics and strict malformed-data handling.

- [ ] **Step 2: Run the focused tests and verify the SQLite regression fails**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:peppyTests/CheckinViewModelTests \
  test
```

Expected: `** TEST FAILED **`. `testCheckinResponseDecodesSQLiteTimestampsAsUTC` fails with `DecodingError.dataCorrupted` because the current `Checkin` model delegates timezone-less timestamps to the strict `.iso8601` date strategy. The timezone-aware, `null`, missing, and malformed-input characterization tests remain green.

- [ ] **Step 3: Add the model-local tolerant timestamp decoder**

In `APIModels.swift`, replace the final two assignments in `Checkin.init(from:)`:

```swift
createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
```

with:

```swift
createdAt = try Self.decodeTimestampIfPresent(forKey: .createdAt, from: container)
updatedAt = try Self.decodeTimestampIfPresent(forKey: .updatedAt, from: container)
```

Then add the following private helpers inside `Checkin`, immediately before `dateOnlyFormatter`:

```swift
private static func decodeTimestampIfPresent(
    forKey key: CodingKeys,
    from container: KeyedDecodingContainer<CodingKeys>
) throws -> Date? {
    guard container.contains(key), try !container.decodeNil(forKey: key) else {
        return nil
    }

    let raw = try container.decode(String.self, forKey: key)
    guard let parsed = timestamp(from: raw) else {
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Expected ISO-8601 timestamp with or without a timezone."
        )
    }
    return parsed
}

private static func timestamp(from raw: String) -> Date? {
    timestampFormatter.date(from: raw)
        ?? fractionalTimestampFormatter.date(from: raw)
        ?? timestampFormatter.date(from: raw + "Z")
        ?? fractionalTimestampFormatter.date(from: raw + "Z")
}

private static let timestampFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

private static let fractionalTimestampFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()
```

The first two parser attempts preserve valid timezone-aware timestamps. Appending `Z` only in the fallback path gives timezone-less SQLite values an explicit UTC timezone. A present but unsupported string raises `DecodingError.dataCorrupted`; missing and `null` values return `nil`.

- [ ] **Step 4: Re-run the focused check-in tests**

Run the same focused command from Step 2.

Expected: `** TEST SUCCEEDED **` with all existing request/save tests and all five response-decoding tests passing. In particular, both `createdAt` and `updatedAt` match the same UTC instants for SQLite-style and timezone-aware inputs.

- [ ] **Step 5: Run the complete iOS test suite**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  test
```

Expected: `** TEST SUCCEEDED **` with zero failing tests. This confirms the model-local parser does not change protocol, dashboard, insight, authentication, or other API-model behavior.

- [ ] **Step 6: Build the Debug app for a generic iOS Simulator**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/peppy/peppy.xcodeproj \
  -scheme peppy \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected: `** BUILD SUCCEEDED **` with no Swift compilation errors.

- [ ] **Step 7: Review and commit the focused fix**

Run:

```bash
git diff --check
git diff -- ios/peppy/Core/Network/APIModels.swift ios/peppy/peppyTests/CheckinViewModelTests.swift
```

Confirm that production changes are limited to `Checkin` timestamp decoding and that tests cover both timestamps, all supported timestamp shapes, optional fields, and malformed input. Then commit:

```bash
git add ios/peppy/Core/Network/APIModels.swift ios/peppy/peppyTests/CheckinViewModelTests.swift
git commit -m "fix: decode check-in response timestamps"
```
