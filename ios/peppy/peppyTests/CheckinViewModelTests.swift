import XCTest
@testable import peppy

@MainActor
final class CheckinViewModelTests: XCTestCase {
    func testCheckinRequestUsesBackendFieldNames() {
        let date = Date(timeIntervalSince1970: 1_788_000_000)

        let request = CreateCheckinRequest(
            date: date,
            weightKg: 74.8,
            energyLevel: 7,
            sleepQuality: 6,
            appetiteLevel: 5,
            mood: 8,
            nausea: 1,
            injectionSiteReaction: 0,
            fatigue: 2,
            headache: 0,
            giIssues: 3,
            notes: "Felt steady after morning dose."
        )

        XCTAssertEqual(request.date, date)
        XCTAssertEqual(request.weightKg, 74.8)
        XCTAssertEqual(request.energyLevel, 7)
        XCTAssertEqual(request.sleepQuality, 6)
        XCTAssertEqual(request.appetiteLevel, 5)
        XCTAssertEqual(request.mood, 8)
        XCTAssertEqual(request.nausea, 1)
        XCTAssertEqual(request.injectionSiteReaction, 0)
        XCTAssertEqual(request.fatigue, 2)
        XCTAssertEqual(request.headache, 0)
        XCTAssertEqual(request.giIssues, 3)
        XCTAssertEqual(request.notes, "Felt steady after morning dose.")
    }

