import Charts
import SwiftUI

struct WeeklySummaryView: View {
    @State private var model: WeeklySummaryViewModel

    init(store: InsightsStore) {
        _model = State(initialValue: WeeklySummaryViewModel(store: store))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let payload = model.payload {
                    heroCard(payload)

                    if !payload.whatChanged.isEmpty {
                        whatChangedCard(payload.whatChanged)
                    }
                    if !payload.whatToWatch.isEmpty {
                        whatToWatchCard(payload.whatToWatch)
                    }
                    if !payload.providerQuestions.isEmpty {
                        questionsCard(payload.providerQuestions)
                    }

                    explainabilityFooter
                } else if model.hasLoaded {
                    PepEmptyState(
                        icon: "calendar",
                        title: "No summary yet",
                        message: "Your first weekly summary arrives after a week with at least 3 check-ins."
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    PepLoadingView(message: "Loading your weekly summary")
                        .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Color.pepBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.onAppear()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            PeppyLogo(size: 28, showsWordmark: true)

            Text("AI weekly summary")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.pepTextPrimary)

            if !model.weekRangeText.isEmpty {
                Text(model.weekRangeText)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pepTextSecondary)
            }
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Hero card

    private func heroCard(_ payload: WeeklySummaryPayload) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.pepPrimary.opacity(0.12))
                    Image(systemName: model.heroTrendingDown ? "arrow.down.right" : "arrow.up.right")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.pepPrimary)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 2) {
                    if let delta = model.heroDeltaText {
                        Text(delta)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color.pepPrimary)
                    }
                    Text("vs last week")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.pepTextPrimary)
                }

                Spacer()

                if model.chartPoints.count >= 2 {
                    sparkline
                        .frame(width: 120, height: 70)
                }
            }

            if let narrative = payload.narrative, model.hasNarrative {
                Text(narrative)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                if let from = payload.hero.weightFromKg, let to = payload.hero.weightToKg {
                    Text(String(format: "From %.1f kg to %.1f kg", from, to))
                }
                Spacer()
                Text(model.weekRangeCaption)
            }
            .font(.system(size: 13))
            .foregroundStyle(Color.pepTextSecondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pepPrimaryMuted)
        .cornerRadius(CornerRadius.md)
    }

    private var sparkline: some View {
        let weights = model.chartPoints.map(\.weightKg)
        let lower = (weights.min() ?? 0) - 0.5
        let upper = (weights.max() ?? 1) + 0.5
        return Chart(model.chartPoints, id: \.date) { point in
            AreaMark(
                x: .value("Day", point.date),
                yStart: .value("Baseline", lower),
                yEnd: .value("Weight", point.weightKg)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.pepPrimary.opacity(0.22), Color.pepPrimary.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Day", point.date),
                y: .value("Weight", point.weightKg)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(Color.pepPrimary)

            PointMark(
                x: .value("Day", point.date),
                y: .value("Weight", point.weightKg)
            )
            .symbolSize(20)
            .foregroundStyle(Color.pepPrimary)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: lower...upper)
    }

    // MARK: - What changed

    private func whatChangedCard(_ metrics: [WeeklySummaryMetric]) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("What changed")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.pepTextPrimary)
                    Text("Key changes compared to the prior week.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pepTextSecondary)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Spacing.sm),
                        GridItem(.flexible())
                    ],
                    spacing: Spacing.sm
                ) {
                    ForEach(metrics) { metric in
                        metricTile(metric)
                    }
                }
            }
        }
    }

    private func metricTile(_ metric: WeeklySummaryMetric) -> some View {
        let style = Self.metricStyle(for: metric.key)
        return HStack(alignment: .top, spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(style.background)
                Image(systemName: style.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(style.foreground)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.label)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pepTextPrimary)
                Text(metric.value)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(metric.positive == true ? Color.pepSuccess : Color.pepTextPrimary)
                if let detail = metric.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.pepTextSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(Color.pepSurface)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(Color.pepBorder, lineWidth: 1)
        )
    }

    private static func metricStyle(
        for key: String
    ) -> (icon: String, background: Color, foreground: Color) {
        switch key {
        case "sleep_quality": return ("moon", .pepInfoMuted, .pepInfo)
        case "dose_adherence": return ("syringe", .pepPrimaryMuted, .pepPrimary)
        case "checkins": return ("calendar", .pepWarningMuted, .pepWarning)
        case "energy": return ("bolt", .pepWarningMuted, .pepWarning)
        default: return ("chart.bar", .pepBorder, .pepTextSecondary)
        }
    }

    // MARK: - What to watch

    private func whatToWatchCard(_ items: [WeeklyWatchItem]) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.pepWarningMuted)
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.pepWarning)
                    }
                    .frame(width: 36, height: 36)

                    Text("What to watch")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.pepTextPrimary)
                }

                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(items, id: \.title) { item in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            bulletDot

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.pepTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(item.detail)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.pepTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Provider questions

    private func questionsCard(_ questions: [String]) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.pepPrimaryMuted)
                        Text("?")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.pepPrimary)
                    }
                    .frame(width: 36, height: 36)

                    Text("Questions for your provider")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.pepTextPrimary)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(questions, id: \.self) { question in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            bulletDot

                            Text(question)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.pepTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var bulletDot: some View {
        Circle()
            .fill(Color.pepTextSecondary)
            .frame(width: 4, height: 4)
            .padding(.top, 7)
    }

    // MARK: - Explainability footer

    private var explainabilityFooter: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.pepInfo)
                Image(systemName: "info")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("All insights are based on your logged data and are explainable.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("View details and sources for each insight.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pepTextSecondary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pepInfoMuted)
        .cornerRadius(CornerRadius.md)
    }
}

