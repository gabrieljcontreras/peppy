import SwiftUI

/// One selectable plan on the paywall. The three cards form a radio group;
/// the whole card is the tap target.
struct PaywallPlanCard: View {
    let product: PremiumProduct
    let isSelected: Bool
    let action: () -> Void

    private var plan: PremiumPlan { product.plan }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Spacing.md) {
                selectionIndicator

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pepTextPrimary)

                    ForEach(plan.subtitleLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.pepTextSecondary)
                    }
                }

                Spacer(minLength: Spacing.sm)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(priceText)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pepTextPrimary)

                    if let original = product.originalDisplayPrice {
                        Text("\(original)\(plan == .yearly ? "/year" : "")")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.pepTextTertiary)
                            .strikethrough(true, color: .pepTextTertiary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.pepPrimaryMuted : Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(
                        isSelected ? Color.pepPrimary : Color.pepBorderLight,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .pepCardShadow()
            .overlay(alignment: .topTrailing) { badge }
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var priceText: String {
        switch plan {
        case .yearly: return "\(product.displayPrice)/year"
        case .monthly: return "\(product.displayPrice)/month"
        case .lifetime: return product.displayPrice
        }
    }

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.pepPrimary : Color.clear)
                .frame(width: 28, height: 28)

            Circle()
                .stroke(isSelected ? Color.clear : Color.pepBorder, lineWidth: 1.5)
                .frame(width: 28, height: 28)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var badge: some View {
        if let text = plan.badgeText {
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.pepPrimary)
                .clipShape(Capsule())
                // Rides the card's top edge, as in the reference.
                .offset(x: -8, y: -14)
                .accessibilityHidden(true)
        }
    }

    private var accessibilityLabel: String {
        var parts = [plan.title, priceText]
        parts.append(contentsOf: plan.subtitleLines)
        if let text = plan.badgeText { parts.append(text) }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    VStack(spacing: 14) {
        PaywallPlanCard(
            product: PremiumProduct(
                plan: .yearly, displayPrice: "$24.99", originalDisplayPrice: "$49.99"
            ),
            isSelected: true,
            action: {}
        )
        PaywallPlanCard(
            product: PremiumProduct(
                plan: .monthly, displayPrice: "$7.99", originalDisplayPrice: nil
            ),
            isSelected: false,
            action: {}
        )
        PaywallPlanCard(
            product: PremiumProduct(
                plan: .lifetime, displayPrice: "$139.99", originalDisplayPrice: nil
            ),
            isSelected: false,
            action: {}
        )
    }
    .padding(20)
    .background(Color.pepBackground)
}
