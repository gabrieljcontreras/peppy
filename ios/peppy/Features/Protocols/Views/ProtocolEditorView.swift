import SwiftUI

struct ProtocolEditorView: View {
    @State private var model: ProtocolEditorViewModel
    private let isCreate: Bool
    private let onSaved: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var activeCompoundSheet: CompoundSheet?
    @State private var removalCandidate: CompoundDraft?

    private enum CompoundSheet: Identifiable {
        case add
        case edit(CompoundDraft)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let draft): return "edit-\(draft.id)"
            }
        }
    }

    init(
        mode: ProtocolEditorMode,
        store: ProtocolStore,
        onSaved: @escaping (UUID) -> Void
    ) {
        _model = State(initialValue: ProtocolEditorViewModel(mode: mode, store: store))
        if case .create = mode {
            isCreate = true
        } else {
            isCreate = false
        }
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                formCard

                if let errorMessage = model.errorMessage {
                    errorBanner(errorMessage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(Color.pepBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            ProtocolPrimaryButton(
                title: isCreate ? "Save protocol" : "Save changes",
                isDisabled: !model.canSubmit,
                isLoading: model.isSubmitting
            ) {
                Task {
                    if await model.submit(), let savedID = model.savedProtocolID {
                        onSaved(savedID)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(Color.pepBackground)
        }
        .task {
            if isCreate && model.startDate == nil {
                model.startDate = Date()
            }
        }
        .sheet(item: $activeCompoundSheet) { sheet in
            compoundSheet(for: sheet)
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Remove \(removalCandidate?.name ?? "this compound") from this protocol?",
            isPresented: removalConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Remove compound", role: .destructive) {
                if let candidate = removalCandidate {
                    model.compounds.removeAll { $0.id == candidate.id }
                }
                removalCandidate = nil
            }
            Button("Cancel", role: .cancel) {
                removalCandidate = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.pepTextPrimary)
                        .frame(width: 46, height: 46)
                        .background(Color.pepSurface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.pepBorder, lineWidth: 1))
                }
                .accessibilityLabel("Back")

                Spacer()

                PeppyLogo(size: 40)
                    .padding(8)
                    .background(Color.pepSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.pepBorder, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 6) {
                PeppyLogo(size: 22, showsWordmark: true)

                Text(isCreate ? "Create protocol" : "Edit protocol")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)

                Text(isCreate ? "Build your personalized plan." : "Update your plan details.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pepTextSecondary)
            }
        }
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            nameSection
            dateSection
            notesSection

            Rectangle()
                .fill(Color.pepBorderLight)
                .frame(height: 1)

            compoundsSection
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.pepBorderLight, lineWidth: 1)
        )
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProtocolFieldLabel(text: "Protocol name", isRequired: true)

            TextField("Retatrutide Titration", text: $model.name)
                .font(.system(size: 15))
                .foregroundStyle(Color.pepTextPrimary)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 14)
                .frame(height: 54)
                .protocolFieldChrome()

            ProtocolFieldHelper(text: "Give your protocol a name you'll recognize.")
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    ProtocolFieldLabel(text: "Start date", isRequired: true)
                    dateField(
                        date: $model.startDate,
                        placeholder: "Select date",
                        clearable: false
                    )
                    ProtocolFieldHelper(text: "When your protocol begins.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    ProtocolFieldLabel(text: "End date", annotation: "(optional)")
                    dateField(
                        date: $model.endDate,
                        placeholder: "Select end date",
                        clearable: true
                    )
                    ProtocolFieldHelper(text: "Leave blank if ongoing.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let dateError = model.validation.dateRange {
                ProtocolFieldError(text: dateError)
            }
        }
    }

    private func dateField(
        date: Binding<Date?>,
        placeholder: String,
        clearable: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.pepTextSecondary)

            if let value = date.wrappedValue {
                DatePicker(
                    placeholder,
                    selection: Binding(
                        get: { value },
                        set: { date.wrappedValue = $0 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)

                if clearable {
                    Button {
                        date.wrappedValue = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.pepTextTertiary)
                    }
                    .accessibilityLabel("Clear date")
                }
            } else {
                Button {
                    date.wrappedValue = model.startDate ?? Date()
                } label: {
                    Text(placeholder)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.pepTextTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 54)
        .protocolFieldChrome()
    }

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

                if model.notes.isEmpty {
                    Text("Add any goals, context, or reminders for this protocol...")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.pepTextTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 110)
            .protocolFieldChrome()

            ProtocolFieldHelper(text: "Notes are private and only visible to you.")
        }
    }

    // MARK: - Compounds

    private var compoundsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Compounds")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)

                Text("Add the peptides and details for your protocol.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pepTextSecondary)
            }

            ForEach(model.compounds) { draft in
                compoundCard(draft)
            }

            Button {
                activeCompoundSheet = .add
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text(model.compounds.isEmpty ? "Add compound" : "Add another compound")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Color.pepPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            Color.pepPrimary.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                        )
                )
            }
            .disabled(model.isSubmitting)
            .accessibilityLabel("Add another compound")

            ProtocolFieldHelper(text: "You can add multiple compounds to a single protocol.")
        }
    }

    private func compoundCard(_ draft: CompoundDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "pill.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.pepPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.pepPrimaryMuted)
                    .clipShape(Circle())

                Text(draft.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                Button {
                    removalCandidate = draft
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Remove")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.pepError)
                    .padding(.horizontal, 13)
                    .frame(height: 38)
                    .background(Color.pepErrorMuted)
                    .clipShape(Capsule())
                }
                .disabled(model.compounds.count == 1 || model.isSubmitting)
                .opacity(model.compounds.count == 1 ? 0.45 : 1)
                .accessibilityLabel("Remove \(draft.name)")
            }

            Button {
                activeCompoundSheet = .edit(draft)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        compoundValue(label: "Dose", isRequired: true, value: doseSummary(draft))
                        compoundValue(label: "Frequency", isRequired: true, value: frequencyDisplay(draft.frequency), showsChevron: true)
                        compoundValue(label: "Route", isRequired: true, value: draft.route.capitalized, showsChevron: true)
                    }

                    if !draft.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ProtocolFieldLabel(text: "Notes", annotation: "(optional)")
                            Text(draft.notes)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.pepTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .protocolFieldChrome()
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(draft.name)")
            .accessibilityHint("Opens the compound editor")
        }
        .padding(14)
        .background(Color.pepBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.pepBorderLight, lineWidth: 1)
        )
    }

    private func compoundValue(
        label: String,
        isRequired: Bool,
        value: String,
        showsChevron: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ProtocolFieldLabel(text: label, isRequired: isRequired)

            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if showsChevron {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.pepTextSecondary)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 46)
            .frame(maxWidth: .infinity, alignment: .leading)
            .protocolFieldChrome()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func doseSummary(_ draft: CompoundDraft) -> String {
        draft.doseText.isEmpty ? "—" : "\(draft.doseText) \(draft.unit)"
    }

    private func frequencyDisplay(_ frequency: String) -> String {
        guard !frequency.isEmpty else { return "—" }
        return frequency.prefix(1).capitalized + frequency.dropFirst()
    }

    // MARK: - Compound sheet

    @ViewBuilder
    private func compoundSheet(for sheet: CompoundSheet) -> some View {
        switch sheet {
        case .add:
            CompoundEditorView(
                mode: .create,
                screenTitle: "Add compound",
                submitTitle: "Add compound"
            ) { draft in
                model.compounds.append(draft)
                return nil
            }
        case .edit(let draft):
            CompoundEditorView(
                mode: .edit(draft),
                screenTitle: "Edit compound",
                subtitle: "Update this compound's details.",
                submitTitle: "Save compound"
            ) { updated in
                if let index = model.compounds.firstIndex(where: { $0.id == updated.id }) {
                    model.compounds[index] = updated
                }
                return nil
            }
        }
    }

    // MARK: - Removal confirmation

    private var removalConfirmationBinding: Binding<Bool> {
        Binding(
            get: { removalCandidate != nil },
            set: { isPresented in
                if !isPresented {
                    removalCandidate = nil
                }
            }
        )
    }

    // MARK: - Error banner

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

#Preview {
    let dependencies = Dependencies.mock()
    NavigationStack {
        ProtocolEditorView(mode: .create, store: dependencies.protocolStore) { _ in }
    }
}
