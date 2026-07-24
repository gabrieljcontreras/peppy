import SwiftUI
import UserNotifications
import XCTest
@testable import peppy

@MainActor
final class NotificationSettingsTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testDoseScheduleCalculatorUsesFixedIntervalsOnlyForDayBasedFrequencies() {
        let expected: [String: Int] = [
            "daily": 1,
            "every other day": 2,
            "weekly": 7,
            "once weekly": 7,
            "every 10 days": 10,
            "biweekly": 14,
        ]

        for (frequency, interval) in expected {
            XCTAssertEqual(
                DoseScheduleCalculator.intervalDays(for: frequency),
                interval,
                "Unexpected interval for \(frequency)"
            )
        }
        XCTAssertNil(DoseScheduleCalculator.intervalDays(for: "twice weekly"))
        XCTAssertNil(DoseScheduleCalculator.intervalDays(for: "monthly"))
        XCTAssertNil(DoseScheduleCalculator.intervalDays(for: "custom"))
    }

    func testDoseScheduleCalculatorAlternatesThreeAndFourDaysForTwiceWeekly() throws {
        let dates = DoseScheduleCalculator.upcomingDates(
            startingAt: try date("2026-07-01 00:00"),
            frequency: "twice weekly",
            localTime: DateComponents(hour: 9, minute: 0),
            after: try date("2026-06-30 00:00"),
            calendar: calendar,
            limit: 6
        )

        XCTAssertEqual(
            dates.map(Self.timestamp),
            [
                "2026-07-01 09:00",
                "2026-07-04 09:00",
                "2026-07-08 09:00",
                "2026-07-11 09:00",
                "2026-07-15 09:00",
                "2026-07-18 09:00",
            ]
        )
    }

    func testDoseScheduleCalculatorUsesCalendarMonthsAndClampsMonthEnd() throws {
        let dates = DoseScheduleCalculator.upcomingDates(
            startingAt: try date("2026-01-31 00:00"),
            frequency: "monthly",
            localTime: DateComponents(hour: 9, minute: 0),
            after: try date("2026-01-01 00:00"),
            calendar: calendar,
            limit: 4
        )

        XCTAssertEqual(
            dates.map(Self.timestamp),
            [
                "2026-01-31 09:00",
                "2026-02-28 09:00",
                "2026-03-31 09:00",
                "2026-04-30 09:00",
            ]
        )
    }

    func testDoseScheduleCalculatorAnchorsFutureDatesToProtocolStart() throws {
        let start = try date("2026-07-01 00:00")
        let now = try date("2026-07-08 09:01")

        let dates = DoseScheduleCalculator.upcomingDates(
            startingAt: start,
            frequency: "weekly",
            localTime: DateComponents(hour: 9, minute: 0),
            after: now,
            calendar: calendar,
            limit: 3
        )

        XCTAssertEqual(
            dates.map(Self.timestamp),
            ["2026-07-15 09:00", "2026-07-22 09:00", "2026-07-29 09:00"]
        )
    }

    func testDoseScheduleCalculatorPreservesUTCDateOnlyAnchorInWesternTimeZone() throws {
        var pacificCalendar = Calendar(identifier: .gregorian)
        pacificCalendar.locale = Locale(identifier: "en_US_POSIX")
        pacificCalendar.timeZone = try XCTUnwrap(
            TimeZone(identifier: "America/Los_Angeles")
        )
        let start = try date("2026-07-01 00:00")
        let now = try XCTUnwrap(
            pacificCalendar.date(
                from: DateComponents(
                    year: 2026,
                    month: 7,
                    day: 1,
                    hour: 8
                )
            )
        )

        let dates = DoseScheduleCalculator.upcomingDates(
            startingAt: start,
            frequency: "weekly",
            localTime: DateComponents(hour: 9, minute: 0),
            after: now,
            calendar: pacificCalendar,
            limit: 1
        )

        let scheduled = try XCTUnwrap(dates.first)
        let components = pacificCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: scheduled
        )
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 0)
    }

    func testSchedulerCapsDoseRequestsAtSixtyAndUsesStableIdentifiers() async throws {
        let now = try date("2026-07-08 08:00")
        let center = NotificationCenterSpy()
        let scheduler = LocalNotificationScheduler(
            center: center,
            calendar: calendar,
            now: { now }
        )
        let compoundID = UUID(uuidString: "A8CE2074-12DD-4D0E-AEDB-12245F66E7B6")!
        let activeProtocol = makeProtocol(
            startDate: try date("2026-07-01 00:00"),
            compoundID: compoundID,
            frequency: "daily"
        )

        try await scheduler.reconcile(
            preferences: makePreferences(
                doseEnabled: true,
                doseReminders: [
                    DoseReminderPreference(
                        compoundID: compoundID,
                        localTime: "09:00:00",
                        enabled: true
                    ),
                ]
            ),
            activeProtocol: activeProtocol
        )

        let doseRequests = center.requests.values.filter {
            $0.identifier.hasPrefix("peppy.settings.dose.")
        }
        XCTAssertEqual(doseRequests.count, 60)
        XCTAssertNotNil(
            center.requests[
                "peppy.settings.dose.a8ce2074-12dd-4d0e-aedb-12245f66e7b6.20260708"
            ]
        )
    }

    func testSchedulerRemovesOnlyObsoleteSettingsRequests() async throws {
        let now = try date("2026-07-08 08:00")
        let obsolete = request(identifier: "peppy.settings.dose.obsolete.20260701")
        let unrelated = request(identifier: "another.feature.notification")
        let center = NotificationCenterSpy(requests: [obsolete, unrelated])
        let scheduler = LocalNotificationScheduler(
            center: center,
            calendar: calendar,
            now: { now }
        )

        try await scheduler.reconcile(
            preferences: makePreferences(),
            activeProtocol: nil
        )

        XCTAssertNil(center.requests[obsolete.identifier])
        XCTAssertNotNil(center.requests[unrelated.identifier])
    }

    func testSchedulerUsesGenericCopyUntilDetailedPreviewsAreEnabled() async throws {
        let now = try date("2026-07-08 08:00")
        let compoundID = UUID(uuidString: "A8CE2074-12DD-4D0E-AEDB-12245F66E7B6")!
        let activeProtocol = makeProtocol(
            startDate: try date("2026-07-01 00:00"),
            compoundID: compoundID,
            frequency: "weekly"
        )
        let center = NotificationCenterSpy()
        let scheduler = LocalNotificationScheduler(
            center: center,
            calendar: calendar,
            now: { now }
        )

        try await scheduler.reconcile(
            preferences: makePreferences(
                doseEnabled: true,
                detailedPreviews: false,
                doseReminders: [
                    DoseReminderPreference(
                        compoundID: compoundID,
                        localTime: "09:00:00",
                        enabled: true
                    ),
                ]
            ),
            activeProtocol: activeProtocol
        )

        let generic = try XCTUnwrap(
            center.requests.values.first {
                $0.identifier.hasPrefix("peppy.settings.dose.")
            }
        )
        XCTAssertEqual(generic.content.title, "Peppy")
        XCTAssertEqual(generic.content.body, "You have a Peppy reminder")

        try await scheduler.reconcile(
            preferences: makePreferences(
                doseEnabled: true,
                detailedPreviews: true,
                doseReminders: [
                    DoseReminderPreference(
                        compoundID: compoundID,
                        localTime: "09:00:00",
                        enabled: true
                    ),
                ]
            ),
            activeProtocol: activeProtocol
        )

        let detailed = try XCTUnwrap(
            center.requests.values.first {
                $0.identifier.hasPrefix("peppy.settings.dose.")
            }
        )
        XCTAssertEqual(detailed.content.title, "Time for your Retatrutide dose")
        XCTAssertEqual(
            detailed.content.body,
            "Your 4 mg dose is scheduled for 9:00 AM."
        )
    }

    func testQuietHoursSuppressCheckinButNeverDoseReminders() async throws {
        let now = try date("2026-07-08 08:00")
        let compoundID = UUID(uuidString: "A8CE2074-12DD-4D0E-AEDB-12245F66E7B6")!
        let center = NotificationCenterSpy()
        let scheduler = LocalNotificationScheduler(
            center: center,
            calendar: calendar,
            now: { now }
        )

        try await scheduler.reconcile(
            preferences: makePreferences(
                doseEnabled: true,
                checkinEnabled: true,
                checkinTime: "23:00:00",
                quietStart: "22:00:00",
                quietEnd: "07:00:00",
                doseReminders: [
                    DoseReminderPreference(
                        compoundID: compoundID,
                        localTime: "23:30:00",
                        enabled: true
                    ),
                ]
            ),
            activeProtocol: makeProtocol(
                startDate: try date("2026-07-01 00:00"),
                compoundID: compoundID,
                frequency: "weekly"
            )
        )

        XCTAssertNil(center.requests["peppy.settings.checkin"])
        XCTAssertTrue(
            center.requests.keys.contains {
                $0.hasPrefix("peppy.settings.dose.")
            }
        )
    }

    func testDeniedPermissionPreservesAccountDraftAndServerConfirmedPreference() async {
        let api = MockAPIClient()
        let original = makePreferences()
        let confirmed = makePreferences(
            checkinEnabled: true,
            checkinTime: "20:00:00"
        )
        let store = SettingsStore(
            api: api,
            initialUser: makeUser(),
            cachedNotificationPreferences: original
        )
        api.setMockResponse(
            confirmed,
            for: .updateNotificationPreferences(
                makeRequest(
                    checkinEnabled: true,
                    checkinTime: "20:00:00"
                )
            )
        )
        let protocolStore = ProtocolStore(api: api)
        let permission = MockNotificationPermissionService(
            outcome: .denied,
            authorizationStatus: .denied
        )
        let scheduler = NotificationSchedulerSpy()
        let model = NotificationSettingsViewModel(
            store: store,
            protocolStore: protocolStore,
            permissionService: permission,
            scheduler: scheduler
        )

        await model.load()
        model.setDailyCheckinRemindersEnabled(true)
        await model.confirmDailyCheckinSetup(localTime: "20:00:00")

        XCTAssertTrue(model.draft.dailyCheckinRemindersEnabled)
        XCTAssertEqual(model.draft.dailyCheckinTime, "20:00:00")
        XCTAssertTrue(model.showsOpenSystemSettingsAction)

        let saved = await model.save()

        XCTAssertTrue(saved)
        XCTAssertEqual(store.notificationPreferences, confirmed)
        XCTAssertNil(scheduler.reconciledPreferences)
        XCTAssertTrue(scheduler.didRemoveSettingsRequests)
        XCTAssertTrue(model.showsOpenSystemSettingsAction)
    }

    func testPushRegistrationStoresAndReusesReturnedServerDeviceID() async {
        let api = MockAPIClient()
        let deviceID = UUID(uuidString: "FA886889-0300-4552-9ED5-662BF8F92AF2")!
        let device = DeviceToken(
            id: deviceID,
            platform: "ios",
            createdAt: Date(timeIntervalSince1970: 1_784_742_400)
        )
        api.setMockResponse(
            device,
            for: .registerDevice(token: "aabbccdd", platform: "ios")
        )
        let registrationStore = InMemoryPushRegistrationStore()
        let coordinator = PushRegistrationCoordinator(
            api: api,
            registrationStore: registrationStore,
            isSignedIn: { true }
        )

        await coordinator.receiveAPNSToken("aabbccdd")

        XCTAssertEqual(registrationStore.deviceID, deviceID)

        await coordinator.unregister()

        XCTAssertNil(registrationStore.deviceID)
        XCTAssertTrue(api.requestLog.contains { endpoint in
            if case .deleteDevice(id: deviceID) = endpoint { return true }
            return false
        })
    }

    func testLogoutWaitsForInFlightPushRegistrationAndDeletesReturnedDevice() async {
        let api = MockAPIClient()
        let deviceID = UUID(uuidString: "BC0B48F7-2EF5-4895-B48A-F559B665ED94")!
        api.setMockResponse(
            DeviceToken(
                id: deviceID,
                platform: "ios",
                createdAt: Date(timeIntervalSince1970: 1_784_742_400)
            ),
            for: .registerDevice(token: "aabbccdd", platform: "ios")
        )
        let registrationStarted = expectation(
            description: "registration request started"
        )
        var releaseRegistration: CheckedContinuation<Void, Never>?
        api.onRequest = { endpoint in
            guard case .registerDevice = endpoint else { return }
            registrationStarted.fulfill()
            await withCheckedContinuation { continuation in
                releaseRegistration = continuation
            }
        }
        let registrationStore = InMemoryPushRegistrationStore()
        let coordinator = PushRegistrationCoordinator(
            api: api,
            registrationStore: registrationStore,
            isSignedIn: { true }
        )

        let registration = Task {
            await coordinator.receiveAPNSToken("aabbccdd")
        }
        await fulfillment(of: [registrationStarted])

        let logout = Task {
            await coordinator.unregister()
        }
        await Task.yield()
        releaseRegistration?.resume()
        await registration.value
        await logout.value

        XCTAssertNil(registrationStore.deviceID)
        XCTAssertTrue(api.requestLog.contains { endpoint in
            if case .deleteDevice(id: deviceID) = endpoint { return true }
            return false
        })
    }

    func testSessionStartLoadsPreferencesAndProtocolsBeforeReconciliation() async throws {
        let api = MockAPIClient()
        let preferences = makePreferences(
            doseEnabled: true,
            doseReminders: [
                DoseReminderPreference(
                    compoundID: UUID(
                        uuidString: "A8CE2074-12DD-4D0E-AEDB-12245F66E7B6"
                    )!,
                    localTime: "09:00:00",
                    enabled: true
                ),
            ]
        )
        let activeProtocol = makeProtocol(
            startDate: try date("2026-07-01 00:00"),
            compoundID: preferences.doseReminders[0].compoundID,
            frequency: "weekly"
        )
        api.setMockError(.notFound, for: .getProfile)
        api.setMockResponse(preferences, for: .getNotificationPreferences)
        api.setMockResponse([activeProtocol], for: .getProtocols)
        let settingsStore = SettingsStore(
            api: api,
            initialUser: makeUser(timezone: "UTC")
        )
        let protocolStore = ProtocolStore(api: api)
        let scheduler = NotificationSchedulerSpy()
        let coordinator = NotificationReconciliationCoordinator(
            settingsStore: settingsStore,
            protocolStore: protocolStore,
            scheduler: scheduler,
            pushRegistration: PushRegistrationCoordinatorSpy(),
            permissionService: MockNotificationPermissionService(
                outcome: .authorized
            ),
            remoteNotificationRegistrar: RemoteNotificationRegistrarSpy(),
            timeZoneIdentifier: { "UTC" }
        )

        await coordinator.startSession()

        XCTAssertEqual(scheduler.reconciledPreferences, preferences)
        XCTAssertEqual(scheduler.reconciledProtocol, activeProtocol)
    }

    func testProtocolStoreResetPreventsCrossAccountProtocolReuse() async throws {
        let api = MockAPIClient()
        let activeProtocol = makeProtocol(
            startDate: try date("2026-07-01 00:00"),
            compoundID: UUID(
                uuidString: "A8CE2074-12DD-4D0E-AEDB-12245F66E7B6"
            )!,
            frequency: "weekly"
        )
        api.setMockResponse([activeProtocol], for: .getProtocols)
        let store = ProtocolStore(api: api)

        await store.loadProtocols()
        XCTAssertEqual(store.protocols, [activeProtocol])

        store.resetSession()

        XCTAssertTrue(store.protocols.isEmpty)
        XCTAssertNil(store.selectedProtocol)
        XCTAssertTrue(store.doseLogs.isEmpty)
    }

    func testNotificationViewModelLoadsServerPreferencesBeforeEditing() async {
        let api = MockAPIClient()
        let confirmed = makePreferences(insightsEnabled: false)
        api.setMockError(.notFound, for: .getProfile)
        api.setMockResponse(confirmed, for: .getNotificationPreferences)
        api.setMockResponse([ProtocolModel](), for: .getProtocols)
        let model = NotificationSettingsViewModel(
            store: SettingsStore(
                api: api,
                initialUser: makeUser()
            ),
            protocolStore: ProtocolStore(api: api),
            permissionService: MockNotificationPermissionService(
                outcome: .authorized
            ),
            scheduler: NotificationSchedulerSpy()
        )

        XCTAssertTrue(model.isLoading)
        model.setInsightsEnabled(false)
        XCTAssertTrue(model.draft.insightsEnabled)

        await model.load()

        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.draft, NotificationSettingsDraft(preferences: confirmed))
        XCTAssertFalse(model.hasUnsavedChanges)
    }

    func testInsightsOnlyEnableRequestsPermissionAndRegistersForRemoteNotifications() async {
        let api = MockAPIClient()
        let original = makePreferences(insightsEnabled: false)
        let confirmed = makePreferences(insightsEnabled: true)
        api.setMockResponse([ProtocolModel](), for: .getProtocols)
        api.setMockResponse(
            confirmed,
            for: .updateNotificationPreferences(makeRequest())
        )
        let updateStarted = expectation(
            description: "notification preference update started"
        )
        var releaseUpdate: CheckedContinuation<Void, Never>?
        api.onRequest = { endpoint in
            guard case .updateNotificationPreferences = endpoint else {
                return
            }
            updateStarted.fulfill()
            await withCheckedContinuation { continuation in
                releaseUpdate = continuation
            }
        }
        let permission = MockNotificationPermissionService(
            outcome: .authorized,
            authorizationStatus: .notDetermined
        )
        var registrationCount = 0
        let model = NotificationSettingsViewModel(
            store: SettingsStore(
                api: api,
                initialUser: makeUser(),
                cachedNotificationPreferences: original
            ),
            protocolStore: ProtocolStore(api: api),
            permissionService: permission,
            scheduler: NotificationSchedulerSpy(),
            registerForRemoteNotifications: {
                registrationCount += 1
            }
        )

        await model.load()
        model.setInsightsEnabled(true)
        let save = Task {
            await model.save()
        }
        await fulfillment(of: [updateStarted])

        XCTAssertEqual(permission.status, .notDetermined)
        XCTAssertEqual(registrationCount, 0)

        releaseUpdate?.resume()
        let saved = await save.value

        XCTAssertTrue(saved)
        XCTAssertEqual(permission.status, .authorized)
        XCTAssertEqual(registrationCount, 1)
        XCTAssertNil(model.activeSetup)
    }

    func testDoseSetupKeepsDisabledCompoundRowsAndTheirTimes() {
        let firstID = UUID(uuidString: "A8CE2074-12DD-4D0E-AEDB-12245F66E7B6")!
        let secondID = UUID(uuidString: "D433EA4E-C29E-47A1-A7B3-7360DF7232ED")!
        let compounds = [
            makeCompound(id: firstID, name: "Retatrutide"),
            makeCompound(id: secondID, name: "BPC-157"),
        ]
        let firstTime = Calendar.current.date(
            from: DateComponents(
                year: 2000,
                month: 1,
                day: 1,
                hour: 9
            )
        )!
        let secondTime = Calendar.current.date(
            from: DateComponents(
                year: 2000,
                month: 1,
                day: 1,
                hour: 20,
                minute: 30
            )
        )!

        let reminders = DoseReminderSetupState.reminders(
            compounds: compounds,
            enabledCompoundIDs: [firstID],
            reminderTimes: [
                firstID: firstTime,
                secondID: secondTime,
            ]
        )

        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(reminders[0].localTime, "09:00:00")
        XCTAssertTrue(reminders[0].enabled)
        XCTAssertEqual(reminders[1].localTime, "20:30:00")
        XCTAssertFalse(reminders[1].enabled)
    }

    func testLifecycleReconciliationReschedulesAndSyncsChangedTimeZone() async {
        let api = MockAPIClient()
        let currentUser = makeUser(timezone: "UTC")
        let confirmedUser = makeUser(timezone: "America/New_York")
        let preferences = makePreferences(
            checkinEnabled: true,
            checkinTime: "20:00:00"
        )
        let store = SettingsStore(
            api: api,
            initialUser: currentUser,
            cachedNotificationPreferences: preferences
        )
        api.setMockResponse(
            confirmedUser,
            for: .updateCurrentUser(
                .init(displayName: nil, timezone: "America/New_York")
            )
        )
        let scheduler = NotificationSchedulerSpy()
        let push = PushRegistrationCoordinatorSpy()
        let remoteRegistration = RemoteNotificationRegistrarSpy()
        let coordinator = NotificationReconciliationCoordinator(
            settingsStore: store,
            protocolStore: ProtocolStore(api: api),
            scheduler: scheduler,
            pushRegistration: push,
            permissionService: MockNotificationPermissionService(
                outcome: .authorized
            ),
            remoteNotificationRegistrar: remoteRegistration,
            timeZoneIdentifier: { "America/New_York" }
        )

        await coordinator.reconcile()

        XCTAssertEqual(scheduler.reconciledPreferences, preferences)
        XCTAssertEqual(store.user?.timezone, "America/New_York")
        XCTAssertEqual(push.registerPendingTokenCallCount, 1)
        XCTAssertEqual(remoteRegistration.callCount, 1)
        XCTAssertTrue(api.requestLog.contains { endpoint in
            guard case .updateCurrentUser(let request) = endpoint else {
                return false
            }
            return request == .init(
                displayName: nil,
                timezone: "America/New_York"
            )
        })
    }

    func testSessionResetRemovesLocalRequestsAndUnregistersDevice() async {
        let api = MockAPIClient()
        let scheduler = NotificationSchedulerSpy()
        let push = PushRegistrationCoordinatorSpy()
        let coordinator = NotificationReconciliationCoordinator(
            settingsStore: SettingsStore(api: api),
            protocolStore: ProtocolStore(api: api),
            scheduler: scheduler,
            pushRegistration: push
        )

        await coordinator.resetSession()

        XCTAssertTrue(scheduler.didRemoveSettingsRequests)
        XCTAssertEqual(push.unregisterCallCount, 1)
    }

    func testNotificationScreenPreservesFigmaGeometryAndAccessibleTapTargets() {
        XCTAssertEqual(NotificationSettingsFigmaLayout.referenceCanvasWidth, 853)
        XCTAssertEqual(NotificationSettingsFigmaLayout.referenceCanvasHeight, 1_844)
        XCTAssertEqual(NotificationSettingsFigmaLayout.horizontalPadding, 22)
        XCTAssertGreaterThanOrEqual(NotificationSettingsFigmaLayout.minimumTapTarget, 44)
        XCTAssertNil(
            NotificationSettingsPresentation.lineLimit(for: .accessibility1)
        )
    }

    private func date(_ value: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return try XCTUnwrap(formatter.date(from: value))
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func makeUser(timezone: String? = nil) -> User {
        User(
            id: UUID(uuidString: "B95BB392-4761-496D-9C0E-FF80B358C7C7")!,
            email: "alex.morgan@example.com",
            displayName: "Alex Morgan",
            isVerified: true,
            timezone: timezone
        )
    }

    private func makeProtocol(
        startDate: Date,
        compoundID: UUID,
        frequency: String
    ) -> ProtocolModel {
        ProtocolModel(
            id: UUID(uuidString: "E25A07EB-25E7-4CA7-BE28-DF09DDDCF982")!,
            name: "Retatrutide Titration",
            startDate: startDate,
            endDate: nil,
            notes: nil,
            isActive: true,
            setupStatus: "active",
            isStarter: false,
            compounds: [
                Compound(
                    id: compoundID,
                    name: "Retatrutide",
                    doseMg: 4,
                    doseUnit: "mg",
                    frequency: frequency,
                    administrationRoute: "subcutaneous",
                    notes: nil
                ),
            ]
        )
    }

    private func makeCompound(id: UUID, name: String) -> Compound {
        Compound(
            id: id,
            name: name,
            doseMg: 4,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            notes: nil
        )
    }

    private func makePreferences(
        insightsEnabled: Bool = true,
        doseEnabled: Bool = false,
        checkinEnabled: Bool = false,
        checkinTime: String? = nil,
        detailedPreviews: Bool = false,
        quietStart: String? = nil,
        quietEnd: String? = nil,
        doseReminders: [DoseReminderPreference] = []
    ) -> NotificationPreferences {
        NotificationPreferences(
            id: UUID(uuidString: "7BCE24BB-54D5-4EC4-A157-C46B05D3043A")!,
            insightsEnabled: insightsEnabled,
            alertSeverityOnly: false,
            doseRemindersEnabled: doseEnabled,
            dailyCheckinRemindersEnabled: checkinEnabled,
            dailyCheckinTime: checkinTime,
            detailedPreviewsEnabled: detailedPreviews,
            quietHoursStart: quietStart,
            quietHoursEnd: quietEnd,
            doseReminders: doseReminders
        )
    }

    private func makeRequest(
        doseEnabled: Bool = false,
        checkinEnabled: Bool = false,
        checkinTime: String? = nil,
        detailedPreviews: Bool = false,
        quietStart: String? = nil,
        quietEnd: String? = nil,
        doseReminders: [DoseReminderPreference] = []
    ) -> UpdateNotificationPreferencesRequest {
        UpdateNotificationPreferencesRequest(
            insightsEnabled: true,
            alertSeverityOnly: false,
            doseRemindersEnabled: doseEnabled,
            dailyCheckinRemindersEnabled: checkinEnabled,
            dailyCheckinTime: checkinTime,
            detailedPreviewsEnabled: detailedPreviews,
            quietHoursStart: quietStart,
            quietHoursEnd: quietEnd,
            doseReminders: doseReminders
        )
    }

    private func request(identifier: String) -> UNNotificationRequest {
        UNNotificationRequest(
            identifier: identifier,
            content: UNMutableNotificationContent(),
            trigger: nil
        )
    }
}

