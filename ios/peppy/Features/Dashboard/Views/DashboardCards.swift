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

struct DashboardProtocolCard: View {
    let summary: DashboardProtocolSummary
    let finishSetup: () -> Void

    var body: some View {
        PepCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: Spacing.sm) {
                    Label(summary.cardTitle, systemImage: "pills.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.pepPrimary)

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
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.pepPrimary)
                        .frame(width: 34, height: 34)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(preview?.title ?? (isSaved ? "Your check-in" : "How are you today?"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.pepTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(preview?.subtitle ?? (isSaved
                            ? "Today's check-in is saved"
                            : "Log weight, energy, mood, and symptoms."))
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pepTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let preview {
                            ForEach(preview.highlights, id: \.self) { value in
                                Text(value)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.pepTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Spacer(minLength: Spacing.sm)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.pepTextTertiary)
                        .frame(width: 24, height: 44)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isSaved ? "View full check-in" : "Add today's check-in")
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
        }
        .padding()
    }
    .background(Color.pepBackground)
}
