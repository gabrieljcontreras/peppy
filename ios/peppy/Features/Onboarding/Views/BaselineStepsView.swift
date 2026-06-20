import SwiftUI

struct AgeStepView: View {
    @Binding var age: Int?

    static let defaultAge = 32
    static let minimumAge = 13
    static let maximumAge = 120

    var displayedAge: Int {
        age ?? Self.defaultAge
    }

    var body: some View {
        NumericValueCard(
            value: displayedAge,
            suffix: "years",
            decrement: decrementAge,
            increment: incrementAge
        )
        .accessibilityLabel("Age")
        .accessibilityValue("\(displayedAge) years")
    }

    func decrementAge() {
        age = max(Self.minimumAge, displayedAge - 1)
    }

    func incrementAge() {
        age = min(Self.maximumAge, displayedAge + 1)
    }
}

struct HeightStepView: View {
    @Binding var centimeters: Double?
    @Binding var unit: HeightUnit
    @State private var feet: Int
    @State private var inches: Int

    static let defaultFeet = 5
    static let defaultInches = 8
    static let minimumFeet = 3
    static let maximumFeet = 8
    static let minimumCentimeters = 100
    static let maximumCentimeters = 250

    init(centimeters: Binding<Double?>, unit: Binding<HeightUnit>) {
        self._centimeters = centimeters
        self._unit = unit
        let parts = Self.imperialParts(from: centimeters.wrappedValue)
        self._feet = State(initialValue: parts.feet)
        self._inches = State(initialValue: parts.inches)
    }

    var displayedCentimeters: Int {
        Int((centimeters ?? Double(Self.defaultCentimeters)).rounded())
    }

    static var defaultCentimeters: Int {
        Int(centimeters(feet: defaultFeet, inches: defaultInches).rounded())
    }

    var body: some View {
        VStack(spacing: 24) {
            Picker("Height unit", selection: $unit) {
                Text("ft / in").tag(HeightUnit.feetAndInches)
                Text("cm").tag(HeightUnit.centimeters)
            }
            .pickerStyle(.segmented)

            if unit == .feetAndInches {
                HStack(spacing: 18) {
                    NumericValueCard(
                        value: feet,
                        suffix: "ft",
                        decrement: decrementFeet,
                        increment: incrementFeet
                    )
                    NumericValueCard(
                        value: inches,
                        suffix: "in",
                        decrement: decrementInches,
                        increment: incrementInches
                    )
                }
            } else {
                NumericValueCard(
                    value: displayedCentimeters,
                    suffix: "cm",
                    decrement: { adjustCentimeters(by: -1) },
                    increment: { adjustCentimeters(by: 1) }
                )
            }
        }
        .onAppear(perform: hydrateImperialFromDraft)
        .onChange(of: unit) { _, newUnit in
            if newUnit == .feetAndInches {
                hydrateImperialFromDraft()
            }
        }
    }

    static func centimeters(feet: Int, inches: Int) -> Double {
        OnboardingDraft.centimeters(feet: feet, inches: inches)
    }

    static func imperialParts(from centimeters: Double?) -> (feet: Int, inches: Int) {
        guard let centimeters else {
            return (defaultFeet, defaultInches)
        }

        let totalInches = max(0, Int((centimeters / 2.54).rounded()))
        let feet = min(max(totalInches / 12, minimumFeet), maximumFeet)
        let inches = min(max(totalInches % 12, 0), 11)

        return (feet, inches)
    }

    func decrementFeet() {
        feet = max(Self.minimumFeet, feet - 1)
        syncImperial()
    }

    func incrementFeet() {
        feet = min(Self.maximumFeet, feet + 1)
        syncImperial()
    }

    func decrementInches() {
        inches = max(0, inches - 1)
        syncImperial()
    }

    func incrementInches() {
        inches = min(11, inches + 1)
        syncImperial()
    }

    func adjustCentimeters(by delta: Int) {
        let nextValue = min(
            max(displayedCentimeters + delta, Self.minimumCentimeters),
            Self.maximumCentimeters
        )
        centimeters = Double(nextValue)
    }