@MainActor
private final class NotificationCenterSpy: UserNotificationCenterScheduling {
    private(set) var requests: [String: UNNotificationRequest]

    init(requests: [UNNotificationRequest] = []) {
        self.requests = Dictionary(
            uniqueKeysWithValues: requests.map { ($0.identifier, $0) }
        )
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        Array(requests.values)
    }

    func add(_ request: UNNotificationRequest) async throws {
        requests[request.identifier] = request
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        identifiers.forEach { requests[$0] = nil }
    }
}

@MainActor
private final class NotificationSchedulerSpy: LocalNotificationScheduling {
    private(set) var reconciledPreferences: NotificationPreferences?
    private(set) var reconciledProtocol: ProtocolModel?
    private(set) var didRemoveSettingsRequests = false

    func reconcile(
        preferences: NotificationPreferences,
        activeProtocol: ProtocolModel?
    ) async throws {
        reconciledPreferences = preferences
        reconciledProtocol = activeProtocol
    }

    func removeSettingsRequests() async {
        didRemoveSettingsRequests = true
    }
}

@MainActor
private final class InMemoryPushRegistrationStore: PushRegistrationStoring {
    var deviceID: UUID?
}

@MainActor
private final class PushRegistrationCoordinatorSpy: PushRegistrationCoordinating {
    private(set) var registerPendingTokenCallCount = 0
    private(set) var unregisterCallCount = 0

    func registerPendingTokenIfPossible() async {
        registerPendingTokenCallCount += 1
    }

    func unregister() async {
        unregisterCallCount += 1
    }
}

@MainActor
private final class RemoteNotificationRegistrarSpy: RemoteNotificationRegistering {
    private(set) var callCount = 0

    func registerForRemoteNotifications() {
        callCount += 1
    }
}
