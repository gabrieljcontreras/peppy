import SwiftUI

struct CompoundEditorView: View {
    @State private var model: CompoundEditorViewModel
    private let screenTitle: String
    private let subtitle: String
    private let submitTitle: String
    private let onSubmit: @MainActor (CompoundDraft) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var isCustomFrequency: Bool
    @State private var touchedFields: Set<CompoundField> = []

    private enum CompoundField {
        case name
        case dose
        case frequency
    }

    init(
        mode: CompoundEditorMode,
        screenTitle: String,
        subtitle: String = "Add the peptide and details to include in your protocol.",
        submitTitle: String,
        onSubmit: @escaping @MainActor (CompoundDraft) async -> String?
    ) {
        _model = State(initialValue: CompoundEditorViewModel(mode: mode))
        self.screenTitle = screenTitle
        self.subtitle = subtitle
        self.submitTitle = submitTitle
        self.onSubmit = onSubmit

        if case .edit(let draft) = mode {
            _isCustomFrequency = State(initialValue:
                !draft.frequency.isEmpty && !Self.frequencyOptions.contains { $0.value == draft.frequency }
            )
        } else {
            _isCustomFrequency = State(initialValue: false)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                nameSection
                doseSection
                frequencySection
                routeSection
                notesSection

                if let errorMessage {
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
                title: submitTitle,
                isDisabled: !model.canSubmit,
                isLoading: isSubmitting
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
                Text(screenTitle)
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

            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Color.pepTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Peptide name

    private var nameSuggestions: [String] {
        let query = model.name.trimmed
        guard !query.isEmpty else { return [] }
        return PeptideCatalog.names
            .filter {
                $0.localizedCaseInsensitiveContains(query) &&
                    $0.caseInsensitiveCompare(query) != .orderedSame
            }
            .prefix(4)
            .map { $0 }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtocolFieldLabel(text: "Peptide name", isRequired: true)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.pepTextTertiary)

                TextField("Search peptides", text: $model.name)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pepTextPrimary)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onChange(of: model.name) { _, _ in
                        touchedFields.insert(.name)
                    }
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .protocolFieldChrome()

            if !nameSuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(nameSuggestions, id: \.self) { suggestion in
                        Button {
                            model.name = suggestion
                        } label: {
                            HStack {
                                Text(suggestion)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.pepTextPrimary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.pepPrimary)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                        }

                        if suggestion != nameSuggestions.last {
                            Rectangle()
                                .fill(Color.pepBorderLight)
                                .frame(height: 1)
                        }
                    }
                }
                .protocolFieldChrome()
            }

