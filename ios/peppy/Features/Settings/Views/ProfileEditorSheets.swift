import SwiftUI

enum ProfileEditor: String, Identifiable {
    case name
    case baselineDate
    case baselineWeight
    case baselineHeight
    case primaryGoal
    case secondaryGoal
    case focusArea

    var id: String { rawValue }
}

struct ProfileEditorSheet: View {
    let editor: ProfileEditor
    let model: ProfileSettingsViewModel

    var body: some View {
        switch editor {
        case .name:
            ProfileNameEditor(initialName: model.draft.fullName) { name in
                model.draft.fullName = name
            }
        case .baselineDate:
            ProfileDateEditor(initialDate: model.draft.baselineDate) { date in
                model.draft.baselineDate = date
            }
        case .baselineWeight:
            ProfileWeightEditor(
                initialKilograms: model.draft.baselineWeightKg,
                unit: model.draft.weightUnit,
                onSave: model.setBaselineWeight(displayValue:)
            )
        case .baselineHeight:
            ProfileHeightEditor(
                initialCentimeters: model.draft.baselineHeightCm,
                unit: model.draft.heightUnit,
                onSaveCentimeters: model.setBaselineHeight(centimeters:),
                onSaveImperial: model.setBaselineHeight(feet:inches:)
            )
        case .primaryGoal:
            ProfileGoalEditor(
                title: "Primary goal",
                initialSelection: model.draft.primaryGoal,
                permitsNone: false
            ) { model.draft.primaryGoal = $0 }
        case .secondaryGoal:
            ProfileGoalEditor(
                title: "Secondary goal",
                initialSelection: model.draft.secondaryGoal,
                permitsNone: true
            ) { model.draft.secondaryGoal = $0 }
        case .focusArea:
            ProfileGoalEditor(
                title: "Focus area",
                initialSelection: model.draft.focusArea,
                permitsNone: true
            ) { model.draft.focusArea = $0 }
        }
    }
}

private struct ProfileNameEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    let onSave: (String) -> Void

    init(initialName: String, onSave: @escaping (String) -> Void) {
        _name = State(initialValue: initialName)
        self.onSave = onSave
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ProfileEditorScaffold(
            title: "Full name",
            canSave: !trimmedName.isEmpty && trimmedName.count <= 100,
            onSave: {
                onSave(trimmedName)
                dismiss()
            }
        ) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Full name")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)

                TextField("Enter your full name", text: $name)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color.pepSurface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(Color.pepBorder, lineWidth: 1)
                    }

                Text("\(name.count)/100")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(name.count > 100 ? Color.pepError : Color.pepTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

private struct ProfileDateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hasDate: Bool
    @State private var date: Date
    let onSave: (Date?) -> Void

    init(initialDate: Date?, onSave: @escaping (Date?) -> Void) {
        _hasDate = State(initialValue: initialDate != nil)
        _date = State(initialValue: initialDate ?? Date())
        self.onSave = onSave
    }

    var body: some View {
        ProfileEditorScaffold(
            title: "Baseline date",
            canSave: !hasDate || date <= Date(),
            onSave: {
                onSave(hasDate ? date : nil)
                dismiss()
            }
        ) {
            VStack(spacing: Spacing.md) {
                Toggle("Set a baseline date", isOn: $hasDate)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .tint(Color.pepPrimary)

                if hasDate {
                    DatePicker(
                        "Baseline date",
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Color.pepPrimary)
                }
            }
            .padding(14)
            .background(Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(Color.pepBorder, lineWidth: 1)
            }
        }
    }
}

private struct ProfileWeightEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var value: String
    let unit: WeightUnit
    let onSave: (Double?) -> Void

    init(
        initialKilograms: Double?,
        unit: WeightUnit,
        onSave: @escaping (Double?) -> Void
    ) {
        if let initialKilograms {
            _value = State(
                initialValue: String(format: "%.1f", unit.displayValue(kilograms: initialKilograms))
            )
        } else {
            _value = State(initialValue: "")
        }
        self.unit = unit
        self.onSave = onSave
    }

    private var parsedValue: Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Double(trimmed)
    }

    private var isValid: Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        guard let parsedValue, parsedValue.isFinite else { return false }
        return ProfileSettingsValidation.isValidWeight(
            kilograms: unit.kilograms(from: parsedValue)
        )
    }

    var body: some View {
        ProfileEditorScaffold(
            title: "Baseline weight",
            canSave: isValid,
            onSave: {
                onSave(parsedValue)
                dismiss()
            }
        ) {
            ProfileMeasurementField(
                title: "Weight",
                value: $value,
                unit: unit.symbol,
                errorMessage: isValid ? nil : "Enter a weight between 27 and 318 kg."
            )
        }
    }
}

