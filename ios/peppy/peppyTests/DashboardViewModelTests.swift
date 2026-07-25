import XCTest
@testable import peppy

@MainActor
final class DashboardViewModelTests: XCTestCase {
    func testLoadDashboardSummaryShowsLoadedState() async {
        let api = MockAPIClient()
        let summary = DashboardSummary.mockPendingStarter
        api.setMockResponse(summary, for: "/dashboard/summary")
        let model = DashboardViewModel(api: api, hasProfileAttachFailure: false)

        await model.load()

        XCTAssertEqual(model.state.summary?.protocol.status, "pending_setup")
        XCTAssertFalse(model.state.isLoading)
        XCTAssertNil(model.state.errorMessage)
    }

    func testProfileAttachFailureShowsSyncRecoveryCard() async {
        let api = MockAPIClient()
        api.setMockResponse(DashboardSummary.mockMissingProfile, for: "/dashboard/summary")
        let model = DashboardViewModel(api: api, hasProfileAttachFailure: true)

        await model.load()

        XCTAssertTrue(model.state.showsProfileSyncRecovery)
    }

    func testPendingStarterSummaryPrefersFinishSetupAction() async {
        let api = MockAPIClient()
        api.setMockResponse(DashboardSummary.mockPendingStarter, for: "/dashboard/summary")
        let model = DashboardViewModel(api: api, hasProfileAttachFailure: false)

        await model.load()

        XCTAssertEqual(model.state.summary?.protocol.status, "pending_setup")
        XCTAssertEqual(model.state.summary?.protocol.title, "Starter protocol")
    }

    func testDashboardPreviewUsesTodayValuesAndPreferredUnit() async {
        let fixture = DashboardCheckinFixture()
        let today = Checkin.fixture(weightKg: 74.8, energyLevel: 7, mood: 8, nausea: 1)
        fixture.api.setMockResponse(DashboardSummary.mockPendingStarter, for: Endpoint.getDashboardSummary)
        fixture.api.setMockResponse([today], for: Endpoint.getCheckins(startDate: nil, endDate: nil))

        await fixture.model.load()

        XCTAssertEqual(fixture.model.todayPreview?.highlights, ["164.9 lb", "Energy 7", "Mood 8"])
        XCTAssertEqual(fixture.model.checkinRoute, .detail(today.id))
    }

