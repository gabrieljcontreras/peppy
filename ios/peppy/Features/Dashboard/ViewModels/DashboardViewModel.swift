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
    private var lastSeenProtocolRevision: Int
    private var lastSeenCheckinRevision: Int

    var state = DashboardState()

    init(
        api: APIClientProtocol,
        protocolStore: ProtocolStore? = nil,
        checkinStore: CheckinStore? = nil,
        weightUnitPreferences: WeightUnitPreferences? = nil,
        hasProfileAttachFailure: @autoclosure @escaping () -> Bool
    ) {
        self.api = api
        self.protocolStore = protocolStore
        self.checkinStore = checkinStore
        self.weightUnitPreferences = weightUnitPreferences
        self.hasProfileAttachFailure = hasProfileAttachFailure
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
            if state.summary == nil {
                state.summary = await recoveringProtocol(in: .mockMissingProfile)
            }
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        } catch {
            state.errorMessage = error.localizedDescription
            if state.summary == nil {
                state.summary = await recoveringProtocol(in: .mockMissingProfile)
            }
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        }
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
