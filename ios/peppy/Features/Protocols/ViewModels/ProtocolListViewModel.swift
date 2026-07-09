import Foundation
import Observation

enum ProtocolListState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(String)
}

struct ProtocolListRowModel: Identifiable, Equatable {
    let id: UUID
    let route: ProtocolRoute
    let title: String
    let status: ProtocolStatus
    let statusText: String
    let timelineText: String
    let dateRangeText: String
    let compoundSummary: String
    let doseSummary: String
    let scheduleSummary: String
    let scheduleDisplayText: String
    let durationText: String?
    let startMarkerText: String
    let statusMarkerText: String
    let endMarkerText: String
    let completedTimelineSteps: Int

    var isCurrent: Bool {
        status != .inactive
    }
}

@MainActor
@Observable
final class ProtocolListViewModel {
    private let store: ProtocolStore
    private var didAttemptLoad = false

    init(store: ProtocolStore) {
        self.store = store
    }

    var state: ProtocolListState {
        if store.isLoading && store.protocols.isEmpty {
            return .loading
        }

        guard store.protocols.isEmpty else {
            return .loaded
        }

        if didAttemptLoad, let errorMessage = store.errorMessage {
            return .failed(errorMessage)
        }

        return didAttemptLoad ? .empty : .idle
    }

    var activeRows: [ProtocolListRowModel] {
        store.protocols
            .filter { $0.status != .inactive }
            .map(row)
    }

    var historyRows: [ProtocolListRowModel] {
        store.protocols
            .filter { $0.status == .inactive }
            .map(row)
    }

    var activeCountText: String {
        "\(activeRows.count)"
    }

    var historyCountText: String {
        "\(historyRows.count)"
    }

    var createRoute: ProtocolRoute {
        .create
    }

    var refreshErrorMessage: String? {
        store.protocols.isEmpty ? nil : store.errorMessage
    }

    func loadIfNeeded() async {
        didAttemptLoad = true
        await store.loadProtocols()
    }

    func retry() async {
        didAttemptLoad = true
        await store.loadProtocols(force: true)
    }

    func refresh() async {
        didAttemptLoad = true
        await store.loadProtocols(force: true)
    }

    func route(for protocolValue: ProtocolModel) -> ProtocolRoute {
        if protocolValue.status == .pendingSetup {
            return .starterSetup(
                protocolID: protocolValue.id,
                compounds: protocolValue.compounds.map(\.name)
            )
        }
        return .detail(protocolValue.id)
    }

    private func row(for protocolValue: ProtocolModel) -> ProtocolListRowModel {
        let compound = protocolValue.compounds.first
        return ProtocolListRowModel(
            id: protocolValue.id,
            route: route(for: protocolValue),
            title: protocolValue.name,
            status: protocolValue.status,
            statusText: statusText(for: protocolValue),
            timelineText: timelineText(for: protocolValue),
            dateRangeText: dateRangeText(for: protocolValue),
            compoundSummary: compoundSummary(for: protocolValue),
            doseSummary: doseSummary(for: compound),
            scheduleSummary: compound?.frequency ?? "No schedule",
            scheduleDisplayText: scheduleDisplayText(for: compound),
            durationText: durationText(for: protocolValue),
            startMarkerText: Self.shortDateFormatter.string(from: protocolValue.startDate),
            statusMarkerText: statusText(for: protocolValue),
            endMarkerText: endMarkerText(for: protocolValue),
            completedTimelineSteps: completedTimelineSteps(for: protocolValue)
        )
    }

    private func compoundSummary(for protocolValue: ProtocolModel) -> String {
        guard let firstCompound = protocolValue.compounds.first else { return "No compounds" }
        guard protocolValue.compounds.count > 1 else { return firstCompound.name }
        return "\(firstCompound.name) + \(protocolValue.compounds.count - 1) more"
    }

    private func statusText(for protocolValue: ProtocolModel) -> String {
        switch protocolValue.status {
        case .pendingSetup:
            return "Needs setup"
        case .active:
            return "Active"
        case .inactive:
            return "Inactive"
        }
    }

    private func timelineText(for protocolValue: ProtocolModel) -> String {
        switch protocolValue.status {
        case .pendingSetup:
            return "Ready for setup"
        case .active:
            if let durationText = durationText(for: protocolValue) {
                return "Planned for \(durationText)"
            }
            return "Active plan"
        case .inactive:
            return durationText(for: protocolValue) ?? "Completed plan"
        }
    }

    private func dateRangeText(for protocolValue: ProtocolModel) -> String {
        if let endDate = protocolValue.endDate {
            return "\(Self.dateFormatter.string(from: protocolValue.startDate)) - \(Self.dateFormatter.string(from: endDate))"
        }
        return "Started \(Self.dateFormatter.string(from: protocolValue.startDate))"
    }

    private func durationText(for protocolValue: ProtocolModel) -> String? {
        guard let endDate = protocolValue.endDate else { return nil }
        let days = Self.dateCalendar.dateComponents([.day], from: protocolValue.startDate, to: endDate).day ?? 0
        let weeks = max(1, Int(ceil(Double(days) / 7.0)))
        return "\(weeks) weeks"
    }

    private func endMarkerText(for protocolValue: ProtocolModel) -> String {
        guard let endDate = protocolValue.endDate else { return "Ongoing" }
        return Self.shortDateFormatter.string(from: endDate)
    }

    private func doseSummary(for compound: Compound?) -> String {
        guard let compound else { return "No dose" }
        let dose = Self.doseFormatter.string(from: NSNumber(value: compound.doseMg)) ?? "\(compound.doseMg)"
        return "\(dose) \(compound.doseUnit)"
    }

    private func scheduleDisplayText(for compound: Compound?) -> String {
        guard let compound else { return "No schedule" }
        return compound.frequency.capitalized
    }

    private func completedTimelineSteps(for protocolValue: ProtocolModel) -> Int {
        switch protocolValue.status {
        case .pendingSetup:
            return 0
        case .active:
            return 1
        case .inactive:
            return 2
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let dateCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static let doseFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
