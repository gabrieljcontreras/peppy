import Foundation
import Observation

extension WeightUnit {
    private static let poundsPerKilogram = 2.2046226218

    var symbol: String { self == .pounds ? "lb" : "kg" }

    func kilograms(from displayValue: Double) -> Double {
        self == .pounds ? displayValue / Self.poundsPerKilogram : displayValue
    }

    func displayValue(kilograms: Double) -> Double {
        self == .pounds ? kilograms * Self.poundsPerKilogram : kilograms
    }

    func format(kilograms: Double) -> String {
        String(format: "%.1f %@", displayValue(kilograms: kilograms), symbol)
    }
}

extension HeightUnit {
    func centimeters(feet: Int, inches: Int) -> Double {
        (Double(feet) * 30.48) + (Double(inches) * 2.54)
    }

    func imperialParts(centimeters: Double) -> (feet: Int, inches: Int) {
        let totalInches = max(0, Int((centimeters / 2.54).rounded()))
        return (totalInches / 12, totalInches % 12)
    }

    func format(centimeters: Double) -> String {
        switch self {
        case .feetAndInches:
            let parts = imperialParts(centimeters: centimeters)
            return "\(parts.feet) ft \(parts.inches) in"
        case .centimeters:
            return "\(Int(centimeters.rounded())) cm"
        }
    }
}

@MainActor
@Observable
final class WeightUnitPreferences {
    private static let anonymousKey = "peppy.checkins.weight-unit"
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let seed: () -> WeightUnit?
    private var activeUserID: UUID?
    private var selectedUnit: WeightUnit?

    var unit: WeightUnit {
        selectedUnit ?? seed() ?? .pounds
    }

    init(
        defaults: UserDefaults = .standard,
        seed: @escaping () -> WeightUnit? = { nil }
    ) {
        self.defaults = defaults
        self.seed = seed
        selectedUnit = savedUnit(forKey: Self.anonymousKey)
    }

    func activate(userID: UUID, serverUnit: WeightUnit?) {
        activeUserID = userID

        if let serverUnit {
            selectedUnit = serverUnit
            defaults.set(serverUnit.rawValue, forKey: Self.userKey(userID))
        } else {
            selectedUnit = savedUnit(forKey: Self.userKey(userID)) ?? seed()
        }
    }

    func select(_ unit: WeightUnit) {
        selectedUnit = unit
        defaults.set(unit.rawValue, forKey: persistenceKey)
    }

    func resetSession() {
        activeUserID = nil
        selectedUnit = savedUnit(forKey: Self.anonymousKey)
    }

    func removePreference(for userID: UUID) {
        defaults.removeObject(forKey: Self.userKey(userID))
        if activeUserID == userID {
            resetSession()
        }
    }

    private var persistenceKey: String {
        activeUserID.map(Self.userKey) ?? Self.anonymousKey
    }

    private static func userKey(_ userID: UUID) -> String {
        "peppy.checkins.weight-unit.\(userID.uuidString.lowercased())"
    }

    private func savedUnit(forKey key: String) -> WeightUnit? {
        defaults.string(forKey: key).flatMap(WeightUnit.init(rawValue:))
    }
}
