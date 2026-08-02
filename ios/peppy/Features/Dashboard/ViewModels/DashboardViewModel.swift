import Foundation
import Observation

struct DashboardState: Equatable {
    var isLoading = false
    var summary: DashboardSummary?
    var errorMessage: String?
    var showsProfileSyncRecovery = false
}

@MainActor
@Observable
final class DashboardViewModel {
    private let api: APIClientProtocol
    private let protocolStore: ProtocolStore?
    private let checkinStore: CheckinStore?
    private let weightUnitPreferences: WeightUnitPreferences?
    private let hasProfileAttachFailure: () -> Bool
    private let currentDisplayName: () -> String?
    private let now: () -> Date
    private var lastSeenProtocolRevision: Int
    private var lastSeenCheckinRevision: Int

    var state = DashboardState()
    private(set) var wearableTiles: DashboardWearableTiles?

    init(
        api: APIClientProtocol,
        protocolStore: ProtocolStore? = nil,
        checkinStore: CheckinStore? = nil,
        weightUnitPreferences: WeightUnitPreferences? = nil,
        hasProfileAttachFailure: @autoclosure @escaping () -> Bool,
        currentDisplayName: @escaping () -> String? = { nil },
        now: @escaping () -> Date = Date.init
    ) {
        self.api = api
        self.protocolStore = protocolStore
        self.checkinStore = checkinStore
        self.weightUnitPreferences = weightUnitPreferences
        self.hasProfileAttachFailure = hasProfileAttachFailure
        self.currentDisplayName = currentDisplayName
        self.now = now
        self.lastSeenProtocolRevision = protocolStore?.revision ?? 0
        self.lastSeenCheckinRevision = checkinStore?.revision ?? 0
    }

    /// Reloads only when the protocol store has reconciled a successful mutation
    /// since the last load; failed mutations leave `revision` untouched.
    func refreshIfProtocolStateChanged() async {
        guard let protocolStore,
              protocolStore.revision != lastSeenProtocolRevision else { return }
        await load()
    }

    func load() async {
        lastSeenProtocolRevision = protocolStore?.revision ?? 0
        lastSeenCheckinRevision = checkinStore?.revision ?? 0
        await checkinStore?.load()
        await loadDashboardSummary()
    }

    func refreshIfCheckinStateChanged() async {
        guard let checkinStore,
              checkinStore.revision != lastSeenCheckinRevision else { return }
        lastSeenCheckinRevision = checkinStore.revision
        await loadDashboardSummary()
    }

    private func loadDashboardSummary() async {
        state.isLoading = true
        state.errorMessage = nil
        defer { state.isLoading = false }

        do {
            let summary: DashboardSummary = try await api.execute(.getDashboardSummary)
            state.summary = await recoveringProtocol(in: summary)
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        } catch let error as APIError {
            state.errorMessage = error.userMessage
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        } catch {
            state.errorMessage = error.localizedDescription
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        }

        await loadActiveProtocolDetailIfNeeded()
        await loadWearableTilesIfNeeded()
    }

    private func loadActiveProtocolDetailIfNeeded() async {
        guard let summary = state.summary,
              summary.protocol.status == "active",
              let protocolID = summary.protocol.id else { return }
        await protocolStore?.loadProtocols()
        await protocolStore?.loadDoseLogs(protocolID: protocolID)
    }

    private func loadWearableTilesIfNeeded() async {
        guard state.summary?.connectedContext.hasWearables == true else {
            wearableTiles = nil
            return
        }
        // Sequential, not `async let`: `MockAPIClient` is a plain class, not
        // an actor, so concurrent calls into it from two child tasks would be
        // a data race in tests. Two small GETs in series is cheap enough that
        // the lost parallelism doesn't matter here.
        let ouraData = await fetchWearableData(provider: "oura")
        let whoopData = await fetchWearableData(provider: "whoop")
        let tiles = DashboardWearableTiles(
            sleepHours: ouraData?.sleepHours,
            hrvMs: ouraData?.hrvMs,
            readinessScore: whoopData?.readinessScore
        )
        wearableTiles = tiles.isEmpty ? nil : tiles
    }

    private func fetchWearableData(provider: String) async -> WearableDataSnapshot? {
        try? await api.execute(.getLatestWearableData(provider: provider))
    }

    var greetingText: String {
        "Good \(dayPart), \(firstName)"
    }

    private var firstName: String {
        guard let displayName = currentDisplayName()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !displayName.isEmpty,
              let first = displayName.split(separator: " ").first else {
            return "there"
        }
        return String(first)
    }

    private var dayPart: String {
        switch Calendar.current.component(.hour, from: now()) {
        case 5...11: return "morning"
        case 12...16: return "afternoon"
        default: return "evening"
        }
    }

    var nextDose: (compound: Compound, dueDate: Date)? {
        guard let summary = state.summary,
              summary.protocol.status == "active",
              let protocolID = summary.protocol.id,
              let fullProtocol = protocolStore?.protocols.first(where: { $0.id == protocolID }),
              !fullProtocol.compounds.isEmpty
        else { return nil }
        return fullProtocol.nextDueCompound(doseLogs: protocolStore?.doseLogs ?? [])
    }

    var todayPreview: DashboardCheckinPreview? {
        guard let checkin = checkinStore?.today,
              let weightUnitPreferences else { return nil }
        var values = [
            checkin.weightKg.map { weightUnitPreferences.unit.format(kilograms: $0) },
            checkin.energyLevel.map { "Energy \($0)" },
            checkin.mood.map { "Mood \($0)" },
        ].compactMap { $0 }

        let symptomCount = [
            checkin.nausea,
            checkin.injectionSiteReaction,
            checkin.fatigue,
            checkin.headache,
            checkin.giIssues,
        ].compactMap { $0 }.filter { $0 > 0 }.count
        if values.count < 3, symptomCount > 0 {
            values.append("\(symptomCount) symptom\(symptomCount == 1 ? "" : "s") logged")
        }
        if values.isEmpty, checkin.notes != nil { values = ["Notes added"] }

        return DashboardCheckinPreview(
            isSaved: true,
            title: "Your check-in",
            subtitle: "Today's check-in is saved",
            highlights: Array(values.prefix(3))
        )
    }

    var checkinRoute: CheckinRoute {
        if let id = checkinStore?.today?.id ?? state.summary?.todayCheckin.checkinId {
            return .detail(id)
        }
        return .create
    }

    private func recoveringProtocol(in summary: DashboardSummary) async -> DashboardSummary {
        guard summary.protocol.status == "missing" else { return summary }

        await protocolStore?.loadProtocols(force: true)

        guard let protocolValue = protocolStore?.protocols.first(where: \.isActive) else {
            return summary
        }

        return summary.replacingProtocol(with: protocolValue)
    }
}
