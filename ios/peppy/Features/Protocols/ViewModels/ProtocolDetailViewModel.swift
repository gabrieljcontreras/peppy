import Foundation
import Observation

enum ProtocolDetailConfirmation: Equatable {
    case deactivate
    case delete
}

struct DoseLogRowModel: Identifiable, Equatable {
    let id: UUID
    let dateText: String
    let doseText: String
    let statusText: String
}

struct CompoundDetailModel: Identifiable, Equatable {
    let id: UUID
    let name: String
    let doseChipText: String
    let doseFrequencyText: String
    let routeText: String
    let notes: String?
    let nextDoseDateText: String?
    let nextDoseAmountText: String
}

@MainActor
@Observable
final class ProtocolDetailViewModel {
    private let store: ProtocolStore
    let protocolID: UUID

    private(set) var didDelete = false
    private(set) var pendingConfirmation: ProtocolDetailConfirmation?

    init(protocolID: UUID, store: ProtocolStore) {
        self.protocolID = protocolID
        self.store = store
    }

    // MARK: - Derived protocol state (no duplicated mutable copy)

    var protocolValue: ProtocolModel? {
        if let selected = store.selectedProtocol, selected.id == protocolID {
            return selected
        }
        return store.protocols.first { $0.id == protocolID }
    }

    var errorMessage: String? {
        store.errorMessage
    }

    var isMutating: Bool {
        store.mutatingProtocolID == protocolID
    }

    var status: ProtocolStatus? {
        protocolValue?.status
    }

    // MARK: - Header presentation

    var title: String {
        protocolValue?.name ?? "Protocol"
    }

    var statusText: String {
        switch status {
        case .pendingSetup:
            return "Needs setup"
        case .active:
            return "Active"
        case .inactive:
            return "Inactive"
        case nil:
            return ""
        }
    }

    var startDateText: String {
        guard let protocolValue else { return "" }
        return "Started \(Self.dateFormatter.string(from: protocolValue.startDate))"
    }

    var endDateText: String {
        guard let endDate = protocolValue?.endDate else { return "Ongoing" }
        return "Ends \(Self.dateFormatter.string(from: endDate))"
    }

    var startMarkerText: String {
        guard let protocolValue else { return "" }
        return Self.shortDateFormatter.string(from: protocolValue.startDate)
    }

    var endMarkerText: String {
        guard let endDate = protocolValue?.endDate else { return "Ongoing" }
        return Self.shortDateFormatter.string(from: endDate)
    }

    var completedTimelineSteps: Int {
        switch status {
        case .pendingSetup, nil:
            return 0
        case .active:
            return 1
        case .inactive:
            return 2
        }
    }

    var notesText: String? {
        guard let notes = protocolValue?.notes, !notes.isEmpty else { return nil }
        return notes
    }

    // MARK: - Action availability

    var canLogDose: Bool {
        status == .active
    }

    var canDeactivate: Bool {
        status == .active
    }

    var canActivate: Bool {
        status == .inactive
    }

    var canEdit: Bool {
        protocolValue != nil
    }

    var canDelete: Bool {
        protocolValue != nil
    }

    // MARK: - Compounds

    var compoundDetails: [CompoundDetailModel] {
        guard let protocolValue else { return [] }
        return protocolValue.compounds.map { compound in
            let doseChipText = Self.doseText(compound.doseMg, unit: compound.doseUnit)
            return CompoundDetailModel(
                id: compound.id,
                name: compound.name,
                doseChipText: doseChipText,
                doseFrequencyText: "\(doseChipText) \(Self.frequencyDisplay(compound.frequency))",
                routeText: Self.routeDisplay(compound.administrationRoute),
                notes: compound.notes,
                nextDoseDateText: nextDoseDateText(for: compound, in: protocolValue),
                nextDoseAmountText: doseChipText
            )
        }
    }

    // MARK: - Dose history

    var allDoseRows: [DoseLogRowModel] {
        store.doseLogs
            .filter { $0.protocolID == protocolID }
            .map { log in
                DoseLogRowModel(
                    id: log.id,
                    dateText: Self.dayDateFormatter.string(from: log.administeredAt),
                    doseText: Self.doseText(log.dose, unit: log.unit),
                    statusText: "Logged"
                )
            }
    }

