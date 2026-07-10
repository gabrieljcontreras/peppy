import SwiftUI

struct ProtocolDetailView: View {
    @State private var model: ProtocolDetailViewModel
    private let navigate: (ProtocolRoute) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showsAllDoses = false

    init(
        protocolID: UUID,
        store: ProtocolStore,
        navigate: @escaping (ProtocolRoute) -> Void
    ) {
        _model = State(initialValue: ProtocolDetailViewModel(protocolID: protocolID, store: store))
        self.navigate = navigate
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if model.protocolValue == nil {
                    if let errorMessage = model.errorMessage {
                        retryState(errorMessage)
                    } else {
                        PepLoadingView(message: "Loading protocol")
                            .frame(minHeight: 280)
                    }
                } else {
                    content
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Color.pepBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .refreshable {
            await model.refresh()
        }
        .task {
            await model.load()
        }
        .onChange(of: model.didDelete) { _, didDelete in
            if didDelete {
                dismiss()
            }
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: confirmationBinding,
            titleVisibility: .visible
        ) {
            confirmationActions
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

            VStack(alignment: .leading, spacing: 10) {
                PeppyLogo(size: 22, showsWordmark: true)

                Text(model.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if let status = model.status {
                    ProtocolStatusPill(status: status, text: model.statusText)
                }
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            dateSummaryRow

            if let errorMessage = model.errorMessage {
                inlineError(errorMessage)
            }

            timelineCard
            compoundCard
            doseHistoryCard

            if let notes = model.notesText {
                notesCard(notes)
            }

            managementActions
        }
    }

    private var dateSummaryRow: some View {
        Button {
            navigate(model.editRoute)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.pepTextSecondary)

                Text(model.startDateText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.pepTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Rectangle()
                    .fill(Color.pepBorder)
                    .frame(width: 1, height: 20)

                Text(model.endDateText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.pepTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.pepTextTertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.startDateText), \(model.endDateText). Edit protocol dates")
    }

    private var timelineCard: some View {
        ProtocolSectionCard(title: "Protocol timeline") {
            ProtocolPhaseTimeline(
                phases: [
                    ProtocolTimelinePhase(title: "Started", subtitle: model.startMarkerText),
                    ProtocolTimelinePhase(title: model.statusText, subtitle: currentPhaseSubtitle),
                    ProtocolTimelinePhase(
                        title: model.protocolValue?.endDate == nil ? "Ongoing" : "Ends",
                        subtitle: model.endMarkerText
                    ),
                ],
                currentIndex: model.completedTimelineSteps
            )
        }
    }

    private var currentPhaseSubtitle: String {
        switch model.status {
        case .active: return "In progress"
        case .inactive: return "Completed"
        case .pendingSetup, nil: return "Not started"
        }
    }

    private var compoundCard: some View {
        ProtocolSectionCard(title: model.compoundDetails.count > 1 ? "Compounds" : "Compound") {
            Button {
                navigate(model.addCompoundRoute)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color.pepPrimary)
            }
            .disabled(model.isMutating)
            .accessibilityLabel("Add compound")
        } content: {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(model.compoundDetails.enumerated()), id: \.element.id) { index, compound in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.pepBorderLight)
                            .frame(height: 1)
                    }
                    compoundBlock(compound)
                }
            }
        }
    }

    private func compoundBlock(_ compound: CompoundDetailModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "pill.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.pepPrimary)
                    .frame(width: 54, height: 54)
                    .background(Color.pepPrimaryMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(compound.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(compound.doseChipText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.pepPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.pepPrimaryMuted)
                    .clipShape(Capsule())

                Spacer(minLength: 4)

                Button {
                    navigate(model.editCompoundRoute(compoundID: compound.id))
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.pepTextSecondary)
                        .frame(width: 38, height: 38)
                        .background(Color.pepSurfaceElevated)
                        .clipShape(Circle())
                }
                .disabled(model.isMutating)
                .accessibilityLabel("Edit \(compound.name)")
            }

            VStack(alignment: .leading, spacing: 12) {
                ProtocolInfoRow(icon: "calendar", label: "Dose & frequency", value: compound.doseFrequencyText)
                ProtocolInfoRow(icon: "syringe", label: "Route", value: compound.routeText)
                if let notes = compound.notes, !notes.isEmpty {
                    ProtocolInfoRow(icon: "doc.text", label: "Notes", value: notes)
                }
            }

            if model.canLogDose {
                Rectangle()
                    .fill(Color.pepBorderLight)
                    .frame(height: 1)

                HStack(spacing: 14) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.pepPrimary)
                        .frame(width: 46, height: 46)
                        .background(Color.pepPrimaryMuted)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next scheduled dose")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pepTextSecondary)

                        if let nextDoseDateText = compound.nextDoseDateText {
                            Text(nextDoseDateText)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.pepTextPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        } else {
                            Text("As scheduled")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.pepTextPrimary)
                        }

                        Text(compound.nextDoseAmountText)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pepTextSecondary)
                    }

                    Spacer(minLength: 8)

                    Button {
                        navigate(model.logDoseRoute(compoundID: compound.id))
                    } label: {
                        Text("Log dose")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.pepPrimary)
                            .padding(.horizontal, 20)
                            .frame(height: 44)
                            .background(Color.pepSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.pepPrimary, lineWidth: 1.5))
                    }
                    .disabled(model.isMutating)
                    .accessibilityLabel("Log dose for \(compound.name)")
                }
            }
        }
    }

    private var doseHistoryCard: some View {
        ProtocolSectionCard(title: "Recent dose history") {
            if model.hasMoreDoseRows {
                Button {
                    withAnimation { showsAllDoses.toggle() }
                } label: {
                    Text(showsAllDoses ? "Show less" : "View all")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.pepPrimary)
                }
                .accessibilityLabel(showsAllDoses ? "Show fewer doses" : "View all doses")
            }
        } content: {
            let rows = showsAllDoses ? model.allDoseRows : model.recentDoseRows
            if rows.isEmpty {
                Text("No doses logged yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pepTextSecondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            Rectangle()
                                .fill(Color.pepBorderLight)
                                .frame(height: 1)
                        }
                        ProtocolDoseHistoryRow(row: row)
                    }
                }
            }
        }
    }

    private func notesCard(_ notes: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "doc.text")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.pepWarning)
                .frame(width: 46, height: 46)
                .background(Color.pepWarningMuted)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text("Protocol notes")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)

                Text(notes)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
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

    // MARK: - Management actions

    private var managementActions: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    navigate(model.editRoute)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Edit protocol")
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(Color.pepPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.pepSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.pepPrimary.opacity(0.45), lineWidth: 1)
                    )
                }
                .disabled(!model.canEdit || model.isMutating)

                if model.canDeactivate {
                    statusActionButton(
                        title: "Deactivate protocol",
                        icon: "pause.circle"
                    ) {
                        model.requestDeactivate()
                    }
                } else if model.canActivate {
                    statusActionButton(
                        title: "Activate protocol",
                        icon: "play.circle"
                    ) {
                        Task { await model.activate() }
                    }
                }
            }

            if model.canDelete {
                Button {
                    model.requestDelete()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Delete protocol")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Color.pepError)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.pepErrorMuted.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(model.isMutating)
                .accessibilityHint("Deletes this protocol permanently")
            }

            if model.isMutating {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Updating protocol")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pepTextSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func statusActionButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(Color.pepTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.pepSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.pepBorder, lineWidth: 1)
            )
        }
        .disabled(model.isMutating)
    }

    // MARK: - Confirmation dialog

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { model.pendingConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    model.cancelPendingConfirmation()
                }
            }
        )
    }

    private var confirmationTitle: String {
        switch model.pendingConfirmation {
        case .delete:
            return "Delete this protocol? This can't be undone."
        case .deactivate, nil:
            return "Deactivate this protocol? You can reactivate it later."
        }
    }

    @ViewBuilder
    private var confirmationActions: some View {
        if model.pendingConfirmation == .delete {
            Button("Delete protocol", role: .destructive) {
                model.confirmFromDialog()
            }
        } else {
            Button("Deactivate protocol") {
                model.confirmFromDialog()
            }
        }
        Button("Cancel", role: .cancel) {
            model.cancelPendingConfirmation()
        }
    }

    // MARK: - Error states

    private func retryState(_ message: String) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.pepWarning)
                    .fixedSize(horizontal: false, vertical: true)

                PepButton(title: "Retry", style: .secondary) {
                    Task { await model.refresh() }
                }
            }
        }
    }

    private func inlineError(_ message: String) -> some View {
        Label(message, systemImage: "wifi.exclamationmark")
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
        ProtocolDetailView(
            protocolID: UUID(),
            store: dependencies.protocolStore
        ) { _ in }
    }
}
