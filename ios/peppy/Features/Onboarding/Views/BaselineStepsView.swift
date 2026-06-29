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
            increment: incrementAge,
            setValue: setAge
        )
        .accessibilityLabel("Age")
        .accessibilityValue("\(displayedAge) years")
    }

    static func clampedAge(_ value: Int) -> Int {
        min(max(value, minimumAge), maximumAge)
    }

    func setAge(_ value: Int) {
        age = Self.clampedAge(value)
    }

    func decrementAge() {
        setAge(displayedAge - 1)
    }

    func incrementAge() {
        setAge(displayedAge + 1)
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
    static let imperialValueCardWidth: CGFloat = 156
    static let imperialCardSpacing: CGFloat = 12
    static var imperialCardsMinimumWidth: CGFloat {
        imperialValueCardWidth * 2 + imperialCardSpacing
    }

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
                HStack(spacing: Self.imperialCardSpacing) {
                    NumericValueCard(
                        value: feet,
                        suffix: "ft",
                        style: .compact,
                        decrement: decrementFeet,
                        increment: incrementFeet,
                        setValue: setFeet
                    )
                    .frame(width: Self.imperialValueCardWidth)

                    NumericValueCard(
                        value: inches,
                        suffix: "in",
                        style: .compact,
                        decrement: decrementInches,
                        increment: incrementInches,
                        setValue: setInches
                    )
                    .frame(width: Self.imperialValueCardWidth)
                }
            } else {
                NumericValueCard(
                    value: displayedCentimeters,
                    suffix: "cm",
                    decrement: { adjustCentimeters(by: -1) },
                    increment: { adjustCentimeters(by: 1) },
                    setValue: setCentimeters
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

    static func clampedFeet(_ value: Int) -> Int {
        min(max(value, minimumFeet), maximumFeet)
    }

    static func clampedInches(_ value: Int) -> Int {
        min(max(value, 0), 11)
    }

    static func clampedCentimeters(_ value: Int) -> Int {
        min(max(value, minimumCentimeters), maximumCentimeters)
    }

    func setFeet(_ value: Int) {
        feet = Self.clampedFeet(value)
        syncImperial()
    }

    func setInches(_ value: Int) {
        inches = Self.clampedInches(value)
        syncImperial()
    }

    func setCentimeters(_ value: Int) {
        centimeters = Double(Self.clampedCentimeters(value))
    }

    func decrementFeet() {
        setFeet(feet - 1)
    }

    func incrementFeet() {
        setFeet(feet + 1)
    }

    func decrementInches() {
        setInches(inches - 1)
    }

    func incrementInches() {
        setInches(inches + 1)
    }

    func adjustCentimeters(by delta: Int) {
        setCentimeters(displayedCentimeters + delta)
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
                increment: { adjustWeight(by: 1) },
                setValue: setDisplayedValue
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

    static func clampedDisplayedValue(_ value: Int, unit: WeightUnit) -> Int {
        let bounds = unit == .pounds ? poundRange : kilogramRange
        return min(max(value, bounds.lowerBound), bounds.upperBound)
    }

    static func kilograms(from displayedValue: Int, unit: WeightUnit) -> Double {
        switch unit {
        case .pounds:
            return OnboardingDraft.kilograms(pounds: Double(displayedValue))
        case .kilograms:
            return Double(displayedValue)
        }
    }

    func setDisplayedValue(_ value: Int) {
        displayedValue = Self.clampedDisplayedValue(value, unit: unit)
        kilograms = Self.kilograms(from: displayedValue, unit: unit)
    }

    func adjustWeight(by delta: Int) {
        setDisplayedValue(displayedValue + delta)
    }

    private func hydrateFromDraft() {
        displayedValue = Self.displayedValue(from: kilograms, unit: unit)
    }
}

private enum NumericValueCardStyle {
    case standard
    case compact
}

private struct NumericValueCard: View {
    let value: Int
    let suffix: String
    var style: NumericValueCardStyle = .standard
    let decrement: () -> Void
    let increment: () -> Void
    let setValue: (Int) -> Void

    @State private var draftValue = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        Group {
            switch style {
            case .standard:
                standardBody
            case .compact:
                compactBody
            }
        }
        .foregroundStyle(Color.pepTextPrimary)
        .padding(.vertical, style == .standard ? 24 : 22)
        .padding(.horizontal, style == .standard ? 12 : 4)
        .frame(maxWidth: .infinity)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.pepBorder, lineWidth: 1)
        }
        .onAppear {
            draftValue = "\(value)"
        }
        .onChange(of: value) { _, newValue in
            if !isEditing {
                draftValue = "\(newValue)"
            }
        }
        .onChange(of: isEditing) { _, focused in
            draftValue = focused ? "" : "\(value)"
        }
    }

    private var standardBody: some View {
        HStack(spacing: 18) {
            stepButton(systemName: "minus", label: "Decrease", action: decrement)

            VStack(spacing: 2) {
                valueField(fontSize: 64, minWidth: 96, maxWidth: 128)

                unitLabel
            }

            stepButton(systemName: "plus", label: "Increase", action: increment)
        }
    }

    private var compactBody: some View {
        VStack(spacing: 6) {
            HStack(spacing: 2) {
                stepButton(systemName: "minus", label: "Decrease", action: decrement)

                valueField(fontSize: 52, minWidth: 46, maxWidth: 52)

                stepButton(systemName: "plus", label: "Increase", action: increment)
            }

            unitLabel
        }
    }

    private var unitLabel: some View {
        Text(suffix)
            .font(.system(size: 12))
            .foregroundStyle(Color.pepTextSecondary)
    }

    private func stepButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func valueField(
        fontSize: CGFloat,
        minWidth: CGFloat,
        maxWidth: CGFloat
    ) -> some View {
        TextField("", text: numericText)
            .keyboardType(.numberPad)
            .focused($isEditing)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(Color.pepTextPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(minWidth: minWidth, maxWidth: maxWidth)
            .textFieldStyle(.plain)
            .accessibilityLabel("\(suffix) value")
            .accessibilityValue("\(value) \(suffix)")
            .toolbar {
                if isEditing {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isEditing = false
                        }
                    }
                }
            }
    }

    private var numericText: Binding<String> {
        Binding(
            get: {
                isEditing ? draftValue : "\(value)"
            },
            set: { newValue in
                let filtered = String(newValue.filter(\.isNumber).prefix(3))
                draftValue = filtered

                if let value = Int(filtered) {
                    setValue(value)
                }
            }
        )
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