// MARK: - Previews

private func previewPayload(narrative: String?) -> WeeklySummaryPayload {
    WeeklySummaryPayload(
        weekStart: "2026-07-06",
        weekEnd: "2026-07-12",
        hero: WeeklySummaryHero(weightDeltaKg: -1.0, weightFromKg: 83.1, weightToKg: 82.1),
        weightSeries: [
            WeeklyWeightPoint(date: "2026-07-06", weightKg: 83.1),
            WeeklyWeightPoint(date: "2026-07-07", weightKg: 83.0),
            WeeklyWeightPoint(date: "2026-07-09", weightKg: 82.7),
            WeeklyWeightPoint(date: "2026-07-10", weightKg: 82.5),
            WeeklyWeightPoint(date: "2026-07-12", weightKg: 82.1)
        ],
        whatChanged: [
            WeeklySummaryMetric(key: "sleep_quality", label: "Sleep", value: "+38 minutes", detail: "7h 23m vs 6h 45m", positive: true),
            WeeklySummaryMetric(key: "dose_adherence", label: "Dose adherence", value: "100%", detail: "7 of 7 doses taken", positive: true),
            WeeklySummaryMetric(key: "checkins", label: "Check-ins", value: "6 of 7 days", detail: "Consistent logging", positive: nil),
            WeeklySummaryMetric(key: "energy", label: "Energy", value: "Stable", detail: "6.2 vs 6.0 avg", positive: nil)
        ],
        whatToWatch: [
            WeeklyWatchItem(title: "Nausea appears within 24 hours after dose day", detail: "Occurred 3 of 4 times this week"),
            WeeklyWatchItem(title: "Energy dips noted on dose day", detail: "Average energy 2.0/5 on dose day vs 3.4/5 other days")
        ],
        providerQuestions: [
            "Is the nausea pattern expected with this protocol?",
            "Should we consider adjusting the dose timing or amount?"
        ],
        narrative: narrative
    )
}

private func previewView(narrative: String?) -> some View {
    let deps = Dependencies.mock()
    if let api = deps.api as? MockAPIClient {
        api.setMockResponse(
            WeeklySummaryEnvelope(available: true, summary: previewPayload(narrative: narrative)),
            for: Endpoint.getWeeklySummary
        )
    }
    return NavigationStack {
        WeeklySummaryView(store: deps.insightsStore)
    }
    .withDependencies(deps)
}

#Preview("Full summary") {
    previewView(narrative: "Great progress. You're trending in the right direction.")
}

#Preview("No narrative") {
    previewView(narrative: nil)
}