private struct ProfileHeightEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hasHeight: Bool
    @State private var centimetersText: String
    @State private var feet: Int
    @State private var inches: Int
    let unit: HeightUnit
    let onSaveCentimeters: (Double?) -> Void
    let onSaveImperial: (Int, Int) -> Void

    init(
        initialCentimeters: Double?,
        unit: HeightUnit,
        onSaveCentimeters: @escaping (Double?) -> Void,
        onSaveImperial: @escaping (Int, Int) -> Void
    ) {
        let parts = unit.imperialParts(centimeters: initialCentimeters ?? 172.72)
        _hasHeight = State(initialValue: initialCentimeters != nil)
        _centimetersText = State(
            initialValue: initialCentimeters.map { String(format: "%.0f", $0) } ?? ""
        )
        _feet = State(initialValue: parts.feet)
        _inches = State(initialValue: parts.inches)
        self.unit = unit
        self.onSaveCentimeters = onSaveCentimeters
        self.onSaveImperial = onSaveImperial
    }

    private var centimeters: Double? {
        Double(centimetersText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isValid: Bool {
        guard hasHeight else { return true }
        switch unit {
        case .feetAndInches:
            return ProfileSettingsValidation.isValidHeight(feet: feet, inches: inches)
        case .centimeters:
            guard let centimeters, centimeters.isFinite else { return false }
            return ProfileSettingsValidation.isValidHeight(centimeters: centimeters)
        }
    }

    var body: some View {
        ProfileEditorScaffold(
            title: "Baseline height",
            canSave: isValid,
            onSave: {
                if !hasHeight {
                    onSaveCentimeters(nil)
                } else if unit == .feetAndInches {
                    onSaveImperial(feet, inches)
                } else {
                    onSaveCentimeters(centimeters)
                }
                dismiss()
            }
        ) {
            VStack(spacing: Spacing.md) {
                Toggle("Set a baseline height", isOn: $hasHeight)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .tint(Color.pepPrimary)

                if hasHeight {
                    switch unit {
                    case .feetAndInches:
                        HStack(spacing: Spacing.md) {
                            ProfileStepper(title: "Feet", value: $feet, range: 3...8)
                            ProfileStepper(title: "Inches", value: $inches, range: 0...11)
                        }
                    case .centimeters:
                        ProfileMeasurementField(
                            title: "Height",
                            value: $centimetersText,
                            unit: "cm",
                            errorMessage: isValid ? nil : "Enter a height from 100 to 250 cm."
                        )
                    }
                }
            }
        }
    }
}

private struct ProfileGoalEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: OnboardingGoal?
    let title: String
    let permitsNone: Bool
    let onSave: (OnboardingGoal?) -> Void

    init(
        title: String,
        initialSelection: OnboardingGoal?,
        permitsNone: Bool,
        onSave: @escaping (OnboardingGoal?) -> Void
    ) {
        self.title = title
        _selection = State(initialValue: initialSelection)
        self.permitsNone = permitsNone
        self.onSave = onSave
    }

    var body: some View {
        ProfileEditorScaffold(
            title: title,
            canSave: permitsNone || selection != nil,
            onSave: {
                onSave(selection)
                dismiss()
            }
        ) {
            VStack(spacing: 0) {
                if permitsNone {
                    goalRow(title: "None", goal: nil)
                    Divider().padding(.leading, 14)
                }

                ForEach(Array(OnboardingGoal.allCases.enumerated()), id: \.element.id) { index, goal in
                    goalRow(title: goal.title, goal: goal)
                    if index < OnboardingGoal.allCases.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(Color.pepBorder, lineWidth: 1)
            }
        }
    }

    private func goalRow(title: String, goal: OnboardingGoal?) -> some View {
        Button {
            selection = goal
        } label: {
            HStack(spacing: Spacing.md) {
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if selection == goal {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.pepPrimary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: ProfileSettingsFigmaLayout.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == goal ? .isSelected : [])
    }
}

private struct ProfileMeasurementField: View {
    let title: String
    @Binding var value: String
    let unit: String
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            HStack {
                TextField("Not set", text: $value)
                    .keyboardType(.decimalPad)
                Text(unit)
                    .foregroundStyle(Color.pepTextSecondary)
            }
            .font(.system(.body, design: .rounded))
            .padding(14)
            .background(Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(errorMessage == nil ? Color.pepBorder : Color.pepError, lineWidth: 1)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.pepError)
            }
        }
    }
}

private struct ProfileStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.pepTextSecondary)
                Text("\(value)")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)
            }
        }
        .padding(14)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(Color.pepBorder, lineWidth: 1)
        }
    }
}

private struct ProfileEditorScaffold<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let canSave: Bool
    let onSave: () -> Void
    @ViewBuilder let content: Content

    init(
        title: String,
        canSave: Bool,
        onSave: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.canSave = canSave
        self.onSave = onSave
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(ProfileSettingsFigmaLayout.horizontalPadding)
            }
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.pepTextPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.pepPrimary)
                        .disabled(!canSave)
                }
            }
        }
        .interactiveDismissDisabled(false)
    }
}