    func testDashboardPreviewReflectsPostLoadKilogramSelection() async {
        let fixture = DashboardCheckinFixture()
        let today = Checkin.fixture(weightKg: 74.8, energyLevel: 7)
        fixture.api.setMockResponse(
            DashboardSummary.mockPendingStarter,
            for: Endpoint.getDashboardSummary
        )
        fixture.api.setMockResponse(
            [today],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        await fixture.model.load()

        fixture.preferences.select(.kilograms)

        XCTAssertEqual(fixture.model.todayPreview?.highlights, ["74.8 kg", "Energy 7"])
    }

    func testSavedCheckinAccessibilitySummaryIncludesVisibleHighlights() async throws {
        let fixture = DashboardCheckinFixture()
        let today = Checkin.fixture(weightKg: 74.8, energyLevel: 7, mood: 8)
        fixture.api.setMockResponse(
            DashboardSummary.mockPendingStarter,
            for: Endpoint.getDashboardSummary
        )
        fixture.api.setMockResponse(
            [today],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        await fixture.model.load()

        let preview = try XCTUnwrap(fixture.model.todayPreview)

        XCTAssertEqual(
            preview.accessibilitySummary,
            "View full check-in. Today's check-in is saved. 164.9 lb. Energy 7. Mood 8."
        )
    }

    func testDashboardPreviewFallsBackToSymptoms() async {
        let fixture = DashboardCheckinFixture()
        let symptoms = Checkin.fixture(nausea: 2, fatigue: 3)
        fixture.api.setMockResponse(DashboardSummary.mockPendingStarter, for: Endpoint.getDashboardSummary)
        fixture.api.setMockResponse([symptoms], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        await fixture.model.load()
        XCTAssertEqual(fixture.model.todayPreview?.highlights, ["2 symptoms logged"])
    }

    func testDashboardPreviewFallsBackToNotes() async {
        let fixture = DashboardCheckinFixture()
        let notesOnly = Checkin.fixture(notes: "Felt steady")
        fixture.api.setMockResponse(DashboardSummary.mockPendingStarter, for: Endpoint.getDashboardSummary)
        fixture.api.setMockResponse([notesOnly], for: Endpoint.getCheckins(startDate: nil, endDate: nil))

        await fixture.model.load()

        XCTAssertEqual(fixture.model.todayPreview?.highlights, ["Notes added"])
    }

    func testDashboardWithoutTodayRoutesToCreate() async {
        let fixture = DashboardCheckinFixture()
        fixture.api.setMockResponse(DashboardSummary.mockMissingProfile, for: Endpoint.getDashboardSummary)
        fixture.api.setMockResponse([Checkin](), for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        await fixture.model.load()
        XCTAssertEqual(fixture.model.checkinRoute, .create)
    }

    func testSuccessfulCheckinMutationTriggersDashboardSummaryRefresh() async {
        let fixture = DashboardCheckinFixture()
        fixture.api.setMockResponse(DashboardSummary.mockMissingProfile, for: Endpoint.getDashboardSummary)
        fixture.api.setMockResponse([Checkin](), for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        await fixture.model.load()
        let created = Checkin.fixture()
        fixture.api.setMockResponse(created, for: Endpoint.createCheckin(.fixture))
        _ = await fixture.store.create(.fixture)

        await fixture.model.refreshIfCheckinStateChanged()

        XCTAssertEqual(fixture.dashboardLoadCount, 2)
    }

    func testCheckinRefreshFailurePreservesPreviouslyLoadedSummaryAndRoute() async {
        let fixture = DashboardCheckinFixture()
        let checkinID = UUID()
        let summary = DashboardSummary(
            generatedAt: DashboardSummary.mockPendingStarter.generatedAt,
            profileStatus: DashboardSummary.mockPendingStarter.profileStatus,
            protocol: DashboardSummary.mockPendingStarter.protocol,
            todayCheckin: DashboardTodayCheckin(logged: true, checkinId: checkinID),
            responseSnapshot: DashboardSummary.mockPendingStarter.responseSnapshot,
            insight: DashboardSummary.mockPendingStarter.insight,
            connectedContext: DashboardSummary.mockPendingStarter.connectedContext
        )
        fixture.api.setMockResponse(summary, for: Endpoint.getDashboardSummary)
        fixture.api.setMockResponse([Checkin](), for: Endpoint.getCheckins(startDate: nil, endDate: nil))
        await fixture.model.load()
        XCTAssertEqual(fixture.model.checkinRoute, .detail(checkinID))

        let historical = Checkin.fixture(date: fixture.now.addingTimeInterval(-86_400))
        fixture.api.setMockResponse(historical, for: Endpoint.createCheckin(.fixture))
        let created = await fixture.store.create(.fixture)
        XCTAssertNotNil(created)
        XCTAssertNil(fixture.store.today)
        fixture.api.setMockError(.serverError, for: Endpoint.getDashboardSummary)

        await fixture.model.refreshIfCheckinStateChanged()

        XCTAssertEqual(fixture.model.state.summary, summary)
        XCTAssertEqual(fixture.model.checkinRoute, .detail(checkinID))
        XCTAssertEqual(fixture.model.state.errorMessage, APIError.serverError.userMessage)
    }

    func testDashboardFailureUsesActiveProtocolFromStore() async {
        let api = MockAPIClient()
        api.setMockError(.serverError, for: Endpoint.getDashboardSummary)
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let store = ProtocolStore(api: api)
        let model = DashboardViewModel(
            api: api,
            protocolStore: store,
            hasProfileAttachFailure: false
        )

        await model.load()

        XCTAssertEqual(model.state.summary?.protocol.id, ProtocolModel.fixture.id)
        XCTAssertEqual(model.state.summary?.protocol.status, "active")
        XCTAssertEqual(model.state.summary?.protocol.title, ProtocolModel.fixture.name)
        XCTAssertEqual(
            model.state.summary?.protocol.compounds,
            ProtocolModel.fixture.compounds.map(\.name)
        )
    }

    func testMissingDashboardSummaryUsesActiveProtocolFromStore() async {
        let api = MockAPIClient()
        api.setMockResponse(DashboardSummary.mockMissingProfile, for: Endpoint.getDashboardSummary)
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let store = ProtocolStore(api: api)
        let model = DashboardViewModel(
            api: api,
            protocolStore: store,
            hasProfileAttachFailure: false
        )

        await model.load()

        XCTAssertEqual(model.state.summary?.protocol.id, ProtocolModel.fixture.id)
        XCTAssertEqual(model.state.summary?.protocol.status, "active")
        XCTAssertEqual(model.state.summary?.protocol.title, ProtocolModel.fixture.name)
    }

    func testMissingDashboardSummaryRefreshesPreviouslyEmptyProtocolStore() async {
        let api = MockAPIClient()
        api.setMockResponse([ProtocolModel](), for: Endpoint.getProtocols)
        let store = ProtocolStore(api: api)
        await store.loadProtocols()

        api.setMockResponse(DashboardSummary.mockMissingProfile, for: Endpoint.getDashboardSummary)
        api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
        let model = DashboardViewModel(
            api: api,
            protocolStore: store,
            hasProfileAttachFailure: false
        )

        await model.load()

        XCTAssertEqual(model.state.summary?.protocol.id, ProtocolModel.fixture.id)
        XCTAssertEqual(model.state.summary?.protocol.status, "active")
    }

    // MARK: - Protocol card presentation

    func testInactiveSummaryPresentsPastProtocolCard() {
        let summary = DashboardProtocolSummary(
            id: UUID(),
            status: "inactive",
            title: "Retatrutide Titration",
            compounds: ["Retatrutide"]
        )

        XCTAssertEqual(summary.cardTitle, "Past protocol")
        XCTAssertEqual(summary.badgeText, "Inactive")
        XCTAssertEqual(summary.badgeType, .neutral)
        XCTAssertEqual(summary.actionTitle, "View protocol")
    }

    func testActiveSummaryPresentsActiveProtocolCard() {
        let summary = DashboardProtocolSummary(
            id: UUID(),
            status: "active",
            title: "Retatrutide Titration",
            compounds: ["Retatrutide"]
        )

        XCTAssertEqual(summary.cardTitle, "Active protocol")
        XCTAssertEqual(summary.badgeText, "Active")
        XCTAssertEqual(summary.badgeType, .success)
        XCTAssertEqual(summary.actionTitle, "View protocol")
    }

    func testMissingSummaryPresentsCreateProtocolCard() {
        let summary = DashboardSummary.mockMissingProfile.protocol

        XCTAssertEqual(summary.cardTitle, "Protocol")
        XCTAssertEqual(summary.badgeText, "Not started")
        XCTAssertEqual(summary.badgeType, .neutral)
        XCTAssertEqual(summary.actionTitle, "Create protocol")
    }

    func testPendingSetupSummaryPresentsStarterCard() {
        let summary = DashboardSummary.mockPendingStarter.protocol

        XCTAssertEqual(summary.cardTitle, "Starter protocol")
        XCTAssertEqual(summary.badgeText, "Needs setup")
        XCTAssertEqual(summary.badgeType, .warning)
        XCTAssertEqual(summary.actionTitle, "Finish setup")
    }
}

@MainActor
private final class DashboardCheckinFixture {
    let now = Date(timeIntervalSince1970: 1_789_689_600)
    let api = MockAPIClient()
    let defaults: UserDefaults
    let suite: String
    let preferences: WeightUnitPreferences
    let store: CheckinStore
    let model: DashboardViewModel

    init() {
        suite = "DashboardCheckinFixture.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        preferences = WeightUnitPreferences(defaults: defaults)
        store = CheckinStore(api: api, now: { [now] in now })
        model = DashboardViewModel(
            api: api,
            checkinStore: store,
            weightUnitPreferences: preferences,
            hasProfileAttachFailure: false
        )
    }

    var dashboardLoadCount: Int {
        api.requestLog.filter {
            $0.requestID == Endpoint.getDashboardSummary.requestID
        }.count
    }

    deinit {
        defaults.removePersistentDomain(forName: suite)
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
        mood: Int? = nil,
        nausea: Int? = nil,
        fatigue: Int? = nil,
        notes: String? = nil
    ) -> Checkin {
        Checkin(
            id: id,
            userId: UUID(),
            date: date,
            weightKg: weightKg,
            energyLevel: energyLevel,
            sleepQuality: nil,
            appetiteLevel: nil,
            mood: mood,
            nausea: nausea,
            injectionSiteReaction: nil,
            fatigue: fatigue,
            headache: nil,
            giIssues: nil,
            notes: notes,
            createdAt: nil,
            updatedAt: nil
        )
    }
}

final class WearableEndpointTests: XCTestCase {
    func testGetLatestWearableDataPathAndQuery() {
        let endpoint = Endpoint.getLatestWearableData(provider: "oura")

        XCTAssertEqual(endpoint.path, "/wearables/data/latest")
        XCTAssertEqual(endpoint.queryItems, [URLQueryItem(name: "provider", value: "oura")])
        XCTAssertEqual(endpoint.method, .get)
    }

    func testRequestIDDisambiguatesByProvider() {
        let oura = Endpoint.getLatestWearableData(provider: "oura")
        let whoop = Endpoint.getLatestWearableData(provider: "whoop")

        XCTAssertNotEqual(oura.requestID, whoop.requestID)
    }

    func testRequestIDUnchangedForEndpointsWithoutQueryItems() {
        XCTAssertEqual(Endpoint.getDashboardSummary.requestID, "GET /dashboard/summary")
    }

    func testMockAPIClientHoldsDistinctResponsesPerProvider() async throws {
        let api = MockAPIClient()
        api.setMockResponse(
            WearableDataSnapshot(sleepHours: 7.2, hrvMs: 54, readinessScore: nil),
            for: Endpoint.getLatestWearableData(provider: "oura")
        )
        api.setMockResponse(
            WearableDataSnapshot(sleepHours: nil, hrvMs: nil, readinessScore: 72),
            for: Endpoint.getLatestWearableData(provider: "whoop")
        )

        let oura: WearableDataSnapshot? = try await api.execute(.getLatestWearableData(provider: "oura"))
        let whoop: WearableDataSnapshot? = try await api.execute(.getLatestWearableData(provider: "whoop"))

        XCTAssertEqual(oura?.sleepHours, 7.2)
        XCTAssertEqual(whoop?.readinessScore, 72)
    }
}
