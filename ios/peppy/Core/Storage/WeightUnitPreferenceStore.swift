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

@MainActor
@Observable
final class WeightUnitPreferences {
    private static let key = "peppy.checkins.weight-unit"
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let seed: () -> WeightUnit?
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
        if let raw = defaults.string(forKey: Self.key),
           let saved = WeightUnit(rawValue: raw) {
            selectedUnit = saved
        }
    }

    func select(_ unit: WeightUnit) {
        selectedUnit = unit
        defaults.set(unit.rawValue, forKey: Self.key)
    }
}
