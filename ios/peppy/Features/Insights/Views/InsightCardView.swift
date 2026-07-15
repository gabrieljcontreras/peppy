import SwiftUI

struct InsightCardView: View {
    let insight: Insight

    var body: some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(insight.typeBadgeStyle.backgroundColor)
                        Image(systemName: insight.typeIcon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(insight.typeBadgeStyle.textColor)
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            PepBadge(text: insight.typeDisplayName, type: insight.typeBadgeStyle)
                            Spacer()
                            if insight.isUnread {
                                PepBadge(text: "New", type: .error)
                            }
                        }

                        Text(insight.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.pepTextPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(insight.description)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pepTextSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                }

                Divider()

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pepTextSecondary)
                    Text(insight.formattedTimestamp)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pepTextSecondary)

                    Spacer()

                    Text("Confidence: \(insight.confidenceLabel)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(insight.confidenceColor)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.pepTextTertiary)
                }
            }
        }
    }

}

#Preview {
    VStack(spacing: Spacing.md) {
        InsightCardView(insight: .fixture(title: "Weight loss is accelerating"))
        InsightCardView(insight: .fixture(
            type: "anomaly",
            severity: "warning",
            title: "Nausea is appearing after dose day",
            description: "You've logged nausea within 24 hours after your dose on 3 of the last 4 occurrences.",
            confidence: 0.6,
            readAt: Date()
        ))
    }
    .padding(20)
    .background(Color.pepBackground)
}
