import XCTest
@testable import peppy

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testRefreshFailurePreservesConfirmedSettings() async {
        let api = MockAPIClient()
        let user = makeUser()
        let cachedProfile = makeProfile()
        let cachedPreferences = makePreferences()
        let store = SettingsStore(
            api: api,
            initialUser: user,
            cachedProfile: cachedProfile,
            cachedNotificationPreferences: cachedPreferences
        )
        api.setMockError(.serverError, for: .getProfile)
        api.setMockResponse(cachedPreferences, for: .getNotificationPreferences)

        await store.refresh()

        XCTAssertEqual(store.profile, cachedProfile)
        XCTAssertEqual(store.notificationPreferences, cachedPreferences)
        XCTAssertEqual(store.refreshError, .serverError)
    }

    func testRefreshReconcilesSuccessfulResourceWhenOtherResourceFails() async {
        let api = MockAPIClient()
        let cachedProfile = makeProfile(primaryGoal: "track_protocols")
        let cachedPreferences = makePreferences(insightsEnabled: false)
        let refreshedPreferences = makePreferences(insightsEnabled: true)
        let store = SettingsStore(
            api: api,
            initialUser: makeUser(),
            cachedProfile: cachedProfile,
            cachedNotificationPreferences: cachedPreferences
        )
        api.setMockError(.networkUnavailable, for: .getProfile)
        api.setMockResponse(refreshedPreferences, for: .getNotificationPreferences)

        await store.refresh()

        XCTAssertEqual(store.profile, cachedProfile)
        XCTAssertEqual(store.notificationPreferences, refreshedPreferences)
        XCTAssertEqual(store.refreshError, .networkUnavailable)
    }

    func testProfileNotFoundCreatesEmptyEditableProfileWithoutRefreshError() async throws {
        let api = MockAPIClient()
        let user = makeUser()
        let preferences = makePreferences()
        let store = SettingsStore(api: api, initialUser: user)
        api.setMockError(.notFound, for: .getProfile)
        api.setMockResponse(preferences, for: .getNotificationPreferences)

        await store.refresh()

        let profile = try XCTUnwrap(store.profile)
        XCTAssertEqual(profile.id, user.id)
        XCTAssertEqual(profile.schemaVersion, 1)
        XCTAssertNil(profile.heightCm)
        XCTAssertNil(profile.primaryGoal)
        XCTAssertEqual(store.notificationPreferences, preferences)
        XCTAssertNil(store.refreshError)
    }

    func testSuccessfulProfileMutationReconcilesOnlyConfirmedResponses() async throws {
        let api = MockAPIClient()
        let originalUser = makeUser(displayName: "Alex Morgan")
        let originalProfile = makeProfile(primaryGoal: "track_protocols")
        let confirmedUser = makeUser(displayName: "Alex Taylor")
        let confirmedProfile = makeProfile(primaryGoal: "feel_in_control")
        let store = SettingsStore(
            api: api,
            initialUser: originalUser,
            cachedProfile: originalProfile
        )
        let userRequest = UpdateCurrentUserRequest(displayName: "Alex Taylor", timezone: nil)
        let profileRequest = makeProfileRequest(primaryGoal: "feel_in_control")
        api.setMockResponse(confirmedUser, for: .updateCurrentUser(userRequest))
        api.setMockResponse(confirmedProfile, for: .updateProfile(profileRequest))

        try await store.updateProfile(user: userRequest, profile: profileRequest)

        XCTAssertEqual(store.user?.displayName, "Alex Taylor")
        XCTAssertEqual(store.profile, confirmedProfile)
    }

    func testFailedProfileMutationPreservesBothConfirmedCaches() async {
        let api = MockAPIClient()
        let originalUser = makeUser(displayName: "Alex Morgan")
        let originalProfile = makeProfile(primaryGoal: "track_protocols")
        let serverUser = makeUser(displayName: "Alex Taylor")
        let store = SettingsStore(
            api: api,
            initialUser: originalUser,
            cachedProfile: originalProfile
        )
        let userRequest = UpdateCurrentUserRequest(displayName: "Alex Taylor", timezone: nil)
        let profileRequest = makeProfileRequest(primaryGoal: "feel_in_control")
        api.setMockResponse(serverUser, for: .updateCurrentUser(userRequest))
        api.setMockError(.serverError, for: .updateProfile(profileRequest))

        do {
            try await store.updateProfile(user: userRequest, profile: profileRequest)
            XCTFail("Expected the profile mutation to fail")
        } catch {
            XCTAssertEqual(error as? APIError, .serverError)
        }

        XCTAssertEqual(store.user?.displayName, "Alex Morgan")
        XCTAssertEqual(store.profile, originalProfile)
    }

    func testNotificationMutationReplacesCacheWithServerResponse() async throws {
        let api = MockAPIClient()
        let original = makePreferences(insightsEnabled: false)
        let confirmed = makePreferences(insightsEnabled: true)
        let request = makeNotificationRequest(insightsEnabled: true)
        let store = SettingsStore(
            api: api,
            initialUser: makeUser(),
            cachedNotificationPreferences: original
        )
        api.setMockResponse(confirmed, for: .updateNotificationPreferences(request))

        try await store.updateNotifications(request)

        XCTAssertEqual(store.notificationPreferences, confirmed)
    }

    func testRefreshDoesNotInvalidateInFlightNotificationMutation() async throws {
        let api = MockAPIClient()
        let mutationGate = SettingsAsyncGate()
        let mutationStarted = expectation(description: "Notification mutation started")
        let original = makePreferences(insightsEnabled: false)
        let confirmed = makePreferences(insightsEnabled: true)
        let request = makeNotificationRequest(insightsEnabled: true)
        let store = SettingsStore(
            api: api,
            initialUser: makeUser(),
            cachedProfile: makeProfile(),
            cachedNotificationPreferences: original
        )
        api.setMockResponse(confirmed, for: .updateNotificationPreferences(request))
        api.setMockResponse(makeProfile(), for: .getProfile)
        api.setMockResponse(original, for: .getNotificationPreferences)
        api.onRequest = { endpoint in
            if case .updateNotificationPreferences = endpoint {
                mutationStarted.fulfill()
                await mutationGate.wait()
            }
        }

        let mutation = Task {
            try await store.updateNotifications(request)
        }
        await fulfillment(of: [mutationStarted], timeout: 1)

        await store.refresh()
        await mutationGate.open()
        try await mutation.value

        XCTAssertEqual(store.notificationPreferences, confirmed)
    }

    func testProfileMutationStopsBeforeProfileRequestAfterSessionChanges() async {
        let api = MockAPIClient()
        let firstRequestGate = SettingsAsyncGate()
        let firstRequestStarted = expectation(description: "User mutation started")
        let originalUser = makeUser(displayName: "Alex Morgan")
        let confirmedUser = makeUser(displayName: "Alex Taylor")
        let replacementUser = makeUser(
            id: UUID(uuidString: "F7BC57D8-2051-4D50-B486-5FB2F1657992")!,
            displayName: "Jordan Lee"
        )
        let userRequest = UpdateCurrentUserRequest(displayName: "Alex Taylor", timezone: nil)
        let profileRequest = makeProfileRequest(primaryGoal: "feel_in_control")
        let store = SettingsStore(
            api: api,
            initialUser: originalUser,
            cachedProfile: makeProfile()
        )
        api.setMockResponse(confirmedUser, for: .updateCurrentUser(userRequest))
        api.setMockResponse(
            makeProfile(primaryGoal: "feel_in_control"),
            for: .updateProfile(profileRequest)
        )
        api.onRequest = { endpoint in
            if case .updateCurrentUser = endpoint {
                firstRequestStarted.fulfill()
                await firstRequestGate.wait()
            }
        }

        let mutation = Task {
            try await store.updateProfile(user: userRequest, profile: profileRequest)
        }
        await fulfillment(of: [firstRequestStarted], timeout: 1)

        store.beginSession(user: replacementUser)
        await firstRequestGate.open()

        do {
            try await mutation.value
            XCTFail("Expected the prior session mutation to be rejected")
        } catch {
            XCTAssertEqual(error as? APIError, .unauthorized)
        }

        XCTAssertEqual(store.user?.id, replacementUser.id)
        XCTAssertFalse(api.requestLog.contains { endpoint in
            if case .updateProfile = endpoint { return true }
            return false
        })
    }

    func testResetSessionInvalidatesConcurrentRefreshResponses() async {
        let api = MockAPIClient()
        let gate = SettingsAsyncGate()
        let requestsStarted = expectation(description: "Both settings requests started")
        requestsStarted.expectedFulfillmentCount = 2
        api.onRequest = { _ in
            requestsStarted.fulfill()
            await gate.wait()
        }
        api.setMockResponse(makeProfile(), for: .getProfile)
        api.setMockResponse(makePreferences(), for: .getNotificationPreferences)
        let store = SettingsStore(api: api, initialUser: makeUser())

        let refresh = Task { await store.refresh() }
        await fulfillment(of: [requestsStarted], timeout: 1)
        store.resetSession()
        await gate.open()
        await refresh.value

        XCTAssertNil(store.user)
        XCTAssertNil(store.profile)
        XCTAssertNil(store.notificationPreferences)
        XCTAssertNil(store.refreshError)
        XCTAssertFalse(store.isRefreshing)
    }

    func testDependenciesSeedAndResetSettingsStoreWithAuthenticationSession() async {
        let dependencies = Dependencies.mock()
        let user = makeUser(displayName: "Session User")

        await dependencies.flow.didAuthenticate(user: user)

        XCTAssertEqual(dependencies.settingsStore.user?.id, user.id)

        await dependencies.flow.logout()

        XCTAssertNil(dependencies.settingsStore.user)
        XCTAssertNil(dependencies.settingsStore.profile)
        XCTAssertNil(dependencies.settingsStore.notificationPreferences)
    }
}