    func testCheckinRequestEncodesBackendJSONShape() throws {
        let encoder = JSONEncoder()
        let date = Date(timeIntervalSince1970: 1_788_000_000)
        let request = CreateCheckinRequest(
            date: date,
            weightKg: 74.8,
            energyLevel: 7,
            sleepQuality: nil,
            appetiteLevel: nil,
            mood: 8,
            nausea: 1,
            injectionSiteReaction: nil,
            fatigue: nil,
            headache: nil,
            giIssues: nil,
            notes: nil
        )

        let data = try encoder.encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["date"] as? String, "2026-08-29")
        XCTAssertEqual(json["weight_kg"] as? Double, 74.8)
        XCTAssertEqual(json["energy_level"] as? Int, 7)
        XCTAssertEqual(json["mood"] as? Int, 8)
        XCTAssertEqual(json["nausea"] as? Int, 1)
        XCTAssertNil(json["sleep_quality"])
        XCTAssertNil(json["symptoms"])
        XCTAssertNil(json["weight"])
    }

    func testEditorDefaultsToPoundsAndCreatesKilogramPayload() async {
        let date = Date(timeIntervalSince1970: 1_788_000_000)
        let fixture = EditorFixture(
            mode: .create(date)
        )
        let saved = Checkin.fixture(weightKg: 74.84274105)
        fixture.api.setMockResponse(saved, for: Endpoint.createCheckin(.fixture))
        fixture.model.weightText = "165"
        fixture.model.energyLevel = 7
        fixture.model.mood = 8
        fixture.model.nausea = 1
        fixture.model.fatigue = 2
        fixture.model.notes = "Felt steady after morning dose."

        let outcome = await fixture.model.save()

        XCTAssertEqual(fixture.model.selectedWeightUnit, .pounds)
        XCTAssertEqual(outcome, .saved(saved.id))
        XCTAssertFalse(fixture.model.isSaving)
        XCTAssertNil(fixture.model.errorMessage)
        guard case .createCheckin(let request) = fixture.api.requestLog.last else {
            return XCTFail("Expected create endpoint")
        }
        XCTAssertEqual(request.date, date)
        XCTAssertEqual(request.weightKg ?? 0, 74.84274105, accuracy: 0.000001)
        XCTAssertEqual(request.energyLevel, 7)
        XCTAssertEqual(request.mood, 8)
        XCTAssertEqual(request.nausea, 1)
        XCTAssertEqual(request.fatigue, 2)
        XCTAssertEqual(request.notes, "Felt steady after morning dose.")
    }

    func testSaveRequiresAtLeastOneMetricSymptomOrNote() async {
        let fixture = EditorFixture(mode: .create(Date()))

        let outcome = await fixture.model.save()

        XCTAssertNil(outcome)
        XCTAssertEqual(
            fixture.model.errorMessage,
            "Add at least one metric, symptom, or note."
        )
    }

    func testEditorPresentationDistinguishesCreateAndEditModes() {
        let create = EditorFixture(mode: .create(Date()))
        let edit = EditorFixture(mode: .edit(Checkin.fixture()))

        XCTAssertEqual(create.model.editorTitle, "Add check-in")
        XCTAssertEqual(
            create.model.supportingText,
            "Log today's signals so Peppy can understand your protocol response."
        )
        XCTAssertEqual(create.model.primaryActionTitle, "Add check-in")
        XCTAssertEqual(edit.model.editorTitle, "Update check-in")
        XCTAssertEqual(
            edit.model.supportingText,
            "Review or change today's saved signals."
        )
        XCTAssertEqual(edit.model.primaryActionTitle, "Update check-in")
    }

    func testInvalidWeightExposesLiveFieldGuidanceAndPreservesDraft() {
        let fixture = EditorFixture(mode: .create(Date()))
        fixture.model.notes = "Keep this draft"
        fixture.model.weightText = "16."

        XCTAssertEqual(
            fixture.model.weightErrorMessage,
            "Enter a valid weight in lb."
        )
        XCTAssertEqual(fixture.model.weightFieldAccessibilityLabel, "Weight in pounds")
        XCTAssertFalse(fixture.model.canSave)
        XCTAssertEqual(fixture.model.notes, "Keep this draft")
        XCTAssertNil(fixture.model.errorMessage)
    }

    func testEditModePrefillsAndSendsExplicitNullableSnapshot() async {
        let existing = Checkin.fixture(weightKg: 74.8, energyLevel: 7, notes: "Original")
        let fixture = EditorFixture(mode: .edit(existing))
        let updated = existing.replacing(energyLevel: 9, notes: nil)
        fixture.api.setMockResponse(
            [existing],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        await fixture.store.load()
        fixture.api.setMockResponse(
            updated,
            for: Endpoint.updateCheckin(id: existing.id, .fixture)
        )

        XCTAssertEqual(Double(fixture.model.weightText) ?? 0, 164.9, accuracy: 0.1)
        XCTAssertEqual(fixture.model.energyLevel, 7)
        XCTAssertEqual(fixture.model.notes, "Original")

        fixture.model.weightText = ""
        fixture.model.energyLevel = 9
        fixture.model.notes = ""

        let outcome = await fixture.model.save()

        XCTAssertEqual(outcome, .saved(existing.id))
        guard case .updateCheckin(_, let request) = fixture.api.requestLog.last else {
            return XCTFail("Expected update endpoint")
        }
        XCTAssertNil(request.weightKg)
        XCTAssertNil(request.notes)
        XCTAssertEqual(request.energyLevel, 9)
    }

    func testSwitchingUnitConvertsValidTextAndPersistsPreference() {
        let fixture = EditorFixture(mode: .create(Date()))
        fixture.model.weightText = "165"

        fixture.model.changeWeightUnit(to: .kilograms)

        XCTAssertEqual(Double(fixture.model.weightText) ?? 0, 74.8, accuracy: 0.1)
        XCTAssertEqual(fixture.preferences.unit, .kilograms)
    }

    func testSwitchingUnitPreservesInvalidTextForValidation() {
        let fixture = EditorFixture(mode: .create(Date()))
        fixture.model.weightText = "16."

        fixture.model.changeWeightUnit(to: .kilograms)

        XCTAssertEqual(fixture.model.weightText, "16.")
        XCTAssertEqual(fixture.preferences.unit, .kilograms)
    }

    func testInvalidWeightDoesNotSaveAsAnIntentionalClear() async {
        let fixture = EditorFixture(mode: .create(Date()))
        fixture.model.weightText = "16."
        fixture.model.notes = "Keep this note"

        let outcome = await fixture.model.save()

        XCTAssertNil(outcome)
        XCTAssertEqual(fixture.model.errorMessage, "Enter a valid weight in lb.")
        XCTAssertTrue(fixture.api.requestLog.isEmpty)
    }

    func testConflictReturnsExistingOutcomeAndKeepsFormUsable() async {
        let date = Date(timeIntervalSince1970: 1_789_689_600)
        let fixture = EditorFixture(mode: .create(date))
        let existing = Checkin.fixture(date: date)
        fixture.api.setMockError(
            .conflict("Already exists"),
            for: Endpoint.createCheckin(.fixture)
        )
        fixture.api.setMockResponse(
            [existing],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        fixture.model.notes = "Duplicate attempt"

        let outcome = await fixture.model.save()

        XCTAssertEqual(outcome, .existing(existing.id))
        XCTAssertEqual(fixture.model.notes, "Duplicate attempt")
    }

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

    func testCheckinResponseRejectsSemanticallyInvalidCalendarTimestamp() throws {
        XCTAssertThrowsError(
            try decodeCheckin(
                createdAt: "2026-02-30T14:25:31Z",
                updatedAt: "2026-07-16T14:26:32Z"
            )
        ) { error in
            guard case DecodingError.dataCorrupted = error else {
                return XCTFail("Expected dataCorrupted, got \(error)")
            }
        }
    }

    func testCheckinResponseRejectsInvalidTimezoneOffset() throws {
        XCTAssertThrowsError(
            try decodeCheckin(
                createdAt: "2026-07-16T14:25:31Z",
                updatedAt: "2026-07-16T14:26:32+99:00"
            )
        ) { error in
            guard case DecodingError.dataCorrupted = error else {
                return XCTFail("Expected dataCorrupted, got \(error)")
            }
        }
    }

    func testUpdateRequestEncodesNullForClearedFields() throws {
        let request = UpdateCheckinRequest(
            date: Date(timeIntervalSince1970: 1_788_000_000),
            weightKg: nil,
            energyLevel: 9,
            sleepQuality: nil,
            appetiteLevel: nil,
            mood: nil,
            nausea: nil,
            injectionSiteReaction: nil,
            fatigue: nil,
            headache: nil,
            giIssues: nil,
            notes: nil
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )
        XCTAssertTrue(object["weight_kg"] is NSNull)
        XCTAssertTrue(object["notes"] is NSNull)
        XCTAssertEqual(object["energy_level"] as? Int, 9)
    }

    func testUpdateRequestEncodesUTCDateAndNullForEveryOptionalField() throws {
        let request = UpdateCheckinRequest(
            date: Date(timeIntervalSince1970: 1_788_000_000),
            weightKg: nil,
            energyLevel: nil,
            sleepQuality: nil,
            appetiteLevel: nil,
            mood: nil,
            nausea: nil,
            injectionSiteReaction: nil,
            fatigue: nil,
            headache: nil,
            giIssues: nil,
            notes: nil
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )

        XCTAssertEqual(object["date"] as? String, "2026-08-29")
        for key in [
            "weight_kg",
            "energy_level",
            "sleep_quality",
            "appetite_level",
            "mood",
            "nausea",
            "injection_site_reaction",
            "fatigue",
            "headache",
            "gi_issues",
            "notes"
        ] {
            XCTAssertTrue(object[key] is NSNull, "Expected explicit null for \(key)")
        }
    }

    func testUpdateEndpointUsesPatchAndCheckinIdentifier() {
        let id = UUID()
        let request = UpdateCheckinRequest.fixture
        let endpoint = Endpoint.updateCheckin(id: id, request)

        XCTAssertEqual(endpoint.method, .patch)
        XCTAssertEqual(endpoint.path, "/checkins/\(id)")
        XCTAssertEqual(endpoint.body as? UpdateCheckinRequest, request)
    }

    func testConflictErrorPreservesServerMessage() {
        XCTAssertEqual(
            APIError.conflict("Check-in already exists for 2026-07-17").userMessage,
            "Check-in already exists for 2026-07-17"
        )
    }

    func testConflictErrorEqualityIncludesAssociatedMessage() {
        XCTAssertEqual(APIError.conflict("same"), APIError.conflict("same"))
        XCTAssertNotEqual(APIError.conflict("first"), APIError.conflict("second"))
        XCTAssertNotEqual(APIError.conflict("same"), APIError.unknown("same"))
    }

    func testAPIClientDecodesServerMessageFromConflictResponse() async throws {
        let client = try makeAPIClient(
            statusCode: 409,
            body: #"{"detail":"Check-in already exists for 2026-07-17"}"#
        )

        do {
            try await client.executeVoid(.updateCheckin(id: UUID(), .fixture))
            XCTFail("Expected conflict error")
        } catch let error as APIError {
            XCTAssertEqual(error, .conflict("Check-in already exists for 2026-07-17"))
        } catch {
            XCTFail("Expected APIError.conflict, got \(error)")
        }
    }

    func testAPIClientUsesFallbackMessageForMalformedConflictResponse() async throws {
        let client = try makeAPIClient(statusCode: 409, body: "not-json")

        do {
            try await client.executeVoid(.updateCheckin(id: UUID(), .fixture))
            XCTFail("Expected conflict error")
        } catch let error as APIError {
            XCTAssertEqual(error, .conflict("A check-in already exists for this date."))
        } catch {
            XCTFail("Expected APIError.conflict, got \(error)")
        }
    }

    func testWeightUnitConversionsAndFormatting() {
        XCTAssertEqual(WeightUnit.pounds.kilograms(from: 165), 74.84274105, accuracy: 0.000001)
        XCTAssertEqual(WeightUnit.pounds.displayValue(kilograms: 74.84274105), 165, accuracy: 0.000001)
        XCTAssertEqual(WeightUnit.pounds.format(kilograms: 74.84274105), "165.0 lb")
        XCTAssertEqual(WeightUnit.kilograms.format(kilograms: 74.8), "74.8 kg")
    }

    func testWeightPreferenceDefaultsToPoundsAndPersistsSelection() {
        let suite = "WeightUnitPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = WeightUnitPreferences(defaults: defaults)
        XCTAssertEqual(first.unit, .pounds)
        first.select(.kilograms)

        let second = WeightUnitPreferences(defaults: defaults)
        XCTAssertEqual(second.unit, .kilograms)
    }

    func testWeightPreferenceUsesOnboardingSeedOnlyWhenNoSavedSelectionExists() {
        let suite = "WeightUnitPreferencesSeedTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let seeded = WeightUnitPreferences(defaults: defaults, seed: { .kilograms })
        XCTAssertEqual(seeded.unit, .kilograms)
        seeded.select(.pounds)

        let reloaded = WeightUnitPreferences(defaults: defaults, seed: { .kilograms })
        XCTAssertEqual(reloaded.unit, .pounds)
    }

    func testWeightPreferenceReevaluatesSeedThatBecomesAvailableLater() {
        let suite = "WeightUnitPreferencesLateSeedTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var seed: WeightUnit?
        let preferences = WeightUnitPreferences(defaults: defaults, seed: { seed })

        XCTAssertEqual(preferences.unit, .pounds)
        seed = .kilograms
        XCTAssertEqual(preferences.unit, .kilograms)
    }

    func testMockDependenciesPreferAuthenticatedUserDraftOverAnonymousDraft() throws {
        let defaults = UserDefaults.standard
        let key = "peppy.checkins.weight-unit"
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.removeObject(forKey: key)

        let dependencies = Dependencies.mock()
        let store = try XCTUnwrap(dependencies.onboardingStore as? InMemoryOnboardingStore)
        var anonymousDraft = OnboardingDraft()
        anonymousDraft.preferredWeightUnit = .pounds
        store.saveAnonymousDraft(anonymousDraft)

        let userID = UUID()
        var userDraft = OnboardingDraft()
        userDraft.preferredWeightUnit = .kilograms
        store.userDrafts[userID] = userDraft
        dependencies.appState.login(user: User(id: userID, email: "checkins@example.com"))

        XCTAssertEqual(dependencies.weightUnitPreferences.unit, .kilograms)
    }

    func testStoreLoadsNewestFirstAndSeparatesTodayFromHistory() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let older = today.addingTimeInterval(-86_400)
        api.setMockResponse(
            [Checkin.fixture(date: older), Checkin.fixture(date: today)],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        let store = CheckinStore(api: api, now: { today })

        await store.load()

        XCTAssertEqual(store.today?.date, today)
        XCTAssertEqual(store.history.map(\.date), [older])
        XCTAssertEqual(store.checkins.map(\.date), [today, older])
    }

    func testStoreListKeepsOnlyNewestOneHundredRecords() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let records = (0..<101).map { index in
            Checkin.fixture(date: today.addingTimeInterval(-Double(index) * 86_400))
        }
        api.setMockResponse(
            Array(records.reversed()),
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        let store = CheckinStore(api: api, now: { today })

        await store.load()

        XCTAssertEqual(store.checkins.count, 100)
        XCTAssertEqual(store.checkins.first?.id, records.first?.id)
        XCTAssertEqual(store.checkins.last?.id, records[99].id)
        XCTAssertFalse(store.checkins.contains { $0.id == records[100].id })
    }

    func testStoreDeduplicatesIdentifiersBeforeApplyingOneHundredRecordCap() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let duplicateID = UUID()
        let staleDuplicate = Checkin.fixture(
            id: duplicateID,
            date: today,
            energyLevel: 4,
            updatedAt: today.addingTimeInterval(-60)
        )
        let freshDuplicate = Checkin.fixture(
            id: duplicateID,
            date: today,
            energyLevel: 9,
            updatedAt: today
        )
        let otherRecords = (1...99).map { index in
            Checkin.fixture(date: today.addingTimeInterval(-Double(index) * 86_400))
        }
        api.setMockResponse(
            [staleDuplicate, freshDuplicate] + otherRecords,
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        let store = CheckinStore(api: api, now: { today })

        await store.load()

        XCTAssertEqual(store.checkins.count, 100)
        XCTAssertEqual(Set(store.checkins.map(\.id)).count, 100)
        XCTAssertEqual(store.checkin(id: duplicateID)?.energyLevel, 9)
    }

    func testStoreUsesUTCBoundaryForToday() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let previousUTCDay = today.addingTimeInterval(-3_600)
        api.setMockResponse(
            [Checkin.fixture(date: previousUTCDay), Checkin.fixture(date: today)],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        let store = CheckinStore(api: api, now: { today })

        await store.load()

        XCTAssertEqual(store.today?.date, today)
        XCTAssertEqual(store.history.map(\.date), [previousUTCDay])
    }

    func testStoreRefreshFailureKeepsLoadedRecords() async {
        let api = MockAPIClient()
        let record = Checkin.fixture()
        api.setMockResponse([record], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        let store = CheckinStore(api: api)
        await store.load()
        api.setMockError(.networkUnavailable, for: Endpoint.getCheckins(startDate: nil, endDate: nil))

        await store.load(force: true)

        XCTAssertEqual(store.checkins.map(\.id), [record.id])
        XCTAssertEqual(store.errorMessage, "No internet connection.")
    }

    func testStoreStaleListSuccessCannotOverwriteNewerCreate() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let created = Checkin.fixture(date: today)
        let listEndpoint = Endpoint.getCheckins(startDate: nil, endDate: nil)
        api.setMockResponse([Checkin](), for: listEndpoint)
        api.setMockResponse(created, for: Endpoint.createCheckin(.fixture))
        let gate = CheckinAsyncGate()
        let listStarted = expectation(description: "List request started")
        api.onRequest = { endpoint in
            guard case .getCheckins = endpoint else { return }
            listStarted.fulfill()
            await gate.wait()
        }
        let store = CheckinStore(api: api, now: { today })

        let listLoad = Task { await store.load() }
        await fulfillment(of: [listStarted], timeout: 2)
        let result = await store.create(.fixture)
        XCTAssertEqual(store.checkins, [created])

        await gate.open()
        await listLoad.value

        XCTAssertEqual(result, .saved(created))
        XCTAssertEqual(store.checkins, [created])
        XCTAssertFalse(store.isLoading)
        XCTAssertEqual(store.revision, 1)
    }

    func testStoreStaleListFailureCannotOverwriteNewerCreate() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let created = Checkin.fixture(date: today)
        let listEndpoint = Endpoint.getCheckins(startDate: nil, endDate: nil)
        api.setMockError(.serverError, for: listEndpoint)
        api.setMockResponse(created, for: Endpoint.createCheckin(.fixture))
        let gate = CheckinAsyncGate()
        let listStarted = expectation(description: "List request started")
        api.onRequest = { endpoint in
            guard case .getCheckins = endpoint else { return }
            listStarted.fulfill()
            await gate.wait()
        }
        let store = CheckinStore(api: api, now: { today })

        let listLoad = Task { await store.load() }
        await fulfillment(of: [listStarted], timeout: 2)
        let result = await store.create(.fixture)
        XCTAssertEqual(store.checkins, [created])

        await gate.open()
        await listLoad.value

        XCTAssertEqual(result, .saved(created))
        XCTAssertEqual(store.checkins, [created])
        XCTAssertNil(store.errorMessage)
        XCTAssertFalse(store.isLoading)
        XCTAssertEqual(store.revision, 1)
    }

    func testStoreStaleListSuccessCannotOverwriteNewerUpdate() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let original = Checkin.fixture(date: today, energyLevel: 7)
        let updated = original.replacing(energyLevel: 9)
        let listEndpoint = Endpoint.getCheckins(startDate: nil, endDate: nil)
        api.setMockResponse([original], for: listEndpoint)
        api.setMockResponse(updated, for: Endpoint.updateCheckin(id: original.id, .fixture))
        let store = CheckinStore(api: api, now: { today })
        await store.load()
        let gate = CheckinAsyncGate()
        let refreshStarted = expectation(description: "Refresh started")
        api.onRequest = { endpoint in
            guard case .getCheckins = endpoint else { return }
            refreshStarted.fulfill()
            await gate.wait()
        }

        let refresh = Task { await store.load(force: true) }
        await fulfillment(of: [refreshStarted], timeout: 2)
        let result = await store.update(id: original.id, request: .fixture)
        XCTAssertEqual(store.checkins, [updated])

        await gate.open()
        await refresh.value

        XCTAssertEqual(result, updated)
        XCTAssertEqual(store.checkins, [updated])
        XCTAssertFalse(store.isLoading)
        XCTAssertEqual(store.revision, 1)
    }

    func testStoreStaleListSuccessCannotOverwriteNewerDetail() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let original = Checkin.fixture(date: today, energyLevel: 7)
        let detail = original.replacing(energyLevel: 9, notes: "Fresh detail")
        let listEndpoint = Endpoint.getCheckins(startDate: nil, endDate: nil)
        api.setMockResponse([original], for: listEndpoint)
        api.setMockResponse(detail, for: Endpoint.getCheckin(id: original.id))
        let store = CheckinStore(api: api, now: { today })
        await store.load()
        let gate = CheckinAsyncGate()
        let refreshStarted = expectation(description: "Refresh started")
        api.onRequest = { endpoint in
            guard case .getCheckins = endpoint else { return }
            refreshStarted.fulfill()
            await gate.wait()
        }

        let refresh = Task { await store.load(force: true) }
        await fulfillment(of: [refreshStarted], timeout: 2)
        await store.loadDetail(original.id)
        XCTAssertEqual(store.checkins, [detail])

        await gate.open()
        await refresh.value

        XCTAssertEqual(store.checkins, [detail])
        XCTAssertEqual(store.selectedCheckin, detail)
        XCTAssertFalse(store.isLoading)
    }

    func testStoreListRefreshUpdatesMatchingSelectedDetail() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let original = Checkin.fixture(date: today, energyLevel: 7)
        let refreshed = original.replacing(energyLevel: 9, notes: "Refreshed list")
        let listEndpoint = Endpoint.getCheckins(startDate: nil, endDate: nil)
        api.setMockResponse([original], for: listEndpoint)
        api.setMockResponse(original, for: Endpoint.getCheckin(id: original.id))
        let store = CheckinStore(api: api, now: { today })
        await store.load()
        await store.loadDetail(original.id)
        api.setMockResponse([refreshed], for: listEndpoint)

        await store.load(force: true)

        XCTAssertEqual(store.checkins, [refreshed])
        XCTAssertEqual(store.selectedCheckin, refreshed)
    }

    func testStoreNewerListSuccessWinsOverStaleListSuccessAndSettlesLoading() async {
        let api = MockAPIClient()
        let older = Checkin.fixture(energyLevel: 7)
        let newer = older.replacing(energyLevel: 9)
        let listEndpoint = Endpoint.getCheckins(startDate: nil, endDate: nil)
        api.setMockResponse([older], for: listEndpoint)
        let gate = CheckinAsyncGate()
        let firstStarted = expectation(description: "First list started")
        var requestCount = 0
        api.onRequest = { endpoint in
            guard case .getCheckins = endpoint else { return }
            requestCount += 1
            guard requestCount == 1 else { return }
            firstStarted.fulfill()
            await gate.wait()
        }
        let store = CheckinStore(api: api)

        let firstLoad = Task { await store.load(force: true) }
        await fulfillment(of: [firstStarted], timeout: 2)
        api.setMockResponse([newer], for: listEndpoint)
        await store.load(force: true)

        XCTAssertEqual(store.checkins, [newer])
        XCTAssertFalse(store.isLoading)
        api.setMockResponse([older], for: listEndpoint)
        await gate.open()
        await firstLoad.value

        XCTAssertEqual(store.checkins, [newer])
        XCTAssertNil(store.errorMessage)
        XCTAssertFalse(store.isLoading)
    }

    func testStoreNewerListSuccessWinsOverStaleListFailureAndSettlesLoading() async {
        let api = MockAPIClient()
        let newer = Checkin.fixture(energyLevel: 9)
        let listEndpoint = Endpoint.getCheckins(startDate: nil, endDate: nil)
        api.setMockError(.serverError, for: listEndpoint)
        let gate = CheckinAsyncGate()
        let firstStarted = expectation(description: "First list started")
        var requestCount = 0
        api.onRequest = { endpoint in
            guard case .getCheckins = endpoint else { return }
            requestCount += 1
            guard requestCount == 1 else { return }
            firstStarted.fulfill()
            await gate.wait()
        }
        let store = CheckinStore(api: api)

        let firstLoad = Task { await store.load(force: true) }
        await fulfillment(of: [firstStarted], timeout: 2)
        api.mockErrors.removeValue(forKey: listEndpoint.requestID)
        api.setMockResponse([newer], for: listEndpoint)
        await store.load(force: true)

        XCTAssertEqual(store.checkins, [newer])
        XCTAssertFalse(store.isLoading)
        api.setMockError(.serverError, for: listEndpoint)
        await gate.open()
        await firstLoad.value

        XCTAssertEqual(store.checkins, [newer])
        XCTAssertNil(store.errorMessage)
        XCTAssertFalse(store.isLoading)
    }

    func testStoreLoadDetailReconcilesSelectedAndListedRecord() async {
        let api = MockAPIClient()
        let local = Checkin.fixture(energyLevel: 7)
        let detail = local.replacing(energyLevel: 9, notes: "Updated detail")
        api.setMockResponse([local], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        api.setMockResponse(detail, for: Endpoint.getCheckin(id: local.id))
        let store = CheckinStore(api: api)
        await store.load()

        await store.loadDetail(local.id)

        XCTAssertEqual(store.selectedCheckin, detail)
        XCTAssertEqual(store.checkin(id: local.id), detail)
        XCTAssertEqual(store.checkins, [detail])
    }

    func testStoreDetailReconciliationRemovesEveryExistingDuplicate() async {
        let api = MockAPIClient()
        let id = UUID()
        let stale = Checkin.fixture(id: id, energyLevel: 4)
        let duplicate = Checkin.fixture(id: id, energyLevel: 6)
        let detail = Checkin.fixture(id: id, energyLevel: 9, notes: "Fresh detail")
        api.setMockResponse(
            [stale, duplicate],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        api.setMockResponse(detail, for: Endpoint.getCheckin(id: id))
        let store = CheckinStore(api: api)
        await store.load()

        await store.loadDetail(id)

        XCTAssertEqual(store.checkins.filter { $0.id == id }, [detail])
        XCTAssertEqual(store.selectedCheckin, detail)
    }

    func testStoreDelayedDetailCannotOverwriteNewerUpdate() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let original = Checkin.fixture(date: today, energyLevel: 4)
        let staleDetail = original.replacing(energyLevel: 5, notes: "Stale detail")
        let updated = original.replacing(energyLevel: 9, notes: "Saved update")
        api.setMockResponse(
            [original],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        api.setMockResponse(staleDetail, for: Endpoint.getCheckin(id: original.id))
        api.setMockResponse(
            updated,
            for: Endpoint.updateCheckin(id: original.id, .fixture)
        )
        let store = CheckinStore(api: api, now: { today })
        await store.load()
        let gate = CheckinAsyncGate()
        let detailStarted = expectation(description: "Detail request started")
        api.onRequest = { endpoint in
            guard case .getCheckin = endpoint else { return }
            detailStarted.fulfill()
            await gate.wait()
        }

        let detailLoad = Task { await store.loadDetail(original.id) }
        await fulfillment(of: [detailStarted], timeout: 2)
        let result = await store.update(id: original.id, request: .fixture)
        await gate.open()
        _ = await detailLoad.value

        XCTAssertEqual(result, updated)
        XCTAssertEqual(store.checkins, [updated])
        XCTAssertEqual(store.selectedCheckin, updated)
    }

    func testStoreDelayedDetailCannotOverwriteNewerList() async {
        let api = MockAPIClient()
        let original = Checkin.fixture(energyLevel: 4)
        let staleDetail = original.replacing(energyLevel: 5, notes: "Stale detail")
        let refreshed = original.replacing(energyLevel: 9, notes: "Newer list")
        let listEndpoint = Endpoint.getCheckins(startDate: nil, endDate: nil)
        api.setMockResponse([original], for: listEndpoint)
        api.setMockResponse(staleDetail, for: Endpoint.getCheckin(id: original.id))
        let store = CheckinStore(api: api)
        await store.load()
        let gate = CheckinAsyncGate()
        let detailStarted = expectation(description: "Detail request started")
        api.onRequest = { endpoint in
            guard case .getCheckin = endpoint else { return }
            detailStarted.fulfill()
            await gate.wait()
        }

        let detailLoad = Task { await store.loadDetail(original.id) }
        await fulfillment(of: [detailStarted], timeout: 2)
        api.setMockResponse([refreshed], for: listEndpoint)
        await store.load(force: true)
        await gate.open()
        _ = await detailLoad.value

        XCTAssertEqual(store.checkins, [refreshed])
        XCTAssertEqual(store.selectedCheckin, refreshed)
    }

    func testLogoutInvalidatesDelayedListResponse() async {
        let dependencies = Dependencies.mock()
        let api = try! XCTUnwrap(dependencies.api as? MockAPIClient)
        let record = Checkin.fixture()
        api.setMockResponse(
            [record],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        let gate = CheckinAsyncGate()
        let requestStarted = expectation(description: "List request started")
        api.onRequest = { endpoint in
            guard case .getCheckins = endpoint else { return }
            requestStarted.fulfill()
            await gate.wait()
        }

        let load = Task { await dependencies.checkinStore.load() }
        await fulfillment(of: [requestStarted], timeout: 2)
        await dependencies.flow.logout()
        await gate.open()
        _ = await load.value

        XCTAssertTrue(dependencies.checkinStore.checkins.isEmpty)
        XCTAssertNil(dependencies.checkinStore.selectedCheckin)
        XCTAssertFalse(dependencies.checkinStore.isLoading)
    }

    func testLogoutInvalidatesDelayedDetailResponse() async {
        let dependencies = Dependencies.mock()
        let api = try! XCTUnwrap(dependencies.api as? MockAPIClient)
        let original = Checkin.fixture(energyLevel: 4)
        let detail = original.replacing(energyLevel: 9, notes: "User A detail")
        api.setMockResponse(
            [original],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        await dependencies.checkinStore.load()
        api.setMockResponse(detail, for: Endpoint.getCheckin(id: original.id))
        let gate = CheckinAsyncGate()
        let requestStarted = expectation(description: "Detail request started")
        api.onRequest = { endpoint in
            guard case .getCheckin = endpoint else { return }
            requestStarted.fulfill()
            await gate.wait()
        }

        let load = Task { await dependencies.checkinStore.loadDetail(original.id) }
        await fulfillment(of: [requestStarted], timeout: 2)
        await dependencies.flow.logout()
        await gate.open()
        _ = await load.value

        XCTAssertTrue(dependencies.checkinStore.checkins.isEmpty)
        XCTAssertNil(dependencies.checkinStore.selectedCheckin)
    }

    func testLogoutInvalidatesDelayedCreateResponse() async {
        let dependencies = Dependencies.mock()
        let api = try! XCTUnwrap(dependencies.api as? MockAPIClient)
        let created = Checkin.fixture()
        api.setMockResponse(created, for: Endpoint.createCheckin(.fixture))
        let gate = CheckinAsyncGate()
        let requestStarted = expectation(description: "Create request started")
        api.onRequest = { endpoint in
            guard case .createCheckin = endpoint else { return }
            requestStarted.fulfill()
            await gate.wait()
        }

        let create = Task { await dependencies.checkinStore.create(.fixture) }
        await fulfillment(of: [requestStarted], timeout: 2)
        await dependencies.flow.logout()
        await gate.open()
        let result = await create.value

        XCTAssertEqual(result, .failed)
        XCTAssertTrue(dependencies.checkinStore.checkins.isEmpty)
        XCTAssertEqual(dependencies.checkinStore.revision, 0)
    }

    func testLogoutInvalidatesDelayedUpdateResponse() async {
        let dependencies = Dependencies.mock()
        let api = try! XCTUnwrap(dependencies.api as? MockAPIClient)
        let today = Date()
        let original = Checkin.fixture(date: today, energyLevel: 4)
        let updated = original.replacing(energyLevel: 9, notes: "User A update")
        api.setMockResponse(
            [original],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        await dependencies.checkinStore.load()
        let request = UpdateCheckinRequest.fixture(date: today)
        api.setMockResponse(
            updated,
            for: Endpoint.updateCheckin(id: original.id, request)
        )
        let gate = CheckinAsyncGate()
        let requestStarted = expectation(description: "Update request started")
        api.onRequest = { endpoint in
            guard case .updateCheckin = endpoint else { return }
            requestStarted.fulfill()
            await gate.wait()
        }

        let update = Task {
            await dependencies.checkinStore.update(id: original.id, request: request)
        }
        await fulfillment(of: [requestStarted], timeout: 2)
        await dependencies.flow.logout()
        await gate.open()
        let result = await update.value

        XCTAssertNil(result)
        XCTAssertTrue(dependencies.checkinStore.checkins.isEmpty)
        XCTAssertNil(dependencies.checkinStore.selectedCheckin)
        XCTAssertEqual(dependencies.checkinStore.revision, 0)
    }

    func testStoreOffListDetailRetainsSelectionWithoutExceedingOneHundredRecords() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let existing = (0..<100).map { index in
            Checkin.fixture(date: today.addingTimeInterval(-Double(index) * 86_400))
        }
        let detail = Checkin.fixture(date: today.addingTimeInterval(-101 * 86_400))
        api.setMockResponse(existing, for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        api.setMockResponse(detail, for: Endpoint.getCheckin(id: detail.id))
        let store = CheckinStore(api: api, now: { today })
        await store.load()

        await store.loadDetail(detail.id)

        XCTAssertEqual(store.checkins.count, 100)
        XCTAssertFalse(store.checkins.contains { $0.id == detail.id })
        XCTAssertEqual(store.selectedCheckin, detail)
        XCTAssertEqual(store.checkin(id: detail.id), detail)
    }

    func testStoreCreateAndUpdateReconcileByIdentifier() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let original = Checkin.fixture(energyLevel: 7)
        let updated = original.replacing(energyLevel: 9)
        api.setMockResponse(original, for: Endpoint.createCheckin(.fixture))
        api.setMockResponse(updated, for: Endpoint.updateCheckin(id: original.id, .fixture))
        let store = CheckinStore(api: api, now: { today })

        let createResult = await store.create(.fixture)
        let updateResult = await store.update(id: original.id, request: .fixture)

        XCTAssertEqual(createResult, .saved(original))
        XCTAssertNotNil(updateResult)

        XCTAssertEqual(store.checkins.count, 1)
        XCTAssertEqual(store.checkins.first?.energyLevel, 9)
        XCTAssertEqual(store.revision, 2)
    }

    func testStoreCreateBeforeInitialLoadDoesNotSuppressHistoryLoad() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let created = Checkin.fixture(date: today)
        let historical = Checkin.fixture(date: today.addingTimeInterval(-86_400))
        api.setMockResponse(created, for: Endpoint.createCheckin(.fixture))
        api.setMockResponse(
            [historical, created],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        let store = CheckinStore(api: api, now: { today })

        let result = await store.create(.fixture)
        await store.load()

        XCTAssertEqual(result, .saved(created))
        XCTAssertEqual(store.checkins, [created, historical])
        XCTAssertEqual(api.requestLog.filter { endpoint in
            if case .getCheckins = endpoint { return true }
            return false
        }.count, 1)
    }

    func testStoreCreateKeepsCollectionAtOneHundredNewestRecords() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let existing = (0..<100).map { index in
            Checkin.fixture(date: today.addingTimeInterval(-Double(index + 1) * 86_400))
        }
        let created = Checkin.fixture(date: today)
        api.setMockResponse(existing, for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        api.setMockResponse(created, for: Endpoint.createCheckin(.fixture))
        let store = CheckinStore(api: api, now: { today })
        await store.load()

        let result = await store.create(.fixture)

        XCTAssertEqual(result, .saved(created))
        XCTAssertEqual(store.checkins.count, 100)
        XCTAssertEqual(store.checkins.first, created)
        XCTAssertFalse(store.checkins.contains { $0.id == existing.last?.id })
    }

    func testStoreFailedMutationsDoNotIncrementRevision() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let existing = Checkin.fixture(date: today)
        api.setMockResponse([existing], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        api.setMockError(.networkUnavailable, for: Endpoint.createCheckin(.fixture))
        api.setMockError(.serverError, for: Endpoint.updateCheckin(id: existing.id, .fixture))
        let store = CheckinStore(api: api, now: { today })
        await store.load()

        let createResult = await store.create(.fixture)
        let updateResult = await store.update(id: existing.id, request: .fixture)

        XCTAssertEqual(createResult, .failed)
        XCTAssertNil(updateResult)
        XCTAssertEqual(store.revision, 0)
    }

    func testStoreRejectsDuplicateConcurrentUpdateForSameIdentifier() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let original = Checkin.fixture(energyLevel: 7)
        let updated = original.replacing(energyLevel: 9)
        api.setMockResponse([original], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        api.setMockResponse(updated, for: Endpoint.updateCheckin(id: original.id, .fixture))
        let store = CheckinStore(api: api, now: { today })
        await store.load()
        let firstRequestStarted = expectation(description: "First update started")
        let gate = CheckinAsyncGate()
        var updateRequestCount = 0
        api.onRequest = { endpoint in
            guard case .updateCheckin = endpoint else { return }
            updateRequestCount += 1
            guard updateRequestCount == 1 else { return }
            firstRequestStarted.fulfill()
            await gate.wait()
        }

        let firstUpdate = Task {
            await store.update(id: original.id, request: .fixture)
        }
        await fulfillment(of: [firstRequestStarted], timeout: 1)

        let duplicateResult = await store.update(id: original.id, request: .fixture)

        XCTAssertNil(duplicateResult)
        XCTAssertEqual(updateRequestCount, 1)
        await gate.open()
        let firstResult = await firstUpdate.value
        XCTAssertEqual(firstResult, updated)
        XCTAssertEqual(store.revision, 1)
    }

    func testStoreRejectsUpdatingHistoricalRecordWithoutNetworkCall() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let historical = Checkin.fixture(date: today.addingTimeInterval(-86_400))
        api.setMockResponse([historical], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        let store = CheckinStore(api: api, now: { today })
        await store.load()

        let result = await store.update(id: historical.id, request: .fixture)

        XCTAssertNil(result)
        XCTAssertEqual(store.errorMessage, "Only today's check-in can be edited.")
        XCTAssertEqual(store.revision, 0)
        XCTAssertFalse(api.requestLog.contains { endpoint in
            if case .updateCheckin = endpoint { return true }
            return false
        })
    }

    func testStoreRejectsUpdatingUnknownIdentifierWithoutNetworkCall() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let existing = Checkin.fixture(date: today)
        api.setMockResponse([existing], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        let store = CheckinStore(api: api, now: { today })
        await store.load()

        let result = await store.update(id: UUID(), request: .fixture)

        XCTAssertNil(result)
        XCTAssertEqual(
            store.errorMessage,
            "The check-in could not be found. Refresh and try again."
        )
        XCTAssertEqual(store.revision, 0)
        XCTAssertFalse(api.requestLog.contains { endpoint in
            if case .updateCheckin = endpoint { return true }
            return false
        })
    }

    func testStoreRejectsMovingTodayCheckinToAnotherUTCDate() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let existing = Checkin.fixture(date: today)
        api.setMockResponse([existing], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        let store = CheckinStore(api: api, now: { today })
        await store.load()

        let result = await store.update(
            id: existing.id,
            request: .fixture(date: today.addingTimeInterval(-86_400))
        )

        XCTAssertNil(result)
        XCTAssertEqual(store.errorMessage, "Today's check-in cannot be moved to another date.")
        XCTAssertEqual(store.revision, 0)
        XCTAssertFalse(api.requestLog.contains { endpoint in
            if case .updateCheckin = endpoint { return true }
            return false
        })
    }

    func testStoreConflictReloadsAndReturnsExistingToday() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let existing = Checkin.fixture(date: today)
        api.setMockError(.conflict("Already exists"), for: Endpoint.createCheckin(.fixture))
        api.setMockResponse([existing], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        let store = CheckinStore(api: api, now: { today })

        let result = await store.create(.fixture)

        XCTAssertEqual(result, .existing(existing))
        XCTAssertEqual(store.today?.id, existing.id)
        XCTAssertEqual(store.revision, 0)
    }

    func testStoreConflictReloadFailureUsesRecoveryMessage() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        api.setMockError(.conflict("Already exists"), for: Endpoint.createCheckin(.fixture))
        api.setMockError(
            .networkUnavailable,
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        let store = CheckinStore(api: api, now: { today })

        let result = await store.create(.fixture)

        XCTAssertEqual(result, .failed)
        XCTAssertEqual(
            store.errorMessage,
            "A check-in already exists for today, but it could not be loaded."
        )
        XCTAssertNil(store.today)
        XCTAssertFalse(store.isLoading)
        XCTAssertEqual(store.revision, 0)
    }

    func testStoreConflictReloadWithoutTodayUsesRecoveryMessage() async {
        let api = MockAPIClient()
        let today = Date(timeIntervalSince1970: 1_789_689_600)
        let historical = Checkin.fixture(date: today.addingTimeInterval(-86_400))
        api.setMockError(.conflict("Already exists"), for: Endpoint.createCheckin(.fixture))
        api.setMockResponse(
            [historical],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        let store = CheckinStore(api: api, now: { today })

        let result = await store.create(.fixture)

        XCTAssertEqual(result, .failed)
        XCTAssertEqual(
            store.errorMessage,
            "A check-in already exists for today, but it could not be loaded."
        )
        XCTAssertNil(store.today)
        XCTAssertEqual(store.checkins, [historical])
        XCTAssertFalse(store.isLoading)
        XCTAssertEqual(store.revision, 0)
    }

    func testHubSeparatesTodayAndMapsOnlyRecordedDetailValues() async {
        let fixture = HubFixture()
        let today = fixture.makeCheckin(
            weightKg: 74.8,
            energyLevel: 7,
            sleepQuality: nil,
            mood: 8,
            nausea: 1,
            notes: "Felt steady."
        )
        fixture.api.setMockResponse(
            [today],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )

        await fixture.model.loadIfNeeded()

        XCTAssertEqual(fixture.model.state, .loaded)
        XCTAssertEqual(
            fixture.model.todayDetail?.metrics.map(\.label),
            ["Weight", "Energy", "Mood"]
        )
        XCTAssertEqual(fixture.model.todayDetail?.metrics.first?.value, "164.9 lb")
        XCTAssertEqual(fixture.model.todayDetail?.dateText, "Friday, September 18")
        XCTAssertEqual(fixture.model.todayDetail?.isToday, true)
        XCTAssertEqual(
            fixture.model.todayDetail?.symptoms,
            [.init(label: "Nausea", severity: 1)]
        )
        XCTAssertEqual(fixture.model.todayDetail?.notes, "Felt steady.")
        XCTAssertTrue(fixture.model.historyRows.isEmpty)
    }

    func testHubHistoryIsNewestFirstAndRoutesToReadOnlyDetail() async {
        let fixture = HubFixture()
        let newer = fixture.makeCheckin(daysAgo: 1, energyLevel: 7)
        let older = fixture.makeCheckin(daysAgo: 2, mood: 6)
        fixture.api.setMockResponse(
            [older, newer],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )

        await fixture.model.loadIfNeeded()

        XCTAssertEqual(fixture.model.historyRows.map(\.id), [newer.id, older.id])
        XCTAssertEqual(fixture.model.historyRows.first?.dateText, "Thursday, September 17")
        XCTAssertEqual(fixture.model.historyRows.first?.route, .detail(newer.id))
        XCTAssertFalse(fixture.model.detail(for: newer).isToday)
    }

    func testHubPreservesLoadedRowsAndExposesRefreshError() async {
        let fixture = HubFixture()
        let row = fixture.makeCheckin(daysAgo: 1)
        let endpoint = Endpoint.getCheckins(startDate: nil, endDate: nil)
        fixture.api.setMockResponse([row], for: endpoint)
        await fixture.model.loadIfNeeded()
        fixture.api.setMockError(.networkUnavailable, for: endpoint)

        await fixture.model.refresh()

        XCTAssertEqual(fixture.model.state, .loaded)
        XCTAssertEqual(fixture.model.refreshErrorMessage, "No internet connection.")
        XCTAssertEqual(fixture.model.historyRows.map(\.id), [row.id])
    }

    func testDetailFailureDoesNotMasqueradeAsRefreshFailure() async {
        let fixture = HubFixture()
        let row = fixture.makeCheckin(daysAgo: 1)
        fixture.api.setMockResponse(
            [row],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        await fixture.model.loadIfNeeded()
        let missingID = UUID()
        fixture.api.setMockError(.notFound, for: Endpoint.getCheckin(id: missingID))

        await fixture.store.loadDetail(missingID)

        XCTAssertNil(fixture.model.refreshErrorMessage)
        XCTAssertEqual(
            fixture.store.errorMessage,
            "Check-in not found. Refresh your check-ins and try again."
        )
    }

    func testMutationFailureDoesNotMasqueradeAsRefreshFailure() async {
        let fixture = HubFixture()
        let today = fixture.makeCheckin(energyLevel: 4)
        fixture.api.setMockResponse(
            [today],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        await fixture.model.loadIfNeeded()
        fixture.api.setMockError(
            .serverError,
            for: Endpoint.updateCheckin(id: today.id, .fixture)
        )

        _ = await fixture.store.update(id: today.id, request: .fixture)

        XCTAssertNil(fixture.model.refreshErrorMessage)
    }

    func testRefreshErrorSurvivesSuccessfulDetailLoad() async {
        let fixture = HubFixture()
        let row = fixture.makeCheckin(daysAgo: 1)
        let listEndpoint = Endpoint.getCheckins(startDate: nil, endDate: nil)
        fixture.api.setMockResponse([row], for: listEndpoint)
        await fixture.model.loadIfNeeded()
        fixture.api.setMockError(.networkUnavailable, for: listEndpoint)
        await fixture.model.refresh()
        fixture.api.setMockResponse(row, for: Endpoint.getCheckin(id: row.id))

        await fixture.store.loadDetail(row.id)

        XCTAssertEqual(fixture.model.refreshErrorMessage, "No internet connection.")
    }

    func testMissingDetailUsesDedicatedActionableMessage() async {
        let api = MockAPIClient()
        let id = UUID()
        api.setMockError(.notFound, for: Endpoint.getCheckin(id: id))
        let store = CheckinStore(api: api)

        let result = await store.loadDetail(id)

        XCTAssertEqual(result, .notFound)
        XCTAssertNil(store.checkin(id: id))
        XCTAssertEqual(
            store.errorMessage,
            "Check-in not found. Refresh your check-ins and try again."
        )
    }

    func testDetailNetworkFailureUsesNetworkMessageWithoutChangingListState() async {
        let api = MockAPIClient()
        let id = UUID()
        api.setMockError(.networkUnavailable, for: Endpoint.getCheckin(id: id))
        let store = CheckinStore(api: api)

        let result = await store.loadDetail(id)

        XCTAssertEqual(result, .failed)
        XCTAssertTrue(store.checkins.isEmpty)
        XCTAssertNil(store.checkin(id: id))
        XCTAssertEqual(store.errorMessage, "No internet connection.")
    }

    func testChangingPreferredUnitRecomputesHubWeight() async {
        let fixture = HubFixture()
        let today = fixture.makeCheckin(weightKg: 74.8)
        fixture.api.setMockResponse(
            [today],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        await fixture.model.loadIfNeeded()

        fixture.preferences.select(.kilograms)

        XCTAssertEqual(fixture.model.todayDetail?.metrics.first?.value, "74.8 kg")
    }

    func testHubStateMovesFromIdleToEmptyAfterSuccessfulEmptyLoad() async {
        let fixture = HubFixture()
        fixture.api.setMockResponse(
            [Checkin](),
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )

        XCTAssertEqual(fixture.model.state, .idle)
        XCTAssertEqual(fixture.model.createRoute, .create)

        await fixture.model.loadIfNeeded()

        XCTAssertEqual(fixture.model.state, .empty)
    }

    func testHubUsesApprovedRootTitle() {
        let fixture = HubFixture()

        XCTAssertEqual(fixture.model.title, "Your check-ins")
    }

    func testHubInitialLoadFailureProducesFailedState() async {
        let fixture = HubFixture()
        fixture.api.setMockError(
            .networkUnavailable,
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )

        await fixture.model.loadIfNeeded()

        XCTAssertEqual(fixture.model.state, .failed("No internet connection."))
        XCTAssertNil(fixture.model.refreshErrorMessage)
    }

    func testHubRetryAfterInitialFailureClearsInitialErrorAndShowsEmpty() async {
        let fixture = HubFixture()
        let endpoint = Endpoint.getCheckins(startDate: nil, endDate: nil)
        fixture.api.setMockError(.networkUnavailable, for: endpoint)
        await fixture.model.loadIfNeeded()
        XCTAssertEqual(fixture.model.state, .failed("No internet connection."))
        fixture.api.mockErrors.removeValue(forKey: endpoint.requestID)
        fixture.api.setMockResponse([Checkin](), for: endpoint)

        await fixture.model.retry()

        XCTAssertEqual(fixture.model.state, .empty)
        XCTAssertNil(fixture.store.initialLoadErrorMessage)
        XCTAssertNil(fixture.store.refreshErrorMessage)
    }

    func testHubFailedRetryRemainsAnInitialLoadFailure() async {
        let fixture = HubFixture()
        let endpoint = Endpoint.getCheckins(startDate: nil, endDate: nil)
        fixture.api.setMockError(.networkUnavailable, for: endpoint)
        await fixture.model.loadIfNeeded()
        fixture.api.setMockError(.serverError, for: endpoint)

        await fixture.model.retry()

        XCTAssertEqual(fixture.model.state, .failed(APIError.serverError.userMessage))
        XCTAssertEqual(fixture.store.initialLoadErrorMessage, APIError.serverError.userMessage)
        XCTAssertNil(fixture.store.refreshErrorMessage)
    }

    func testHubReportsLoadingWhileInitialRequestIsInFlight() async {
        let fixture = HubFixture()
        let endpoint = Endpoint.getCheckins(startDate: nil, endDate: nil)
        let gate = CheckinAsyncGate()
        let requestStarted = expectation(description: "Check-in list request started")
        fixture.api.setMockResponse([Checkin](), for: endpoint)
        fixture.api.onRequest = { request in
            guard case .getCheckins = request else { return }
            requestStarted.fulfill()
            await gate.wait()
        }

        let load = Task { await fixture.model.loadIfNeeded() }
        await fulfillment(of: [requestStarted], timeout: 2)

        XCTAssertEqual(fixture.model.state, .loading)

        await gate.open()
        await load.value
        XCTAssertEqual(fixture.model.state, .empty)
    }

    func testHubHistorySummaryUsesRecordedValuesAndFallbacks() async {
        let fixture = HubFixture()
        let values = fixture.makeCheckin(
            daysAgo: 1,
            weightKg: 74.8,
            energyLevel: 7,
            mood: 8,
            nausea: 1
        )
        let symptoms = fixture.makeCheckin(daysAgo: 2, fatigue: 2)
        let notes = fixture.makeCheckin(daysAgo: 3, notes: "Felt steady.")
        let saved = fixture.makeCheckin(daysAgo: 4)
        fixture.api.setMockResponse(
            [saved, notes, symptoms, values],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )

        await fixture.model.loadIfNeeded()

        XCTAssertEqual(
            fixture.model.historyRows.map(\.summary),
            [
                "164.9 lb · Energy 7 · Mood 8",
                "Symptoms logged",
                "Notes added",
                "Check-in saved",
            ]
        )
    }

    func testMockDependenciesShareAPIWithCheckinStore() async throws {
        let dependencies = Dependencies.mock()
        let api = try XCTUnwrap(dependencies.api as? MockAPIClient)
        let record = Checkin.fixture()
        api.setMockResponse([record], for: Endpoint.getCheckins(startDate: nil, endDate: nil))

        await dependencies.checkinStore.load()

        XCTAssertEqual(dependencies.checkinStore.checkins, [record])
        XCTAssertEqual(api.requestLog.count, 1)
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

    private func makeAPIClient(statusCode: Int, body: String) throws -> APIClient {
        CheckinURLProtocolStub.statusCode = statusCode
        CheckinURLProtocolStub.responseData = Data(body.utf8)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CheckinURLProtocolStub.self]
        let keychain = MockKeychainService()
        try keychain.save("access-token", for: KeychainKeys.accessToken)
        return APIClient(
            baseURL: URL(string: "https://checkins.example/api/v1")!,
            session: URLSession(configuration: configuration),
            keychain: keychain
        )
    }
}

@MainActor
private final class EditorFixture {
    let api = MockAPIClient()
    let defaults: UserDefaults
    let suite: String
    let preferences: WeightUnitPreferences
    let store: CheckinStore
    let model: CheckinViewModel

    init(mode: CheckinEditorMode) {
        let now: Date
        switch mode {
        case .create(let date):
            now = date
        case .edit(let checkin):
            now = checkin.date
        }

        suite = "EditorFixture.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        preferences = WeightUnitPreferences(defaults: defaults)
        store = CheckinStore(api: api, now: { now })
        model = CheckinViewModel(
            store: store,
            preferences: preferences,
            mode: mode
        )
    }

    deinit {
        defaults.removePersistentDomain(forName: suite)
    }
}

@MainActor
private final class HubFixture {
    let now = Date(timeIntervalSince1970: 1_789_689_600)
    let api = MockAPIClient()
    let defaults: UserDefaults
    let suite: String
    let preferences: WeightUnitPreferences
    let store: CheckinStore
    let model: CheckinHubViewModel

    init() {
        suite = "HubFixture.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        preferences = WeightUnitPreferences(defaults: defaults)
        store = CheckinStore(api: api, now: { [now] in now })
        model = CheckinHubViewModel(store: store, preferences: preferences)
    }

    deinit {
        defaults.removePersistentDomain(forName: suite)
    }

    func makeCheckin(
        daysAgo: Int = 0,
        weightKg: Double? = nil,
        energyLevel: Int? = nil,
        sleepQuality: Int? = nil,
        mood: Int? = nil,
        nausea: Int? = nil,
        fatigue: Int? = nil,
        notes: String? = nil
    ) -> Checkin {
        .fixture(
            date: now.addingTimeInterval(-Double(daysAgo) * 86_400),
            weightKg: weightKg,
            energyLevel: energyLevel,
            sleepQuality: sleepQuality,
            mood: mood,
            nausea: nausea,
            fatigue: fatigue,
            notes: notes
        )
    }
}

private final class CheckinURLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var responseData = Data()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: Self.statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension UpdateCheckinRequest {
    static let fixture = fixture(date: Date(timeIntervalSince1970: 1_789_689_600))

    static func fixture(date: Date) -> UpdateCheckinRequest {
        UpdateCheckinRequest(
            date: date,
            weightKg: 74.8,
            energyLevel: 7,
            sleepQuality: nil,
            appetiteLevel: nil,
            mood: 8,
            nausea: nil,
            injectionSiteReaction: nil,
            fatigue: nil,
            headache: nil,
            giIssues: nil,
            notes: nil
        )
    }
}

private extension CreateCheckinRequest {
    static let fixture = CreateCheckinRequest(
        date: Date(timeIntervalSince1970: 1_789_689_600),
        weightKg: 74.8,
        energyLevel: 7,
        sleepQuality: nil,
        appetiteLevel: nil,
        mood: 8,
        nausea: nil,
        injectionSiteReaction: nil,
        fatigue: nil,
        headache: nil,
        giIssues: nil,
        notes: nil
    )
}

private extension Checkin {
    static func fixture(
        id: UUID = UUID(),
        date: Date = Date(timeIntervalSince1970: 1_789_689_600),
        weightKg: Double? = nil,
        energyLevel: Int? = nil,
        sleepQuality: Int? = nil,
        appetiteLevel: Int? = nil,
        mood: Int? = nil,
        nausea: Int? = nil,
        injectionSiteReaction: Int? = nil,
        fatigue: Int? = nil,
        headache: Int? = nil,
        giIssues: Int? = nil,
        notes: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) -> Checkin {
        Checkin(
            id: id,
            userId: UUID(),
            date: date,
            weightKg: weightKg,
            energyLevel: energyLevel,
            sleepQuality: sleepQuality,
            appetiteLevel: appetiteLevel,
            mood: mood,
            nausea: nausea,
            injectionSiteReaction: injectionSiteReaction,
            fatigue: fatigue,
            headache: headache,
            giIssues: giIssues,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func replacing(energyLevel: Int?, notes: String? = nil) -> Checkin {
        Checkin(
            id: id,
            userId: userId,
            date: date,
            weightKg: weightKg,
            energyLevel: energyLevel,
            sleepQuality: sleepQuality,
            appetiteLevel: appetiteLevel,
            mood: mood,
            nausea: nausea,
            injectionSiteReaction: injectionSiteReaction,
            fatigue: fatigue,
            headache: headache,
            giIssues: giIssues,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func mock(
        date: Date,
        weightKg: Double?,
        energyLevel: Int?,
        mood: Int?
    ) -> Checkin {
        Checkin(
            id: UUID(),
            userId: UUID(),
            date: date,
            weightKg: weightKg,
            energyLevel: energyLevel,
            sleepQuality: nil,
            appetiteLevel: nil,
            mood: mood,
            nausea: nil,
            injectionSiteReaction: nil,
            fatigue: nil,
            headache: nil,
            giIssues: nil,
            notes: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }
}

private actor CheckinAsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}
