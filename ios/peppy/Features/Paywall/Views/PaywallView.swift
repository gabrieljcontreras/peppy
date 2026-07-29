import SwiftUI

struct PaywallView: View {
    static let featureRun =
        "Insights, Weekly Summaries, Trend Charts, Confidence Scores, "
        + "Symptom Patterns, Data Export."

    @Environment(\.dependencies) private var deps
    @State private var model: PaywallViewModel?

    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.pepBackground.ignoresSafeArea()

            if let model {
                content(model)
            } else {
                ProgressView().tint(.pepPrimary)
            }
        }
        .task {
            if model == nil {
                let created = PaywallViewModel(
                    service: deps.subscriptionService,
                    entitlements: deps.entitlements
                )
                model = created
                await created.load()
            }
        }
    }

    @ViewBuilder
    private func content(_ model: PaywallViewModel) -> some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    headline
                    featureText

                    switch model.state {
                    case .loading:
                        skeletonCards
                    case .loadFailed(let message):
                        loadFailure(message, model: model)
                    case .ready, .purchasing:
                        planCards(model)
                        restoreButton(model)
                    }

                    if let message = model.errorMessage {
                        Text(message)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.pepError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.md)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.lg)
            }

            footer(model)
        }
        .onChange(of: model.didPurchase) {
            if model.didPurchase { onDismiss() }
        }
    }

    private var topBar: some View {
        ZStack {
            PeppyLogo(size: 30, showsWordmark: true)

            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Color.pepTextPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close")

                Spacer()
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.sm)
    }

    /// "Peppy" in the app's rounded face, "Premium" in the marketing site's
    /// Fraunces italic accent — the same two-face treatment the web headlines
    /// use.
    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Peppy")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pepTextPrimary)

            Text("Premium")
                .font(.peppyPremiumItalic(size: 42))
                .foregroundStyle(Color.pepPrimary)
        }
        .minimumScaleFactor(0.7)
        .lineLimit(1)
        .padding(.top, Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Peppy Premium")
        .accessibilityAddTraits(.isHeader)
    }

    private var featureText: some View {
        Text(Self.featureRun)
            .font(.system(size: 17, design: .rounded))
            .foregroundStyle(Color.pepTextSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            .padding(.horizontal, Spacing.sm)
    }

    private var skeletonCards: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.pepSurfaceElevated)
                    .frame(height: 96)
            }
        }
        .accessibilityLabel("Loading plans")
    }

    private func loadFailure(_ message: String, model: PaywallViewModel) -> some View {
        VStack(spacing: Spacing.md) {
            Text(message)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)
                .multilineTextAlignment(.center)

            PepButton(title: "Retry", style: .secondary) {
                Task { await model.load() }
            }
            .frame(maxWidth: 220)
        }
        .padding(.vertical, Spacing.lg)
    }

    private func planCards(_ model: PaywallViewModel) -> some View {
        VStack(spacing: 14) {
            ForEach(model.products, id: \.plan) { product in
                PaywallPlanCard(
                    product: product,
                    isSelected: product.plan == model.selectedPlan
                ) {
                    model.select(product.plan)
                }
            }
        }
        .padding(.top, Spacing.xs)
    }

    private func restoreButton(_ model: PaywallViewModel) -> some View {
        Button {
            Task { await model.restore() }
        } label: {
            Text("Restore Purchase")
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.pepTextTertiary)
                        .frame(height: 1)
                        .offset(y: 4)
                }
        }
        .buttonStyle(.plain)
        .disabled(model.isPurchasing)
        .padding(.top, Spacing.xs)
    }

    private func footer(_ model: PaywallViewModel) -> some View {
        VStack(spacing: 10) {
            if let product = model.selectedProduct {
                priceRecap(product)
            }

            PaywallPrimaryButton(
                title: "Continue",
                isLoading: model.isPurchasing,
                isDisabled: model.selectedProduct == nil
            ) {
                Task { await model.purchase() }
            }

            if model.showsCancelAnytime {
                Text("Cancel Anytime")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.pepPrimary)
            }

            Text(Self.legalText(for: model.selectedPlan))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.pepTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.sm)
        }
        .padding(.horizontal, 22)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(Color.pepBackground)
    }

    private func priceRecap(_ product: PremiumProduct) -> some View {
        HStack(spacing: Spacing.sm) {
            if let original = product.originalDisplayPrice {
                Text(original)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(Color.pepTextTertiary)
                    .strikethrough(true, color: .pepTextTertiary)
            }

            Text(recapPrice(product))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.pepTextPrimary)

            if product.originalDisplayPrice != nil {
                Text("50% OFF")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.pepPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.pepPrimaryMuted)
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func recapPrice(_ product: PremiumProduct) -> String {
        switch product.plan {
        case .yearly: return "\(product.displayPrice)/year"
        case .monthly: return "\(product.displayPrice)/month"
        case .lifetime: return product.displayPrice
        }
    }

    /// App Store review requires the auto-renewal disclosure for
    /// subscriptions. Absent from the visual reference, non-optional to ship.
    static func legalText(for plan: PremiumPlan) -> String {
        if plan.isRecurring {
            return "Renews automatically until cancelled. Manage or cancel in "
                + "Settings at least 24 hours before the period ends. "
                + "Terms and Privacy Policy apply."
        }
        return "One-time purchase. Terms and Privacy Policy apply."
    }
}

/// The paywall's CTA is coral, while the shared `PepButton` primary is ink.
/// Local to the paywall so the rest of the app's primary buttons are untouched.
private struct PaywallPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView().tint(.white)
                }
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .frame(minHeight: 56)
            .foregroundStyle(Color.white)
            .background(isDisabled ? Color.pepPrimary.opacity(0.5) : Color.pepPrimary)
            .clipShape(Capsule())
        }
        .disabled(isLoading || isDisabled)
    }
}

#Preview {
    PaywallView(onDismiss: {})
        .withDependencies(.mock())
}
