import SwiftUI

struct CheckinHubView: View {
    private let store: CheckinStore
    private let preferences: WeightUnitPreferences
    @Bindable private var navigation: ProtocolNavigationCoordinator
    @State private var model: CheckinHubViewModel

    init(
        store: CheckinStore,
        preferences: WeightUnitPreferences,
        navigation: ProtocolNavigationCoordinator
    ) {
        self.store = store
        self.preferences = preferences
        self.navigation = navigation
        _model = State(initialValue: CheckinHubViewModel(
            store: store,
            preferences: preferences
        ))
    }

    var body: some View {
        NavigationStack(path: $navigation.checkinPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    content
                    if let error = model.detailErrorMessage {
                        missingDetailCard(error)
                    }
                    if let error = model.refreshErrorMessage { retryCard(error) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, Spacing.lg)
            }
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable { await model.refresh() }
            .task { await model.loadIfNeeded() }
            .navigationDestination(for: CheckinRoute.self) { route in
                destination(route)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            PeppyLogo(size: 28, showsWordmark: true)

            Text(model.title)
                .font(.title.bold())
                .foregroundStyle(Color.pepTextPrimary)

            Text("See today's signals and revisit how you've been feeling.")
                .font(.subheadline)
                .foregroundStyle(Color.pepTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Spacing.sm)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            PepLoadingView(message: "Loading your check-ins")
                .frame(maxWidth: .infinity, minHeight: 220)
        case .failed(let message):
            VStack(spacing: Spacing.md) {
                PepEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "Check-ins couldn't load",
                    message: message
                )
                PepButton(title: "Try again", style: .primary) {
                    Task { await model.retry() }
                }
            }
        case .empty:
            VStack(spacing: Spacing.md) {
                PepEmptyState(
                    icon: "checkmark.circle",
                    title: "Start your check-in history",
                    message: "Log how you feel today so Peppy can connect changes to your protocol."
                )
                addTodayButton
            }
        case .loaded:
            if let today = model.todayDetail {
                CheckinDetailView(model: today, showsEdit: true) {
                    navigation.checkinPath.append(.edit(today.id))
                }
            } else {
                addTodayButton
            }
            historySection
        }
    }

    private var addTodayButton: some View {
        PepButton(title: "Add today's check-in", style: .primary) {
            navigation.checkinPath.append(.create)
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if !model.historyRows.isEmpty {
            Text("Recent check-ins")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.pepTextPrimary)
            VStack(spacing: Spacing.sm) {
                ForEach(model.historyRows) { row in
                    Button {
                        navigation.checkinPath.append(row.route)
                    } label: {
                        PepCard {
                            HStack(spacing: Spacing.sm) {
                                CheckinIconTile(
                                    systemName: "calendar",
                                    tint: .pepPrimary,
                                    background: .pepPrimaryMuted
                                )
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(row.dateText)
                                        .font(.headline)
                                        .foregroundStyle(Color.pepTextPrimary)
                                    Text(row.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.pepTextSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.pepTextTertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(row.dateText), \(row.summary). View check-in")
                }
            }
        }
    }

    private func retryCard(_ message: String) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Couldn't refresh check-ins")
                    .font(.headline)
                    .foregroundStyle(Color.pepTextPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                PepButton(title: "Try again", style: .secondary) {
                    Task { await model.retry() }
                }
            }
        }
    }

    private func missingDetailCard(_ message: String) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Check-in not found")
                    .font(.headline)
                    .foregroundStyle(Color.pepTextPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                PepButton(title: "Refresh check-ins", style: .secondary) {
                    Task { await model.recoverFromMissingDetail() }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: CheckinRoute) -> some View {
        switch route {
        case .create:
            CheckinEditorView(store: store, preferences: preferences, mode: .create(Date())) {
                handleEditorOutcome($0)
            }
        case .edit(let id):
            if let value = store.checkin(id: id) {
                CheckinEditorView(store: store, preferences: preferences, mode: .edit(value)) {
                    handleEditorOutcome($0)
                }
            } else {
                CheckinLoadingDestination(
                    store: store,
                    preferences: preferences,
                    navigation: navigation,
                    id: id
                )
            }
        case .detail(let id):
            CheckinLoadingDestination(
                store: store,
                preferences: preferences,
                navigation: navigation,
                id: id
            )
        }
    }

    private func handleEditorOutcome(_ outcome: CheckinEditorOutcome) {
        switch outcome {
        case .saved:
            navigation.checkinPath.removeAll()
        case .existing(let id):
            navigation.checkinPath = [.detail(id)]
        }
    }
}

// MARK: - Saved detail presentation

struct CheckinDetailView: View {
    let model: CheckinDetailModel
    let showsEdit: Bool
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            dateCard

            if !model.metrics.isEmpty {
                ratingsCard
            }

            if !model.symptoms.isEmpty {
                symptomsCard
            }

            if let notes = model.notes {
                notesCard(notes)
            }

            if showsEdit {
                PepButton(title: "Edit today's check-in", style: .primary, action: onEdit)
            }
        }
        .navigationTitle(model.isToday ? "Today's check-in" : "Check-in details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dateCard: some View {
        PepCard {
            HStack(alignment: .center, spacing: Spacing.sm) {
                CheckinIconTile(
                    systemName: "calendar",
                    tint: .pepPrimary,
                    background: .pepPrimaryMuted
                )
                Text(model.dateText)
                    .font(.headline)
                    .foregroundStyle(Color.pepTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.sm)
                PepBadge(
                    text: model.isToday ? "Today · Saved" : "Completed",
                    type: .success
                )
            }
        }
    }

    private var ratingsCard: some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                CheckinSectionHeader(text: model.isToday ? "Today's ratings" : "Ratings")

                ForEach(model.metrics) { metric in
                    let style = CheckinMetricStyle.style(for: metric.label)
                    HStack(spacing: Spacing.sm) {
                        CheckinIconTile(
                            systemName: style.icon,
                            tint: style.tint,
                            background: style.background
                        )
                        Text(metric.label)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.pepTextPrimary)
                        Spacer(minLength: Spacing.sm)
                        if style.showsPlainValue {
                            Text(metric.value)
                                .font(.headline)
                                .foregroundStyle(Color.pepTextPrimary)
                        } else {
                            Text(metric.value)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(style.tint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, Spacing.xs)
                                .background(style.background)
                                .clipShape(Capsule())
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(metric.label), \(metric.value)")
                }
            }
        }
    }

    private var symptomsCard: some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                CheckinSectionHeader(text: "Symptoms reported")

                ForEach(model.symptoms) { symptom in
                    HStack(spacing: Spacing.sm) {
                        CheckinIconTile(
                            systemName: Self.symptomIcon(symptom.label),
                            tint: .pepError,
                            background: .pepErrorMuted
                        )
                        Text(symptom.label)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.pepTextPrimary)
                        Spacer(minLength: Spacing.sm)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(symptom.severity)/10")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.pepError)
                                .padding(.horizontal, 10)
                                .padding(.vertical, Spacing.xs)
                                .background(Color.pepErrorMuted)
                                .clipShape(Capsule())
                            Text(Self.severityText(symptom.severity))
                                .font(.caption)
                                .foregroundStyle(Color.pepTextSecondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(symptom.label), severity \(symptom.severity) out of 10")
                }
            }
        }
    }

    private func notesCard(_ notes: String) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                CheckinSectionHeader(text: "Notes")
                HStack(alignment: .top, spacing: Spacing.sm) {
                    CheckinIconTile(
                        systemName: "text.quote",
                        tint: .pepTextSecondary,
                        background: .pepSurfaceElevated
                    )
                    Text(notes)
                        .font(.body)
                        .foregroundStyle(Color.pepTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private static func symptomIcon(_ label: String) -> String {
        switch label {
        case "Nausea": return "wind"
        case "Injection site": return "syringe"
        case "Fatigue": return "zzz"
        case "Headache": return "brain.head.profile"
        default: return "waveform.path.ecg"
        }
    }

    private static func severityText(_ severity: Int) -> String {
        switch severity {
        case ...3: return "Mild"
        case ...6: return "Moderate"
        default: return "Severe"
        }
    }
}

// MARK: - Shared detail styling

private struct CheckinSectionHeader: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .kerning(0.6)
            .foregroundStyle(Color.pepTextSecondary)
    }
}

