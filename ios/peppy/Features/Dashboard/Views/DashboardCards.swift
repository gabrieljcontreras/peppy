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
    let logCheckin: () -> Void

    var body: some View {
        PepCard {
            HStack(spacing: 14) {
                Image(systemName: today.logged ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.pepPrimary)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(today.logged ? "Today's check-in is saved" : "How are you today?")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.pepTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(today.logged ? "You can update it anytime." : "Log weight, energy, mood, and symptoms.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pepTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.sm)

                Button(action: logCheckin) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.pepTextTertiary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(today.logged ? "Update check-in" : "Log check-in")
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.md) {
            DashboardProtocolCard(summary: DashboardSummary.mockPendingStarter.protocol) {}
            DashboardTodayCard(today: DashboardSummary.mockPendingStarter.todayCheckin) {}
        }
        .padding()
    }
    .background(Color.pepBackground)
}
