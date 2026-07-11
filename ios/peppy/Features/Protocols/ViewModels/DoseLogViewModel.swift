import Foundation
import Observation

struct DoseLogValidation: Equatable {
    var dose: String?
    var unit: String?
    var route: String?

    var isValid: Bool {
        dose == nil && unit == nil && route == nil
    }
}

@MainActor
@Observable
final class DoseLogViewModel {
    private let store: ProtocolStore
    private let protocolValue: ProtocolModel
    private let compound: Compound
    private let now: Date

    var doseText: String
    var unit: String
    var route: String
    var notes = ""
    var administeredAt: Date

    private(set) var isSubmitting = false
    private(set) var errorMessage: String?

    init(
        protocol protocolValue: ProtocolModel,
        compound: Compound,
        store: ProtocolStore,
        now: Date = Date()
    ) {
        self.store = store
        self.protocolValue = protocolValue
        self.compound = compound
        self.now = now

        doseText = Self.doseAmountText(compound.doseMg)
        unit = compound.doseUnit
        route = compound.administrationRoute
        administeredAt = now
    }

    // MARK: - Context presentation

    var compoundName: String {
        compound.name
    }

    var protocolName: String {
        protocolValue.name
    }

    var protocolStatus: ProtocolStatus {
        protocolValue.status
    }

    var protocolStatusText: String {
        switch protocolValue.status {
        case .pendingSetup:
            return "Needs setup"
        case .active:
            return "Active"
        case .inactive:
            return "Inactive"
        }
    }

    var weekProgressText: String {
        let elapsed = now.timeIntervalSince(protocolValue.startDate)
        let currentWeek = max(1, Int(elapsed / Self.weekInterval) + 1)

        guard let endDate = protocolValue.endDate else {
            return "Week \(currentWeek)"
        }
        let totalWeeks = max(1, Int(ceil(endDate.timeIntervalSince(protocolValue.startDate) / Self.weekInterval)))
        return "Week \(min(currentWeek, totalWeeks)) of \(totalWeeks)"
    }

    var scheduledAmountText: String {
        "Scheduled amount: \(Self.doseAmountText(compound.doseMg)) \(compound.doseUnit)"
    }

    // MARK: - Validation

    var validation: DoseLogValidation {
        DoseLogValidation(
            dose: normalizedDose.map { $0 > 0 } == true ? nil : "Enter a positive dose.",
            unit: normalizedUnit.isEmpty ? "Unit is required." : nil,
            route: normalizedRoute.isEmpty ? "Route is required." : nil
        )
    }

    var canSubmit: Bool {
        validation.isValid && !isSubmitting
    }

    // MARK: - Submission

    func submit() async -> Bool {
        guard !isSubmitting, let request = buildRequest() else { return false }

        isSubmitting = true
        defer { isSubmitting = false }

        errorMessage = nil
        let logged = await store.logDose(request)
        guard logged != nil else {
            errorMessage = store.errorMessage ?? "Something went wrong. Please try again."
            return false
        }
        return true
    }

    private func buildRequest() -> CreateDoseLogRequest? {
        guard let dose = normalizedDose, dose > 0 else { return nil }
        let unit = normalizedUnit
        let route = normalizedRoute
        guard !unit.isEmpty, !route.isEmpty else { return nil }

        return CreateDoseLogRequest(
            protocolID: protocolValue.id,
            compoundID: compound.id,
            dose: dose,
            unit: unit,
            administeredAt: administeredAt,
            route: route,
            notes: notes.nilIfTrimmedEmpty
        )
    }

    // MARK: - Normalization

    private var normalizedDose: Double? {
        Double(doseText.trimmed)
    }

    private var normalizedUnit: String {
        unit.trimmed
    }

    private var normalizedRoute: String {
        route.trimmed
    }

    // MARK: - Formatting

    private static let weekInterval: TimeInterval = 7 * 86_400

    private static func doseAmountText(_ dose: Double) -> String {
        doseFormatter.string(from: NSNumber(value: dose)) ?? "\(dose)"
    }

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