            if touchedFields.contains(.name), let error = model.validation.name {
                ProtocolFieldError(text: error)
            } else {
                ProtocolFieldHelper(text: "Search by name or synonym")
            }
        }
    }

    // MARK: - Dose

    private var doseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtocolFieldLabel(text: "Dose", isRequired: true)

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
                        touchedFields.insert(.dose)
                    }

                ForEach(Self.unitOptions, id: \.self) { unit in
                    unitChip(unit)
                }
            }

            if touchedFields.contains(.dose), let error = model.validation.dose {
                ProtocolFieldError(text: error)
            } else {
                ProtocolFieldHelper(text: "Enter the amount per dose.")
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

    // MARK: - Frequency

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtocolFieldLabel(text: "Frequency", isRequired: true)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                ForEach(Self.frequencyOptions, id: \.value) { option in
                    frequencyChip(option)
                }
                customFrequencyChip
            }

            if isCustomFrequency {
                TextField("Describe your schedule", text: $model.frequency)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pepTextPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .frame(height: 54)
                    .protocolFieldChrome()
                    .onChange(of: model.frequency) { _, _ in
                        touchedFields.insert(.frequency)
                    }
            }

            if touchedFields.contains(.frequency), let error = model.validation.frequency {
                ProtocolFieldError(text: error)
            } else {
                ProtocolFieldHelper(text: "How often you'll take this compound.")
            }
        }
    }

    private func frequencyChip(_ option: FrequencyOption) -> some View {
        let isSelected = !isCustomFrequency && model.frequency == option.value
        return Button {
            isCustomFrequency = false
            model.frequency = option.value
            touchedFields.insert(.frequency)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: option.icon)
                    .font(.system(size: 14, weight: .medium))

                Text(option.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.pepPrimary : Color.pepTextPrimary)
            .padding(.horizontal, 13)
            .frame(height: 52)
            .background(isSelected ? Color.pepPrimaryMuted : Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.pepPrimary : Color.pepBorder, lineWidth: 1)
            )
        }
        .accessibilityLabel("Frequency \(option.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var customFrequencyChip: some View {
        Button {
            if !isCustomFrequency {
                isCustomFrequency = true
                model.frequency = ""
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .medium))

                Text("Custom")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(isCustomFrequency ? Color.pepPrimary : Color.pepTextPrimary)
            .padding(.horizontal, 13)
            .frame(height: 52)
            .background(isCustomFrequency ? Color.pepPrimaryMuted : Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isCustomFrequency ? Color.pepPrimary : Color.pepBorder, lineWidth: 1)
            )
        }
        .accessibilityLabel("Frequency Custom")
        .accessibilityAddTraits(isCustomFrequency ? .isSelected : [])
    }

    // MARK: - Route

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtocolFieldLabel(text: "Route", isRequired: true)

            HStack(spacing: 8) {
                ForEach(Self.routeOptions, id: \.value) { option in
                    routeTile(option)
                }
            }

            ProtocolFieldHelper(text: "How the compound will be administered.")
        }
    }

    private func routeTile(_ option: RouteOption) -> some View {
        let isSelected = model.route == option.value
        return Button {
            model.route = option.value
        } label: {
            VStack(spacing: 7) {
                Image(systemName: option.icon)
                    .font(.system(size: 17, weight: .medium))

                Text(option.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? Color.pepPrimary : Color.pepTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(isSelected ? Color.pepPrimaryMuted : Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.pepPrimary : Color.pepBorder, lineWidth: 1)
            )
        }
        .accessibilityLabel("Route \(option.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    Text("Add any notes about this compound...")
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
        guard !isSubmitting, let draft = model.submitDraft() else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            let error = await onSubmit(draft)
            isSubmitting = false
            if let error {
                errorMessage = error
            } else {
                dismiss()
            }
        }
    }

    // MARK: - Options

    private static let notesLimit = 250
    private static let unitOptions = ["mg", "mcg", "IU"]

    private struct FrequencyOption {
        let title: String
        let value: String
        let icon: String
    }

    private struct RouteOption {
        let title: String
        let value: String
        let icon: String
    }

    private static let frequencyOptions: [FrequencyOption] = [
        FrequencyOption(title: "Daily", value: "daily", icon: "sun.max"),
        FrequencyOption(title: "Every other day", value: "every other day", icon: "arrow.triangle.2.circlepath"),
        FrequencyOption(title: "Twice weekly", value: "twice weekly", icon: "calendar"),
        FrequencyOption(title: "Weekly", value: "weekly", icon: "calendar"),
        FrequencyOption(title: "Every 10 days", value: "every 10 days", icon: "calendar"),
        FrequencyOption(title: "Biweekly", value: "biweekly", icon: "calendar"),
        FrequencyOption(title: "Monthly", value: "monthly", icon: "calendar"),
    ]

    private static let routeOptions: [RouteOption] = [
        RouteOption(title: "Subcutaneous", value: "subcutaneous", icon: "syringe"),
        RouteOption(title: "Intramuscular", value: "intramuscular", icon: "syringe.fill"),
        RouteOption(title: "Oral", value: "oral", icon: "pill"),
        RouteOption(title: "Nasal", value: "nasal", icon: "nose"),
        RouteOption(title: "Other", value: "other", icon: "ellipsis"),
    ]
}

#Preview {
    CompoundEditorView(
        mode: .create,
        screenTitle: "Add compound",
        submitTitle: "Add compound"
    ) { _ in nil }
}
