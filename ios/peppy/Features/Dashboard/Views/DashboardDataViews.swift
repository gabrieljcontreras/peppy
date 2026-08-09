import SwiftUI
import Charts

struct DashboardWeightTrendCard: View {
    let snapshot: DashboardResponseSnapshot
    let preferredUnit: WeightUnit

    /// Trend dates arrive as `yyyy-MM-dd` and decode to UTC midnight via
    /// `APIDateOnly`, so the axis has to label them in UTC too. Formatting them
    /// in the device calendar shifts every weekday back a day west of GMT.
    private static let weekdayLabel = Date.FormatStyle(
        date: .omitted,
        time: .omitted,
        timeZone: TimeZone(secondsFromGMT: 0) ?? .current
    ).weekday(.abbreviated)

    /// The backend sends up to 10 check-ins spanning 30 days. Plotting all of
    /// them crowds the axis past the point of legibility, so the card shows a
    /// week — which is also the window `deltaText` describes.
    private static let maximumPoints = 7

    /// Oldest to newest, because the axis labels read left to right.
    private var points: [DashboardWeightPoint] {
        Array(
            snapshot.weightTrend
                .sorted { $0.date < $1.date }
                .suffix(Self.maximumPoints)
        )
    }

    var body: some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("WEIGHT TREND")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.pepPrimary)
                    .tracking(0.5)

                if let latest = points.last {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preferredUnit.format(kilograms: latest.weightKg))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.pepTextPrimary)
                        if let deltaText {
                            Text(deltaText)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(delta ?? 0 <= 0 ? Color.pepSuccess : Color.pepWarning)
                        }
                    }

                    trendChart
                        .frame(maxWidth: .infinity)
                        .frame(height: 96)
                        .padding(.top, Spacing.xs)
                } else {
                    Text("Log a few check-ins to see your trend.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pepTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var delta: Double? {
        // Points sit at UTC midnight, so the cutoff has to as well — measuring
        // back from the local clock drops the oldest day west of GMT.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let today = calendar.startOfDay(for: Date())
        guard let cutoff = calendar.date(byAdding: .day, value: -7, to: today) else { return nil }
        let recent = snapshot.weightTrend.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        guard let first = recent.first, let last = recent.last, first.date != last.date else { return nil }
        return last.weightKg - first.weightKg
    }

    private var deltaText: String? {
        guard let delta else { return nil }
        let displayDelta = preferredUnit.displayValue(kilograms: abs(delta))
        let arrow = delta <= 0 ? "\u{2193}" : "\u{2191}"
        return "\(arrow) \(String(format: "%.1f", displayDelta)) \(preferredUnit.symbol) this week"
    }

    private var trendChart: some View {
        let plotted = points
        let weights = plotted.map(\.weightKg)
        let lower = (weights.min() ?? 0) - 0.5
        return Chart(plotted, id: \.date) { point in
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
            // A lone check-in draws no line segment; the symbol keeps the
            // chart from coming up blank on a brand new account.
            .symbol {
                Circle()
                    .fill(Color.pepPrimary)
                    .frame(width: 5, height: 5)
            }
        }
        // Labelling the check-in dates themselves, rather than striding by day,
        // keeps every label under a data point and caps the count at seven.
        .chartXAxis {
            AxisMarks(values: plotted.map(\.date)) { _ in
                AxisValueLabel(format: Self.weekdayLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.pepTextTertiary)
            }
        }
        .chartYAxis(.hidden)
    }
}

