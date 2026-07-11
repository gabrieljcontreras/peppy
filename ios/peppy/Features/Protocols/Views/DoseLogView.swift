import SwiftUI

struct DoseLogView: View {
    @State private var model: DoseLogViewModel
    private let onLogged: @MainActor () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hasEditedDose = false

    init(
        protocol protocolValue: ProtocolModel,
        compound: Compound,
        store: ProtocolStore,
        onLogged: @escaping @MainActor () -> Void = {}
    ) {
        _model = State(initialValue: DoseLogViewModel(
            protocol: protocolValue,
            compound: compound,
            store: store
        ))
        self.onLogged = onLogged
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                contextCard
                amountSection
                dateTimeSection
                protocolSection
                notesSection

                if let errorMessage = model.errorMessage {
                    errorBanner(errorMessage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
        }
        .background(Color.pepBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            ProtocolPrimaryButton(
                title: "Confirm dose",
                systemImage: "checkmark.circle",
                isDisabled: !model.canSubmit,
                isLoading: model.isSubmitting
            ) {
                submit()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(Color.pepBackground)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text("Log dose")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.pepTextPrimary)
                        .frame(width: 42, height: 42)
                        .background(Color.pepSurface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.pepBorder, lineWidth: 1))
                }
                .accessibilityLabel("Close")
            }

            Text("Record your dose to stay on track.")
                .font(.system(size: 15))
                .foregroundStyle(Color.pepTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Compound context

    private var contextCard: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "cross.vial")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.pepPrimary)
                .frame(width: 54, height: 54)
                .background(Color.pepPrimaryMuted)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(model.compoundName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.pepTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 7) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 8, height: 8)

                    Text(model.protocolName)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.pepTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Text(model.weekProgressText)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pepTextSecondary)
            }

            Spacer(minLength: 8)

            Button {
                dismiss()
            } label: {
                HStack(spacing: 5) {
                    Text("View protocol")
                        .font(.system(size: 14, weight: .semibold))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.pepPrimary)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Color.pepSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.pepPrimary, lineWidth: 1.5))
            }
            .accessibilityLabel("View protocol \(model.protocolName)")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.pepBorderLight, lineWidth: 1)
        )
    }

    private var statusDotColor: Color {
        switch model.protocolStatus {
        case .active: return .pepSuccess
        case .pendingSetup: return .pepWarning
        case .inactive: return .pepTextSecondary
        }
    }

    // MARK: - Amount

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtocolFieldLabel(text: "Amount", isRequired: true)

            HStack(spacing: 10) {
                TextField("0", text: $model.doseText)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pepTextPrimary)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 14)
                    .frame(height: 54)
                    .frame(maxWidth: .infinity)
                    .protocolFieldChrome()
                    .onChange(of: model.doseText) { _, _ in
                        hasEditedDose = true
                    }

                ForEach(Self.unitOptions, id: \.self) { unit in
                    unitChip(unit)
                }
            }

            if hasEditedDose, let error = model.validation.dose {
                ProtocolFieldError(text: error)
            } else {
                ProtocolFieldHelper(text: model.scheduledAmountText)
            }
        }
    }

    private func unitChip(_ unit: String) -> some View {
        let isSelected = model.unit == unit
        return Button {
            model.unit = unit
        } label: {
            Text(unit)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? Color.pepPrimary : Color.pepTextPrimary)
                .frame(width: 58, height: 54)
                .background(isSelected ? Color.pepPrimaryMuted : Color.pepSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.pepPrimary : Color.pepBorder, lineWidth: 1)
                )
        }
        .accessibilityLabel("Unit \(unit)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Date & time

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtocolFieldLabel(text: "Date & time", isRequired: true)

            HStack(spacing: 10) {
                dateTimeField(icon: "calendar", components: .date)
                dateTimeField(icon: "clock", components: .hourAndMinute)
            }

            ProtocolFieldHelper(text: "Defaults to today at the current time.")
        }
    }

    private func dateTimeField(
        icon: String,
        components: DatePickerComponents
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.pepTextSecondary)

            DatePicker(
                "",
                selection: $model.administeredAt,
                displayedComponents: components
            )
            .labelsHidden()
            .tint(Color.pepPrimary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .protocolFieldChrome()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(components == .date ? "Dose date" : "Dose time")
    }

    // MARK: - Protocol

    private var protocolSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtocolFieldLabel(text: "Protocol")

            HStack(spacing: 10) {
                Text(model.protocolName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.pepTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                ProtocolStatusPill(status: model.protocolStatus, text: model.protocolStatusText)
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .protocolFieldChrome()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Protocol \(model.protocolName), \(model.protocolStatusText)")

            ProtocolFieldHelper(text: "This dose will be added to this protocol.")
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtocolFieldLabel(text: "Notes", annotation: "(optional)")

            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.notes)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pepTextPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .onChange(of: model.notes) { _, newValue in
                        if newValue.count > Self.notesLimit {
                            model.notes = String(newValue.prefix(Self.notesLimit))
                        }
                    }

                if model.notes.isEmpty {
                    Text("Add a note about this dose...")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.pepTextTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(model.notes.count)/\(Self.notesLimit)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pepTextSecondary)
                            .padding(10)
                    }
                }
            }
            .frame(minHeight: 118)
            .protocolFieldChrome()

            ProtocolFieldHelper(text: "Notes are private and only visible to you.")
        }
    }

    // MARK: - Error and submit

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pepWarning)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pepWarningMuted)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func submit() {
        guard model.canSubmit else { return }

        Task {
            if await model.submit() {
                onLogged()
                dismiss()
            }
        }
    }

    private static let notesLimit = 250
    private static let unitOptions = ["mg", "mcg", "IU"]
}

#Preview {
    let dependencies = Dependencies.mock()
    DoseLogView(
        protocol: ProtocolModel(
            id: UUID(),
            name: "Retatrutide Titration",
            startDate: Date().addingTimeInterval(-5 * 7 * 86_400),
            endDate: Date().addingTimeInterval(7 * 7 * 86_400),
            notes: nil,
            isActive: true,
            setupStatus: "active",
            isStarter: false,
            compounds: []
        ),
        compound: Compound(
            id: UUID(),
            name: "Retatrutide",
            doseMg: 4,
            doseUnit: "mg",
            frequency: "weekly",
            administrationRoute: "subcutaneous",
            notes: nil
        ),
        store: dependencies.protocolStore
    )
}