    private func hydrateImperialFromDraft() {
        let parts = Self.imperialParts(from: centimeters)
        feet = parts.feet
        inches = parts.inches
    }

    private func syncImperial() {
        centimeters = Self.centimeters(feet: feet, inches: inches)
    }
}

struct WeightStepView: View {
    @Binding var kilograms: Double?
    @Binding var unit: WeightUnit
    @State private var displayedValue: Int

    static let defaultPounds = 165
    static let defaultKilograms = 75
    static let poundRange = 60...700
    static let kilogramRange = 27...318

    init(kilograms: Binding<Double?>, unit: Binding<WeightUnit>) {
        self._kilograms = kilograms
        self._unit = unit
        self._displayedValue = State(
            initialValue: Self.displayedValue(
                from: kilograms.wrappedValue,
                unit: unit.wrappedValue
            )
        )
    }

    var suffix: String {
        unit == .pounds ? "lb" : "kg"
    }

    var body: some View {
        VStack(spacing: 24) {
            Picker("Weight unit", selection: $unit) {
                Text("lb").tag(WeightUnit.pounds)
                Text("kg").tag(WeightUnit.kilograms)
            }
            .pickerStyle(.segmented)

            NumericValueCard(
                value: displayedValue,
                suffix: suffix,
                decrement: { adjustWeight(by: -1) },
                increment: { adjustWeight(by: 1) }
            )
        }
        .onAppear(perform: hydrateFromDraft)
        .onChange(of: unit) { _, _ in
            hydrateFromDraft()
        }
    }

    static func displayedValue(from kilograms: Double?, unit: WeightUnit) -> Int {
        guard let kilograms else {
            return unit == .pounds ? defaultPounds : defaultKilograms
        }

        switch unit {
        case .pounds:
            return Int((kilograms / 0.45359237).rounded())
        case .kilograms:
            return Int(kilograms.rounded())
        }
    }

    static func kilograms(from displayedValue: Int, unit: WeightUnit) -> Double {
        switch unit {
        case .pounds:
            return OnboardingDraft.kilograms(pounds: Double(displayedValue))
        case .kilograms:
            return Double(displayedValue)
        }
    }

    func adjustWeight(by delta: Int) {
        let bounds = unit == .pounds ? Self.poundRange : Self.kilogramRange
        displayedValue = min(max(displayedValue + delta, bounds.lowerBound), bounds.upperBound)
        kilograms = Self.kilograms(from: displayedValue, unit: unit)
    }

    private func hydrateFromDraft() {
        displayedValue = Self.displayedValue(from: kilograms, unit: unit)
    }
}

private struct NumericValueCard: View {
    let value: Int
    let suffix: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button(action: decrement) {
                Image(systemName: "minus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Decrease")

            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(Color.pepTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(suffix)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.pepTextSecondary)
            }
            .frame(minWidth: 96)

            Button(action: increment) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Increase")
        }
        .foregroundStyle(Color.pepTextPrimary)
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.pepBorder, lineWidth: 1)
        }
    }
}

#Preview("Age Step") {
    AgeStepView(age: .constant(32))
        .padding(24)
        .background(Color.pepBackground)
        .previewLayout(.fixed(width: 393, height: 260))
}

#Preview("Height Step") {
    HeightStepView(
        centimeters: .constant(OnboardingDraft.centimeters(feet: 5, inches: 8)),
        unit: .constant(.feetAndInches)
    )
    .padding(24)
    .background(Color.pepBackground)
    .previewLayout(.fixed(width: 393, height: 320))
}

#Preview("Weight Step - Accessibility") {
    WeightStepView(
        kilograms: .constant(OnboardingDraft.kilograms(pounds: 165)),
        unit: .constant(.pounds)
    )
    .padding(24)
    .background(Color.pepBackground)
    .environment(\.dynamicTypeSize, .accessibility3)
    .previewLayout(.fixed(width: 393, height: 320))
}
