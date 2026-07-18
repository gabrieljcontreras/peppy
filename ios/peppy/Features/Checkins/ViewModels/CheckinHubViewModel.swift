import Foundation
import Observation

@MainActor
@Observable
final class CheckinHubViewModel {
    private let store: CheckinStore
    private let preferences: WeightUnitPreferences
    private var didAttemptLoad = false

    init(store: CheckinStore, preferences: WeightUnitPreferences) {
        self.store = store
        self.preferences = preferences
    }

    var state: CheckinHubState {
        if store.isLoading && store.checkins.isEmpty { return .loading }
        if !store.checkins.isEmpty { return .loaded }
        if didAttemptLoad, let error = store.errorMessage { return .failed(error) }
        return didAttemptLoad ? .empty : .idle
    }

    var todayDetail: CheckinDetailModel? {
        store.today.map(makeDetail)
    }

    var createRoute: CheckinRoute { .create }

    var refreshErrorMessage: String? {
        store.checkins.isEmpty ? nil : store.errorMessage
    }

    var historyRows: [CheckinHistoryRowModel] {
        store.history.map(row)
    }

    func loadIfNeeded() async {
        didAttemptLoad = true
        await store.load()
    }

    func refresh() async {
        didAttemptLoad = true
        await store.load(force: true)
    }

    func retry() async {
        await refresh()
    }

    func detail(for checkin: Checkin) -> CheckinDetailModel {
        makeDetail(checkin)
    }

    private func row(_ checkin: Checkin) -> CheckinHistoryRowModel {
        let values = [
            checkin.weightKg.map { preferences.unit.format(kilograms: $0) },
            checkin.energyLevel.map { "Energy \($0)" },
            checkin.mood.map { "Mood \($0)" },
            symptomModels(checkin).isEmpty ? nil : "Symptoms logged",
        ].compactMap { $0 }

        return CheckinHistoryRowModel(
            id: checkin.id,
            dateText: Self.dateFormatter.string(from: checkin.date),
            summary: values.isEmpty
                ? (checkin.notes == nil ? "Check-in saved" : "Notes added")
                : values.prefix(3).joined(separator: " · "),
            route: .detail(checkin.id)
        )
    }

    private func makeDetail(_ checkin: Checkin) -> CheckinDetailModel {
        var metrics: [CheckinMetricModel] = []
        if let value = checkin.weightKg {
            metrics.append(
                .init(label: "Weight", value: preferences.unit.format(kilograms: value))
            )
        }
        if let value = checkin.energyLevel {
            metrics.append(.init(label: "Energy", value: "\(value)/10"))
        }
        if let value = checkin.mood {
            metrics.append(.init(label: "Mood", value: "\(value)/10"))
        }
        if let value = checkin.sleepQuality {
            metrics.append(.init(label: "Sleep quality", value: "\(value)/10"))
        }
        if let value = checkin.appetiteLevel {
            metrics.append(.init(label: "Appetite", value: "\(value)/10"))
        }

        return CheckinDetailModel(
            id: checkin.id,
            dateText: Self.dateFormatter.string(from: checkin.date),
            metrics: metrics,
            symptoms: symptomModels(checkin),
            notes: checkin.notes,
            isToday: store.today?.id == checkin.id
        )
    }

    private func symptomModels(_ checkin: Checkin) -> [CheckinSymptomModel] {
        [
            ("Nausea", checkin.nausea),
            ("Injection site", checkin.injectionSiteReaction),
            ("Fatigue", checkin.fatigue),
            ("Headache", checkin.headache),
            ("GI issues", checkin.giIssues),
        ].compactMap { label, value in
            guard let value, value > 0 else { return nil }
            return CheckinSymptomModel(label: label, severity: value)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
}
