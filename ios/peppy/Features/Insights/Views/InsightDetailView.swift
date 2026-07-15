import SwiftUI

struct InsightDetailView: View {
    @Environment(\.dependencies) private var deps
    @Environment(\.dismiss) private var dismiss
    @State private var model: InsightDetailViewModel

    init(store: InsightsStore, api: APIClientProtocol, insightID: UUID) {
        _model = State(initialValue: InsightDetailViewModel(store: store, api: api, insightID: insightID))
    }

    var body: some View {
        Group {
            if let insight = model.insight {
                content(insight)
            } else {
                PepLoadingView(message: "Loading insight")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.pepBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.onAppear()
        }
        .onChange(of: model.didCompleteAction) {
            guard model.didCompleteAction else { return }
            if let message = model.completedActionMessage {
                deps.appState.showSuccess(message)
            }
            dismiss()
        }
    }

    private func content(_ insight: Insight) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PepBadge(text: insight.typeDisplayName, type: insight.typeBadgeStyle)

                Text(insight.title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(insight.formattedTimestamp)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pepTextSecondary)

                statCard(insight)
                observationCard(insight)
                whyCard(insight)
                disclaimerBanner
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
    }

    // MARK: - Stat card

    private func statCard(_ insight: Insight) -> some View {
        PepCard {
            HStack(spacing: 0) {
                statColumn(header: "Type", label: insight.typeDisplayName, labelColor: insight.typeBadgeStyle.textColor) {
                    ZStack {
                        Circle()
                            .fill(insight.typeBadgeStyle.backgroundColor)
                        Image(systemName: insight.typeIcon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(insight.typeBadgeStyle.textColor)
                    }
                    .frame(width: 56, height: 56)
                }

                Rectangle()
                    .fill(Color.pepBorder)
                    .frame(width: 1)

                statColumn(header: "Severity", label: insight.severityDisplayName, labelColor: insight.severityBadgeStyle.textColor) {
                    ZStack {
                        Circle()
                            .fill(insight.severityBadgeStyle.backgroundColor)
                        Image(systemName: insight.severityIcon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(insight.severityBadgeStyle.textColor)
                    }
                    .frame(width: 56, height: 56)
                }

                Rectangle()
                    .fill(Color.pepBorder)
                    .frame(width: 1)

                statColumn(header: "Confidence", label: insight.confidenceLabel, labelColor: insight.confidenceColor) {
                    ConfidenceRing(confidence: insight.confidence)
                        .frame(width: 56, height: 56)
                }
            }
        }
    }

    private func statColumn(
        header: String,
        label: String,
        labelColor: Color,
        @ViewBuilder visual: () -> some View
    ) -> some View {
        VStack(spacing: Spacing.sm) {
            Text(header)
                .font(.system(size: 13))
                .foregroundStyle(Color.pepTextSecondary)
            visual()
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(labelColor)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Observation card

    private func observationCard(_ insight: Insight) -> some View {
        PepCard {
            HStack(alignment: .top, spacing: Spacing.md) {
                iconCircle("quote.opening", background: .pepSuccessMuted, foreground: .pepSuccess)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Plain-English observation")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.pepTextPrimary)

                    Text(insight.description)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.pepTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Why card

    private func whyCard(_ insight: Insight) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    iconCircle("sparkles", background: .pepPrimaryMuted, foreground: .pepPrimary)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Why peppy noticed this")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.pepTextPrimary)

                        Text(insight.explanation)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.pepTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let items = insight.supportingData, !items.isEmpty {
                    Divider()

                    Text("Supporting references")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.pepTextPrimary)

                    VStack(spacing: Spacing.md) {
                        ForEach(items, id: \.self) { item in
                            supportingRow(item)
                        }
                    }
                }
            }
        }
    }

    private func supportingRow(_ item: InsightSupportingItem) -> some View {
        let style = Self.referenceStyle(for: item.iconKey)
        return HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(style.background)
                Image(systemName: style.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(style.foreground)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.pepTextPrimary)
                if let sublabel = item.sublabel {
                    Text(sublabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.pepTextSecondary)
                }
            }

            Spacer()

            Text(item.value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(style.foreground)

            // Rendered but non-navigating this slice.
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.pepTextTertiary)
        }
    }

    private static func referenceStyle(
        for iconKey: String
    ) -> (icon: String, background: Color, foreground: Color) {
        switch iconKey {
        case "weight": return ("chart.line.downtrend.xyaxis", .pepPrimaryMuted, .pepPrimary)
        case "sleep": return ("moon", .pepInfoMuted, .pepInfo)
        case "calendar": return ("calendar", .pepPrimaryMuted, .pepPrimary)
        case "checkmark": return ("checkmark.circle", .pepSuccessMuted, .pepSuccess)
        case "symptom": return ("exclamationmark.triangle", .pepWarningMuted, .pepWarning)
        case "chart": return ("chart.bar", .pepInfoMuted, .pepInfo)
        default: return ("circle", .pepBorder, .pepTextSecondary)
        }
    }

    private func iconCircle(_ systemName: String, background: Color, foreground: Color) -> some View {
        ZStack {
            Circle()
                .fill(background)
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(foreground)
        }
        .frame(width: 44, height: 44)
    }

    // MARK: - Disclaimer

    private var disclaimerBanner: some View {
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
                Text("Informational only, not medical advice")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)

                Text("These insights are based on your self-reported data and are provided for informational purposes only. They are not a substitute for professional medical advice or diagnosis.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pepInfoMuted)
        .cornerRadius(CornerRadius.md)
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: Spacing.sm) {
            actionButton(icon: "bookmark", title: "Snooze", subtitle: "Remind me later", filled: false) {
                Task { await model.snooze() }
            }
            actionButton(icon: "xmark.circle", title: "Dismiss", subtitle: "Not helpful", filled: false) {
                Task { await model.dismissInsight() }
            }
            actionButton(icon: "checkmark.circle", title: "Accept", subtitle: "Helpful insight", filled: true) {
                Task { await model.accept() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .background(Color.pepBackground)
    }

    private func actionButton(
        icon: String,
        title: String,
        subtitle: String,
        filled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(filled ? Color.white : Color.pepTextPrimary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(filled ? Color.white : Color.pepTextPrimary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(filled ? Color.white.opacity(0.85) : Color.pepTextSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(filled ? Color.pepPrimary : Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay {
                if !filled {
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.pepBorder, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(model.isActing)
    }
}

#Preview {
    let deps = Dependencies.mock()
    let insight = Insight.fixture(
        title: "Weight loss is accelerating",
        description: "Your average weekly weight loss over the past 2 weeks is 0.8 lb, up from 0.4 lb in the prior 2 weeks. This suggests your rate of loss is increasing.",
        explanation: "We analyzed your check-ins and protocol data to find meaningful patterns.",
        supportingData: [
            .init(iconKey: "weight", label: "Weight trend", sublabel: "Compared to prior 2 weeks", value: "0.8 lb / week"),
            .init(iconKey: "sleep", label: "Sleep change", sublabel: "Average nightly sleep", value: "+0.7 hrs"),
            .init(iconKey: "calendar", label: "Dose timing", sublabel: "Consistent with plan", value: "100% on time"),
            .init(iconKey: "checkmark", label: "Check-in consistency", sublabel: "Last 30 days", value: "93%")
        ]
    )
    if let api = deps.api as? MockAPIClient {
        api.setMockResponse(insight, for: .getInsight(id: insight.id))
        api.setMockResponse(insight, for: .markInsightRead(id: insight.id))
    }
    return NavigationStack {
        InsightDetailView(store: deps.insightsStore, api: deps.api, insightID: insight.id)
    }
    .withDependencies(deps)
}
