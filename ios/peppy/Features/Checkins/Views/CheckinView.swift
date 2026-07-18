import SwiftUI

struct CheckinEditorView: View {
    @State private var model: CheckinViewModel
    private let onComplete: (CheckinEditorOutcome) -> Void

    init(
        store: CheckinStore,
        preferences: WeightUnitPreferences,
        mode: CheckinEditorMode,
        onComplete: @escaping (CheckinEditorOutcome) -> Void
    ) {
        _model = State(initialValue: CheckinViewModel(
            store: store,
            preferences: preferences,
            mode: mode
        ))
        self.onComplete = onComplete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                metricsCard(model)
                symptomsCard(model)
                notesCard(model)

                if let error = model.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.pepError)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PepButton(
                    title: "Save check-in",
                    style: .primary,
                    isLoading: model.isSaving,
                    isDisabled: !model.canSave
                ) {
                    Task {
                        if let outcome = await model.save() {
                            onComplete(outcome)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, Spacing.lg)
        }
        .background(Color.pepBackground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("How are you today?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.pepTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Log the signals Peppy needs to understand your protocol response.")
                .font(.system(size: 14))
                .foregroundStyle(Color.pepTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metricsCard(_ model: CheckinViewModel) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Daily metrics")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)

                Picker("Weight unit", selection: Binding(
                    get: { model.selectedWeightUnit },
                    set: { model.changeWeightUnit(to: $0) }
                )) {
                    Text("lb").tag(WeightUnit.pounds)
                    Text("kg").tag(WeightUnit.kilograms)
                }
                .pickerStyle(.segmented)

                PepTextFieldWithLabel(
                    label: "Weight (\(model.selectedWeightUnit.symbol))",
                    placeholder: model.selectedWeightUnit == .pounds ? "165.0" : "74.8",
                    text: Binding(
                        get: { model.weightText },
                        set: { model.weightText = $0 }
                    ),
                    keyboardType: .decimalPad
                )

                scoreStepper("Energy", value: Binding(
                    get: { model.energyLevel },
                    set: { model.energyLevel = $0 }
                ))
                scoreStepper("Mood", value: Binding(
                    get: { model.mood },
                    set: { model.mood = $0 }
                ))
                scoreStepper("Sleep quality", value: Binding(
                    get: { model.sleepQuality },
                    set: { model.sleepQuality = $0 }
                ))
                scoreStepper("Appetite", value: Binding(
                    get: { model.appetiteLevel },
                    set: { model.appetiteLevel = $0 }
                ))
            }
        }
    }

    private func symptomsCard(_ model: CheckinViewModel) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Symptoms")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)

                severitySlider("Nausea", value: Binding(
                    get: { model.nausea },
                    set: { model.nausea = $0 }
                ))
                severitySlider("Injection site", value: Binding(
                    get: { model.injectionSiteReaction },
                    set: { model.injectionSiteReaction = $0 }
                ))
                severitySlider("Fatigue", value: Binding(
                    get: { model.fatigue },
                    set: { model.fatigue = $0 }
                ))
                severitySlider("Headache", value: Binding(
                    get: { model.headache },
                    set: { model.headache = $0 }
                ))
                severitySlider("GI issues", value: Binding(
                    get: { model.giIssues },
                    set: { model.giIssues = $0 }
                ))
            }
        }
    }

    private func notesCard(_ model: CheckinViewModel) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Notes")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)

                TextEditor(text: Binding(
                    get: { model.notes },
                    set: { model.notes = $0 }
                ))
                .font(.system(size: 14))
                .foregroundStyle(Color.pepTextPrimary)
                .frame(minHeight: 96)
                .padding(Spacing.sm)
                .scrollContentBackground(.hidden)
                .background(Color.pepSurface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(Color.pepBorder, lineWidth: 1)
                )
            }
        }
    }

    private func scoreStepper(_ title: String, value: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)
                Spacer()
                Text(value.wrappedValue.map(String.init) ?? "Not set")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.pepTextSecondary)
            }

            Stepper(value: Binding(
                get: { value.wrappedValue ?? 5 },
                set: { value.wrappedValue = $0 }
            ), in: 1...10) {
                EmptyView()
            }
        }
    }

    private func severitySlider(_ title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)
                Spacer()
                Text(value.wrappedValue == 0 ? "None" : "\(value.wrappedValue)/10")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.pepTextSecondary)
            }

            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0.rounded()) }
                ),
                in: 0...10,
                step: 1
            )
            .tint(.pepPrimary)
        }
    }
}

struct CheckinView: View {
    @Environment(\.dependencies) private var deps
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    private let onSaved: () -> Void

    init(onSaved: @escaping () -> Void = {}) {
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            CheckinEditorView(
                store: deps.checkinStore,
                preferences: deps.weightUnitPreferences,
                mode: .create(date)
            ) { _ in
                onSaved()
                dismiss()
            }
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    CheckinView()
        .withDependencies(.mock())
}
