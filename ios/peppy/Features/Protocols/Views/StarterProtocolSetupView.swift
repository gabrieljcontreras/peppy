import SwiftUI

struct StarterProtocolSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: StarterProtocolViewModel
    private let onSaved: () -> Void

    init(
        protocolID: UUID,
        compounds: [String],
        api: APIClientProtocol,
        onSaved: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: StarterProtocolViewModel(
            protocolID: protocolID,
            compounds: compounds,
            api: api
        ))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header

                    PepCard {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            if !model.compounds.isEmpty {
                                compoundSummary
                            }

                            PepTextFieldWithLabel(
                                label: "Dose",
                                placeholder: "2",
                                text: $model.doseText,
                                keyboardType: .decimalPad
                            )

                            PepTextFieldWithLabel(
                                label: "Frequency",
                                placeholder: "weekly",
                                text: $model.frequency
                            )

                            PepTextFieldWithLabel(
                                label: "Route",
                                placeholder: "subcutaneous",
                                text: $model.route
                            )

                            DatePicker(
                                "Start date",
                                selection: startDateBinding,
                                displayedComponents: .date
                            )
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.pepTextPrimary)
                        }
                    }

                    if let error = model.saveErrorMessage ?? model.validationMessage, !model.canSave {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.pepError)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let error = model.saveErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.pepError)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PepButton(
                        title: "Save protocol",
                        style: .primary,
                        isLoading: model.isSaving,
                        isDisabled: !model.canSave
                    ) {
                        Task {
                            if await model.save() {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, Spacing.lg)
            }
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationTitle("Finish setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Complete your starter protocol")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.pepTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Add the first dose details Peppy needs before tracking protocol response.")
                .font(.system(size: 14))
                .foregroundStyle(Color.pepTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var compoundSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Compound")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.pepTextPrimary)

            Text(model.compounds.joined(separator: ", "))
                .font(.system(size: 14))
                .foregroundStyle(Color.pepTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { model.startDate ?? Date() },
            set: { model.startDate = $0 }
        )
    }
}

#Preview {
    StarterProtocolSetupView(
        protocolID: UUID(),
        compounds: ["Retatrutide"],
        api: MockAPIClient()
    )
}
