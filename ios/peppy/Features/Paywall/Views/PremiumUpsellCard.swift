import SwiftUI

/// Sits above the profile card in More. Upsell for free accounts, status and
/// a management link for paid ones.
struct PremiumUpsellCard: View {
    let entitlement: PremiumEntitlement
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: entitlement.isPremium ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 40)
                    .background(Color.pepPrimary)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.pepTextPrimary)

                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.pepTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pepTextTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: SettingsFigmaLayout.minimumTapTarget)
            .background(Color.pepPrimaryMuted)
            .clipShape(
                RoundedRectangle(cornerRadius: SettingsFigmaLayout.cardCornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SettingsFigmaLayout.cardCornerRadius)
                    .stroke(Color.pepPrimary.opacity(0.35), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }

    private var title: String {
        entitlement.isPremium ? "Peppy Premium" : "Unlock Peppy Premium"
    }

    private var subtitle: String {
        guard entitlement.isPremium else {
            return "Insights, weekly summaries, and data export"
        }
        guard let plan = entitlement.plan else { return "Active" }
        // Only a genuinely non-recurring plan is Lifetime. A recurring plan
        // that arrived without an expiry is still that plan — saying
        // "Lifetime" there would promise a subscriber something they did
        // not buy.
        guard plan.isRecurring else { return "Lifetime — thank you" }
        guard let expires = entitlement.expires else { return "\(plan.title) — active" }
        return "\(plan.title) — renews \(expires.formatted(date: .abbreviated, time: .omitted))"
    }
}

#Preview {
    VStack(spacing: 12) {
        PremiumUpsellCard(entitlement: .free, action: {})
        PremiumUpsellCard(
            entitlement: .premium(plan: .yearly, expires: Date().addingTimeInterval(86_400 * 300)),
            action: {}
        )
        PremiumUpsellCard(entitlement: .premium(plan: .lifetime, expires: nil), action: {})
    }
    .padding(22)
    .background(Color.pepBackground)
}
