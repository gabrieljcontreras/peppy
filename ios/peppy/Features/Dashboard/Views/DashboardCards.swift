import SwiftUI

/// Card presentation derived from the backend `setup_status` contract, mirroring
/// the Protocols tab's three-way treatment so a deactivated protocol never
/// renders as active.
extension DashboardProtocolSummary {
    var cardTitle: String {
        switch status {
        case "pending_setup": return "Starter protocol"
        case "inactive": return "Past protocol"
        case "missing": return "Protocol"
        default: return "Active protocol"
        }
    }

    var badgeText: String {
        switch status {
        case "pending_setup": return "Needs setup"
        case "inactive": return "Inactive"
        case "missing": return "Not started"
        default: return "Active"
        }
    }

    var badgeType: PepBadgeType {
        switch status {
        case "pending_setup": return .warning
        case "inactive": return .neutral
        case "missing": return .neutral
        default: return .success
        }
    }

    var actionTitle: String {
        switch status {
        case "pending_setup": return "Finish setup"
        case "missing": return "Create protocol"
        default: return "View protocol"
        }
    }
}

extension DashboardInsightSummary {
    var confidenceLabel: String? {
        guard let confidence else { return nil }
        switch confidence {
        case ..<0.5: return "Low confidence"
        case 0.5..<0.75: return "Medium confidence"
        default: return "High confidence"
        }
    }
}

struct DashboardProtocolCard: View {
    let summary: DashboardProtocolSummary
    let finishSetup: () -> Void

    var body: some View {
        PepCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: Spacing.sm) {
                    ZStack {
                        Circle().fill(Color.pepPrimaryMuted)
                        Image(systemName: "pills.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.pepPrimary)
                    }
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)

                    Text(summary.cardTitle.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.pepPrimary)
                        .tracking(0.5)

                    Spacer(minLength: Spacing.sm)

                    PepBadge(text: summary.badgeText, type: summary.badgeType)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(summary.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.pepTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !summary.compounds.isEmpty {
                        Text(summary.compounds.joined(separator: ", "))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.pepTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                PepButton(
                    title: summary.actionTitle,
                    style: .primary,
                    action: finishSetup
                )
            }
        }
    }
}

struct DashboardTodayCard: View {
    let today: DashboardTodayCheckin
    let preview: DashboardCheckinPreview?
    let openCheckin: () -> Void

    private var isSaved: Bool { preview != nil || today.logged }

    var body: some View {
        Button(action: openCheckin) {
            PepCard {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle().fill(Color.pepPrimaryMuted)
                        Image(systemName: isSaved ? "checkmark.circle.fill" : "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.pepPrimary)
                    }
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("TODAY'S CHECK-IN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.pepPrimary)
                            .tracking(0.5)
                        Text(preview?.title ?? (isSaved ? "Your check-in" : "How are you today?"))
                            .font(.headline)
                            .foregroundStyle(Color.pepTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(preview?.subtitle ?? (isSaved
                            ? "Today's check-in is saved"
                            : "Log weight, energy, mood, and symptoms."))
                            .font(.subheadline)
                            .foregroundStyle(Color.pepTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let preview {
                            ForEach(preview.highlights, id: \.self) { value in
                                Text(value)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.pepTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Spacer(minLength: Spacing.sm)
                    Text(isSaved ? "View" : "Check in")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.pepPrimary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .overlay(
                            Capsule().stroke(Color.pepPrimary, lineWidth: 1)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        if let preview { return preview.accessibilitySummary }
        if isSaved { return "View full check-in. Today's check-in is saved." }
        return "Add today's check-in. Log weight, energy, mood, and symptoms."
    }
}

struct DashboardNextDoseCard: View {
    let compound: Compound
    let dueDate: Date
    let logDose: () -> Void

    var body: some View {
        Button(action: logDose) {
            PepCard {
                HStack(alignment: .top, spacing: Spacing.md) {
                    ZStack {
                        Circle().fill(Color.pepPrimaryMuted)
                        Image(systemName: "pills.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.pepPrimary)
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("NEXT DOSE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.pepPrimary)
                            .tracking(0.5)
                        Text(compound.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.pepTextPrimary)
                        Text("\(doseText) • Due \(Self.dueDateFormatter.string(from: dueDate))")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pepTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: Spacing.sm)

                    Text("Log dose")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.pepPrimary)
                        .clipShape(Capsule())
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Next dose: \(compound.name), \(doseText), due \(Self.dueDateFormatter.string(from: dueDate)). Log dose."
        )
    }

    private var doseText: String {
        let amount = Self.doseFormatter.string(from: NSNumber(value: compound.doseMg)) ?? "\(compound.doseMg)"
        return "\(amount) \(compound.doseUnit)"
    }

    private static let dueDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private static let doseFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

struct DashboardInsightCard: View {
    let insight: DashboardInsightSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PepCard {
                HStack(alignment: .top, spacing: Spacing.md) {
                    ZStack {
                        Circle().fill(Color.pepPrimaryMuted)
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.pepPrimary)
                    }
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("LATEST INSIGHT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.pepPrimary)
                            .tracking(0.5)

                        Text(insight.title ?? insight.emptyMessage ?? "No new insights right now.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.pepTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let confidenceLabel = insight.confidenceLabel {
                            Text(confidenceLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.pepSuccess)
                        }
                    }

                    Spacer(minLength: Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.pepTextTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.md) {
            DashboardProtocolCard(summary: DashboardSummary.mockPendingStarter.protocol) {}
            DashboardTodayCard(
                today: DashboardSummary.mockPendingStarter.todayCheckin,
                preview: nil
            ) {}
            DashboardNextDoseCard(
                compound: Compound(
                    id: UUID(),
                    name: "Retatrutide",
                    doseMg: 2.5,
                    doseUnit: "mg",
                    frequency: "weekly",
                    administrationRoute: "subcutaneous",
                    notes: nil
                ),
                dueDate: Date()
            ) {}
            DashboardInsightCard(
                insight: DashboardInsightSummary(
                    id: nil, title: "Your weight trend is accelerating", severity: "info",
                    emptyMessage: nil, confidence: 0.82
                )
            ) {}
        }
        .padding()
    }
    .background(Color.pepBackground)
}