private extension SettingsStoreTests {
    func makeUser(
        id: UUID = UUID(uuidString: "B95BB392-4761-496D-9C0E-FF80B358C7C7")!,
        displayName: String = "Alex Morgan"
    ) -> User {
        User(
            id: id,
            email: "alex.morgan@example.com",
            displayName: displayName,
            isVerified: true
        )
    }

    func makeProfile(primaryGoal: String? = "track_protocols") -> AccountProfile {
        AccountProfile(
            id: UUID(uuidString: "B95BB392-4761-496D-9C0E-FF80B358C7C7")!,
            schemaVersion: 1,
            heightCm: 180,
            preferredHeightUnit: "cm",
            weightKg: 82,
            preferredWeightUnit: "kg",
            baselineDate: APIDateOnly.date(from: "2026-07-20"),
            primaryGoal: primaryGoal,
            secondaryGoal: nil,
            focusArea: nil
        )
    }

    func makePreferences(insightsEnabled: Bool = true) -> NotificationPreferences {
        NotificationPreferences(
            id: UUID(uuidString: "7BCE24BB-54D5-4EC4-A157-C46B05D3043A")!,
            insightsEnabled: insightsEnabled,
            alertSeverityOnly: false,
            doseRemindersEnabled: false,
            dailyCheckinRemindersEnabled: false,
            dailyCheckinTime: nil,
            detailedPreviewsEnabled: false,
            quietHoursStart: nil,
            quietHoursEnd: nil,
            doseReminders: []
        )
    }

    func makeProfileRequest(primaryGoal: String) -> ProfileUpdateRequest {
        ProfileUpdateRequest(
            schemaVersion: 1,
            heightCm: 180,
            preferredHeightUnit: "cm",
            weightKg: 82,
            preferredWeightUnit: "kg",
            baselineDate: APIDateOnly.date(from: "2026-07-20"),
            primaryGoal: primaryGoal,
            secondaryGoal: nil,
            focusArea: nil
        )
    }

    func makeNotificationRequest(
        insightsEnabled: Bool
    ) -> UpdateNotificationPreferencesRequest {
        UpdateNotificationPreferencesRequest(
            insightsEnabled: insightsEnabled,
            alertSeverityOnly: false,
            doseRemindersEnabled: false,
            dailyCheckinRemindersEnabled: false,
            dailyCheckinTime: nil,
            detailedPreviewsEnabled: false,
            quietHoursStart: nil,
            quietHoursEnd: nil,
            doseReminders: []
        )
    }
}

private actor SettingsAsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let currentWaiters = waiters
        waiters.removeAll()
        currentWaiters.forEach { $0.resume() }
    }
}