struct DashboardWearableTilesRow: View {
    let tiles: DashboardWearableTiles

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let sleepHours = tiles.sleepHours {
                tile(
                    icon: "moon.fill",
                    tint: Color.pepInfo,
                    label: "SLEEP",
                    value: formattedHours(sleepHours),
                    source: "From Oura"
                )
            }
            if let hrvMs = tiles.hrvMs {
                tile(
                    icon: "heart.fill",
                    tint: Color.pepSuccess,
                    label: "HRV",
                    value: "\(Int(hrvMs.rounded())) ms",
                    source: "From Oura"
                )
            }
            if let readinessScore = tiles.readinessScore {
                tile(
                    icon: "sun.max.fill",
                    tint: Color.pepWarning,
                    label: "READINESS",
                    value: "\(Int(readinessScore.rounded()))%",
                    source: "From Whoop"
                )
            }
        }
    }

    private func formattedHours(_ hours: Double) -> String {
        let wholeHours = Int(hours)
        let minutes = Int((hours - Double(wholeHours)) * 60)
        return "\(wholeHours)h \(minutes)m"
    }

    private func tile(icon: String, tint: Color, label: String, value: String, source: String) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.pepTextSecondary)
                        .tracking(0.5)
                }
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.pepTextPrimary)
                Text(source)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.pepTextTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DashboardActivityFeed: View {
    let items: [DashboardActivityItem]
    let openProtocol: (UUID) -> Void
    let openCheckin: (UUID) -> Void

    var body: some View {
        PepCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(for: item)
                    if index < items.count - 1 {
                        Divider().padding(.vertical, Spacing.sm)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for item: DashboardActivityItem) -> some View {
        let content = HStack(spacing: Spacing.sm) {
            ZStack {
                Circle().fill(iconTint(for: item.type).opacity(0.15))
                Image(systemName: icon(for: item.type))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconTint(for: item.type))
            }
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)
                Text(item.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.pepTextSecondary)
            }

            Spacer(minLength: Spacing.sm)

            Text(Self.timeFormatter.string(from: item.timestamp))
                .font(.system(size: 11))
                .foregroundStyle(Color.pepTextTertiary)

            if isNavigable(item) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.pepTextTertiary)
                    .accessibilityHidden(true)
            }
        }

        if item.type == "dose_logged", let protocolID = item.protocolID {
            Button { openProtocol(protocolID) } label: { content }
                .buttonStyle(.plain)
        } else if item.type == "checkin_completed", let checkinID = item.checkinID {
            Button { openCheckin(checkinID) } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func isNavigable(_ item: DashboardActivityItem) -> Bool {
        (item.type == "dose_logged" && item.protocolID != nil)
            || (item.type == "checkin_completed" && item.checkinID != nil)
    }

    private func icon(for type: String) -> String {
        switch type {
        case "dose_logged": return "pills.fill"
        case "checkin_completed": return "checkmark.circle.fill"
        case "wearable_synced": return "applewatch"
        case "lab_added": return "testtube.2"
        default: return "circle.fill"
        }
    }

    private func iconTint(for type: String) -> Color {
        switch type {
        case "dose_logged": return .pepPrimary
        case "checkin_completed": return .pepSuccess
        case "wearable_synced": return .pepInfo
        case "lab_added": return .pepWarning
        default: return .pepTextSecondary
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.md) {
            DashboardWeightTrendCard(
                snapshot: DashboardSummary.mockPendingStarter.responseSnapshot,
                preferredUnit: .pounds
            )
            DashboardWearableTilesRow(
                tiles: DashboardWearableTiles(sleepHours: 7.3, hrvMs: 54, readinessScore: 72)
            )
            DashboardActivityFeed(
                items: [
                    DashboardActivityItem(
                        type: "dose_logged", title: "Dose logged", subtitle: "Retatrutide \u{2022} 4 mg",
                        timestamp: Date(), protocolID: UUID(), checkinID: nil
                    ),
                    DashboardActivityItem(
                        type: "checkin_completed", title: "Check-in completed", subtitle: "Energy, mood, weight",
                        timestamp: Date(), protocolID: nil, checkinID: UUID()
                    ),
                ],
                openProtocol: { _ in },
                openCheckin: { _ in }
            )
        }
        .padding()
    }
    .background(Color.pepBackground)
}
