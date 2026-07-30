import SwiftUI

enum PremiumGate {
    /// Whether to show locked UI. `.unknown` returns false so nothing flashes
    /// "locked" while the entitlement is still resolving at launch.
    static func showsLock(for entitlement: PremiumEntitlement) -> Bool {
        entitlement.isResolved && !entitlement.isPremium
    }
}

/// The locked-feature treatment: blurred placeholder cards behind a lock and
/// an unlock call to action.
///
/// The blurred shapes are synthetic — never real insight content — so nothing
/// a free account has not paid for is rendered, even out of focus.
struct PremiumLockedOverlay: View {
    let title: String
    let message: String
    var actionTitle: String = "Unlock Insights"
    let action: () -> Void

    var body: some View {
        ZStack {
            teaser
                .blur(radius: 8)
                .opacity(0.55)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.md) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.pepPrimary)
                    .frame(width: 56, height: 56)
                    .background(Color.pepPrimaryMuted)
                    .clipShape(Circle())

                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Color.pepTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.md)

                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, 14)
                        .background(Color.pepPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xs)
            }
            .padding(.vertical, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
    }

    /// Placeholder shapes only.
    private var teaser: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { index in
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.pepBorder)
                        .frame(width: index == 1 ? 180 : 140, height: 14)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.pepBorderLight)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.pepBorderLight)
                        .frame(width: 220, height: 10)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.pepSurface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
        }
    }
}

#Preview {
    PremiumLockedOverlay(
        title: "Insights are a Premium feature",
        message: "See what your check-ins and doses are telling you.",
        action: {}
    )
    .padding(20)
    .background(Color.pepBackground)
}