private struct CheckinIconTile: View {
    let systemName: String
    let tint: Color
    let background: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(background)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

private struct CheckinMetricStyle {
    let icon: String
    let tint: Color
    let background: Color
    var showsPlainValue = false

    static func style(for label: String) -> CheckinMetricStyle {
        switch label {
        case "Weight":
            return .init(icon: "scalemass", tint: .pepPrimary, background: .pepPrimaryMuted, showsPlainValue: true)
        case "Energy":
            return .init(icon: "bolt.fill", tint: .pepPrimary, background: .pepPrimaryMuted)
        case "Mood":
            return .init(icon: "face.smiling", tint: .pepWarning, background: .pepWarningMuted)
        case "Sleep quality":
            return .init(icon: "moon.fill", tint: .pepInfo, background: .pepInfoMuted)
        case "Appetite":
            return .init(icon: "fork.knife", tint: .pepWarning, background: .pepWarningMuted)
        default:
            return .init(icon: "circle.fill", tint: .pepTextSecondary, background: .pepSurfaceElevated)
        }
    }
}

// MARK: - Detail loading destination

private struct CheckinLoadingDestination: View {
    let store: CheckinStore
    let preferences: WeightUnitPreferences
    let navigation: ProtocolNavigationCoordinator
    let id: UUID
    @State private var isLoading = false
    @State private var didFail = false