    var recentDoseRows: [DoseLogRowModel] {
        Array(allDoseRows.prefix(Self.recentDoseRowLimit))
    }

    var hasMoreDoseRows: Bool {
        allDoseRows.count > Self.recentDoseRowLimit
    }

    // MARK: - Loading

    func load() async {
        await store.select(protocolID)
        await store.loadDoseLogs(protocolID: protocolID)
    }

    func refresh() async {
        await load()
    }

    // MARK: - Confirmation flow

    func requestDeactivate() {
        pendingConfirmation = .deactivate
    }

    func requestDelete() {
        pendingConfirmation = .delete
    }

    func cancelPendingConfirmation() {
        pendingConfirmation = nil
    }

    func confirmPendingAction() async -> Bool {
        guard let confirmation = pendingConfirmation else { return false }
        pendingConfirmation = nil
        return await perform(confirmation)
    }

    /// Dequeues synchronously so a confirmation dialog's dismissal (which cancels
    /// the pending action) cannot race the async confirmation work.
    func confirmFromDialog() {
        guard let confirmation = pendingConfirmation else { return }
        pendingConfirmation = nil
        Task { _ = await perform(confirmation) }
    }

    private func perform(_ confirmation: ProtocolDetailConfirmation) async -> Bool {
        switch confirmation {
        case .deactivate:
            return await store.deactivate(id: protocolID)
        case .delete:
            guard store.selectedProtocol?.id == protocolID else { return false }
            let deleted = await store.deleteSelected()
            if deleted {
                didDelete = true
            }
            return deleted
        }
    }

    func activate() async -> Bool {
        await store.activate(id: protocolID)
    }

    // MARK: - Route intents

    var editRoute: ProtocolRoute {
        .edit(protocolID)
    }

    var addCompoundRoute: ProtocolRoute {
        .addCompound(protocolID)
    }

    func logDoseRoute(compoundID: UUID?) -> ProtocolRoute {
        .logDose(protocolID: protocolID, compoundID: compoundID)
    }

    func editCompoundRoute(compoundID: UUID) -> ProtocolRoute {
        .editCompound(protocolID: protocolID, compoundID: compoundID)
    }

    // MARK: - Presentation helpers

    private func nextDoseDateText(for compound: Compound, in protocolValue: ProtocolModel) -> String? {
        let compoundLogs = store.doseLogs.filter { $0.compoundID == compound.id }
        guard let latest = compoundLogs.map(\.administeredAt).max() else {
            return Self.dayDateFormatter.string(from: protocolValue.startDate)
        }
        guard let recurrence = DoseScheduleCalculator.recurrence(
            for: compound.frequency
        ) else {
            return nil
        }
        let calendar = Calendar.current
        let next: Date?
        switch recurrence {
        case .fixedDays(let interval):
            next = calendar.date(
                byAdding: .day,
                value: interval,
                to: latest
            )
        case .twiceWeekly, .monthly:
            next = DoseScheduleCalculator.upcomingDates(
                startingAt: protocolValue.startDate,
                frequency: compound.frequency,
                localTime: calendar.dateComponents([.hour, .minute], from: latest),
                after: latest,
                calendar: calendar,
                limit: 1
            ).first
        }
        guard let next else { return nil }
        return Self.dayDateFormatter.string(from: next)
    }

    private static func doseText(_ dose: Double, unit: String) -> String {
        let amount = doseFormatter.string(from: NSNumber(value: dose)) ?? "\(dose)"
        return "\(amount) \(unit)"
    }

    private static func frequencyDisplay(_ frequency: String) -> String {
        switch frequency.lowercased() {
        case "weekly":
            return "once weekly"
        case "daily":
            return "once daily"
        default:
            return frequency.lowercased()
        }
    }

    private static func routeDisplay(_ route: String) -> String {
        switch route.lowercased() {
        case "subcutaneous":
            return "Subcutaneous injection"
        case "intramuscular":
            return "Intramuscular injection"
        default:
            return route.capitalized
        }
    }

    private static let recentDoseRowLimit = 4

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

    private static let dayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, MMM d, yyyy"
        return formatter
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
