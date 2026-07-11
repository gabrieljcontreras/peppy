import SwiftUI

struct StarterProtocolSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: StarterProtocolViewModel
    private let embedsInNavigationStack: Bool
    private let onSaved: () -> Void

    init(
        protocolID: UUID,
        compounds: [String],
        store: ProtocolStore,
        embedsInNavigationStack: Bool = true,
        onSaved: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: StarterProtocolViewModel(
            protocolID: protocolID,
            compounds: compounds,
            store: store
        ))
        self.embedsInNavigationStack = embedsInNavigationStack
        self.onSaved = onSaved
    }

    var body: some View {
        if embedsInNavigationStack {
            NavigationStack {
                content
            }
        } else {
            content
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                header
                formCard

                if let saveErrorMessage = model.saveErrorMessage {
                    errorBanner(saveErrorMessage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
        }
        .background(Color.pepBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                StarterPrimaryButton(
                    title: "Save protocol",
                    isDisabled: !model.canSave,
                    isLoading: model.isSaving
                ) {
                    Task {
                        if await model.save() {
                            onSaved()
                            dismiss()
                        }
                    }
                }

                StarterSecondaryButton(title: "I'll do this later") {
                    dismiss()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(Color.pepBackground)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            PeppyLogo(size: 40)
                .padding(.bottom, Spacing.sm)

            headline

            Text("Add your dose, frequency, and route so Peppy can start tracking with clarity.")
                .font(.system(size: 15))
                .foregroundStyle(Color.pepTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var headline: some View {
        (Text("Set up your ")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(Color.pepTextPrimary)
         + Text("first")
            .font(.system(size: 28, weight: .semibold, design: .serif))
            .italic()
            .foregroundStyle(Color.pepTextPrimary)
         + Text(" protocol.")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(Color.pepTextPrimary))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .minimumScaleFactor(0.8)
        .accessibilityLabel("Set up your first protocol.")
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !model.compounds.isEmpty {
                compoundSummary
            }

            doseSection
            frequencySection
            routeSection
            startDateSection
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.pepBorderLight, lineWidth: 1)
        )
    }

    private var compoundSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            StarterFieldLabel(text: model.compounds.count > 1 ? "Compounds" : "Compound")

            HStack(spacing: 10) {
                Image(systemName: "pill.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.pepPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.pepPrimaryMuted)
                    .clipShape(Circle())

                Text(model.compounds.joined(separator: ", "))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.pepTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 58)
            .protocolFieldChrome()
            .accessibilityElement(children: .combine)

            ProtocolFieldHelper(text: "These settings apply to every compound listed above.")
        }
    }

    private var doseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            StarterFieldLabel(text: "Dose")

            TextField("e.g. 2", text: $model.doseText)
                .font(.system(size: 16))
                .foregroundStyle(Color.pepTextPrimary)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 16)
                .frame(height: 58)
                .protocolFieldChrome()
                .accessibilityLabel("Dose in milligrams")

            ProtocolFieldHelper(text: "In milligrams (mg).")
        }
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            StarterFieldLabel(text: "Frequency")

            TextField("e.g. weekly", text: $model.frequency)
                .font(.system(size: 16))
                .foregroundStyle(Color.pepTextPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(height: 58)
                .protocolFieldChrome()
                .accessibilityLabel("Frequency")

            ProtocolFieldHelper(text: "How often you'll take this dose.")
        }
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            StarterFieldLabel(text: "Route")

            TextField("e.g. subcutaneous", text: $model.route)
                .font(.system(size: 16))
                .foregroundStyle(Color.pepTextPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(height: 58)
                .protocolFieldChrome()
                .accessibilityLabel("Administration route")

            ProtocolFieldHelper(text: "How the compound is administered.")
        }
    }

    private var startDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            StarterFieldLabel(text: "Start date")

            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.pepPrimary)

                DatePicker(
                    "Start date",
                    selection: startDateBinding,
                    displayedComponents: .date
                )
                .labelsHidden()
                .tint(Color.pepPrimary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .protocolFieldChrome()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Start date")

            ProtocolFieldHelper(text: "When you'll begin this protocol.")
        }
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { model.startDate ?? Date() },
            set: { model.startDate = $0 }
        )
    }

    // MARK: - Error

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
}

// MARK: - Starter-only local styling
//
// These mirror Peppy's shared button shapes but use this screen's Figma-specified
// ink-black primary / outlined secondary treatment, which no shared component
// currently renders (PepButton's `.primary` style is close but sized and weighted
// differently; ProtocolPrimaryButton is hardcoded to the red primary color).

private struct StarterFieldLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Color.pepTextSecondary)
            .accessibilityLabel(text)
    }
}

private struct StarterPrimaryButton: View {
    let title: String
    var isDisabled = false
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(isDisabled ? Color.pepInk.opacity(0.45) : Color.pepInk)
            .clipShape(Capsule())
        }
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(isLoading ? "\(title), in progress" : title)
    }
}

private struct StarterSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.pepTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Color.pepSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.pepBorder, lineWidth: 1)
                )
        }
        .accessibilityLabel(title)
    }
}

#Preview {
    let dependencies = Dependencies.mock()
    StarterProtocolSetupView(
        protocolID: UUID(),
        compounds: ["Retatrutide"],
        store: dependencies.protocolStore
    )
}