    var body: some View {
        Group {
            if let value = store.checkin(id: id) {
                ScrollView {
                    CheckinDetailView(
                        model: CheckinHubViewModel(
                            store: store,
                            preferences: preferences
                        ).detail(for: value),
                        showsEdit: false,
                        onEdit: {}
                    )
                    .padding(20)
                }
            } else if isLoading {
                PepLoadingView(message: "Loading check-in")
            } else if didFail {
                VStack(spacing: Spacing.md) {
                    PepEmptyState(
                        icon: "exclamationmark.circle",
                        title: "Couldn't load check-in",
                        message: store.detailErrorMessage ?? "Try loading this check-in again."
                    )
                    PepButton(title: "Try again", style: .secondary) {
                        Task { await loadDetail() }
                    }
                }
                .padding(20)
            } else {
                PepLoadingView(message: "Loading check-in")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pepBackground.ignoresSafeArea())
        .task { await loadDetail() }
    }

    private func loadDetail() async {
        guard store.checkin(id: id) == nil else { return }
        isLoading = true
        didFail = false
        let result = await store.loadDetail(id)
        isLoading = false
        switch result {
        case .loaded:
            break
        case .notFound:
            navigation.showCheckinHub()
        case .failed:
            didFail = true
        }
    }
}

#Preview {
    let dependencies = Dependencies.mock()
    if let api = dependencies.api as? MockAPIClient {
        api.setMockResponse(
            [
                Checkin(
                    id: UUID(),
                    userId: nil,
                    date: Date(),
                    weightKg: 74.8,
                    energyLevel: 7,
                    sleepQuality: 6,
                    appetiteLevel: 4,
                    mood: 6,
                    nausea: 0,
                    injectionSiteReaction: 3,
                    fatigue: 0,
                    headache: 0,
                    giIssues: 4,
                    notes: "Felt good overall. Went for a walk in the evening and stayed hydrated.",
                    createdAt: nil,
                    updatedAt: nil
                ),
                Checkin(
                    id: UUID(),
                    userId: nil,
                    date: Date().addingTimeInterval(-86_400),
                    weightKg: 75.0,
                    energyLevel: 7,
                    sleepQuality: 6,
                    appetiteLevel: nil,
                    mood: 6,
                    nausea: 0,
                    injectionSiteReaction: 2,
                    fatigue: 0,
                    headache: 0,
                    giIssues: 0,
                    notes: nil,
                    createdAt: nil,
                    updatedAt: nil
                ),
                Checkin(
                    id: UUID(),
                    userId: nil,
                    date: Date().addingTimeInterval(-2 * 86_400),
                    weightKg: 75.3,
                    energyLevel: 6,
                    sleepQuality: 5,
                    appetiteLevel: nil,
                    mood: 5,
                    nausea: 1,
                    injectionSiteReaction: 0,
                    fatigue: 3,
                    headache: 0,
                    giIssues: 0,
                    notes: nil,
                    createdAt: nil,
                    updatedAt: nil
                ),
            ],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
    }
    return CheckinHubView(
        store: dependencies.checkinStore,
        preferences: dependencies.weightUnitPreferences,
        navigation: dependencies.protocolNavigation
    )
}
