import SwiftUI

struct InsightsListView: View {
    static let learningTitle = "peppy is learning your patterns."
    static let learningMessage = "Keep checking in daily and logging doses"

    let store: InsightsStore
    @Environment(\.dependencies) private var deps
    @Bindable private var navigation: ProtocolNavigationCoordinator
    @State private var model: InsightsListViewModel
    @State private var toast: Toast?

    init(store: InsightsStore, navigation: ProtocolNavigationCoordinator) {
        self.store = store
        self.navigation = navigation
        _model = State(initialValue: InsightsListViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $navigation.insightsPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    filterChips

                    if model.showsSummaryCard {
                        weeklySummaryCard
                    }

                    if store.insights.isEmpty && store.isLoading {
                        PepLoadingView(message: "Loading your insights")
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if model.showsLearningState {
                        PepEmptyState(
                            icon: "sparkles",
                            title: Self.learningTitle,
                            message: Self.learningMessage
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        insightSections
                    }

                    privacyFooter
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable {
                await model.refresh()
            }
            .navigationDestination(for: InsightRoute.self) { route in
                switch route {
                case .detail(let id):
                    InsightDetailView(store: store, api: deps.api, insightID: id)
                case .weeklySummary:
                    WeeklySummaryView(store: store)
                }
            }
            .task {
                await model.onAppear()
            }
            .onChange(of: store.errorMessage) {
                if let message = store.errorMessage {
                    toast = Toast(message: message, type: .error)
                }
            }
            .pepToast($toast)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            PeppyLogo(size: 28, showsWordmark: true)

            HStack(spacing: Spacing.sm) {
                Text("Insights")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)

                if store.unreadCount > 0 {
                    Text("\(store.unreadCount)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.pepPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.pepPrimaryMuted)
                        .clipShape(Capsule())
                }
            }

            Text("AI-powered insights from your check-ins and protocol data.")
                .font(.system(size: 13))
                .foregroundStyle(Color.pepTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Filters

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(InsightTypeFilter.allCases) { option in
                    PepSelectionChip(title: option.title, isSelected: model.filter == option) {
                        model.filter = option
                    }
                }
            }
        }
    }

    // MARK: - Weekly summary entry

    private var weeklySummaryCard: some View {
        NavigationLink(value: InsightRoute.weeklySummary) {
            PepCard {
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.pepPrimaryMuted)
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.pepPrimary)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI weekly summary")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.pepTextPrimary)
                        Text(weekRangeText)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pepTextSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.pepTextTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var weekRangeText: String {
        guard let summary = store.weekly?.summary,
              let start = Self.isoDayFormatter.date(from: summary.weekStart),
              let end = Self.isoDayFormatter.date(from: summary.weekEnd) else {
            return "Last week"
        }
        let startText = Self.dayFormatter.string(from: start)
        let endText = Self.dayFormatter.string(from: end)
        return "\(startText) – \(endText)"
    }

    // MARK: - Sections

    private var insightSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !model.unread.isEmpty {
                sectionHeader("Unread")
                insightLinks(model.unread)
            }

            if !model.earlier.isEmpty {
                sectionHeader("Earlier")
                insightLinks(model.earlier)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.pepTextPrimary)
    }

    private func insightLinks(_ insights: [Insight]) -> some View {
        VStack(spacing: Spacing.md) {
            ForEach(insights) { insight in
                NavigationLink(value: InsightRoute.detail(insight.id)) {
                    InsightCardView(insight: insight)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Privacy footer

    private var privacyFooter: some View {
        PepCard {
            HStack(alignment: .top, spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.pepPrimaryMuted)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.pepPrimary)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Your data is private and secure.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.pepTextPrimary)

                    Text("Your data is used only to generate your insights. It's never sold and never used to train AI models.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pepTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Formatters

    private static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

#Preview {
    let deps = Dependencies.mock()
    if let api = deps.api as? MockAPIClient {
        api.setMockResponse(
            [
                Insight.fixture(title: "Weight loss is accelerating"),
                Insight.fixture(
                    type: "anomaly",
                    severity: "warning",
                    title: "Nausea is appearing after dose day",
                    description: "You've logged nausea within 24 hours after your dose on 3 of the last 4 occurrences.",
                    confidence: 0.6
                ),
                Insight.fixture(
                    type: "milestone",
                    title: "7-day check-in streak",
                    description: "You've checked in every day for the last 7 days.",
                    confidence: 0.9,
                    readAt: Date()
                )
            ],
            for: Endpoint.getInsights(unreadOnly: nil, type: nil, severity: nil)
        )
        api.setMockResponse(
            WeeklySummaryEnvelope(
                available: true,
                summary: WeeklySummaryPayload(
                    weekStart: "2026-07-06",
                    weekEnd: "2026-07-12",
                    hero: WeeklySummaryHero(weightDeltaKg: -0.8, weightFromKg: 84.9, weightToKg: 84.1),
                    weightSeries: [],
                    whatChanged: [],
                    whatToWatch: [],
                    providerQuestions: [],
                    narrative: nil
                )
            ),
            for: Endpoint.getWeeklySummary
        )
    }
    return InsightsListView(store: deps.insightsStore, navigation: deps.protocolNavigation)
        .withDependencies(deps)
}

#Preview("Insights learning state") {
    let deps = Dependencies.mock()
    if let api = deps.api as? MockAPIClient {
        api.setMockResponse(
            [Insight](),
            for: Endpoint.getInsights(unreadOnly: nil, type: nil, severity: nil)
        )
        api.setMockResponse(
            WeeklySummaryEnvelope(available: false, summary: nil),
            for: Endpoint.getWeeklySummary
        )
    }
    return InsightsListView(
        store: deps.insightsStore,
        navigation: deps.protocolNavigation
    )
    .withDependencies(deps)
}
