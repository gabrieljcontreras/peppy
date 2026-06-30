import SwiftUI

struct OnboardingScaffold<Content: View>: View {
    static var bottomSafeAreaPadding: CGFloat { 28 }

    let step: Int?
    let title: Text
    let subtitle: String
    let primaryTitle: String
    let canGoBack: Bool
    let showsSkip: Bool
    let isPrimaryLoading: Bool
    let primaryAction: () -> Void
    let backAction: () -> Void
    let skipAction: () -> Void
    let content: Content

    init(
        step: Int?,
        title: Text,
        subtitle: String,
        primaryTitle: String = "Continue",
        canGoBack: Bool = true,
        showsSkip: Bool = true,
        isPrimaryLoading: Bool = false,
        primaryAction: @escaping () -> Void,
        backAction: @escaping () -> Void,
        skipAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.step = step
        self.title = title
        self.subtitle = subtitle
        self.primaryTitle = primaryTitle
        self.canGoBack = canGoBack
        self.showsSkip = showsSkip
        self.isPrimaryLoading = isPrimaryLoading
        self.primaryAction = primaryAction
        self.backAction = backAction
        self.skipAction = skipAction
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if canGoBack {
                    HStack {
                        Button(action: backAction) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.pepTextPrimary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")

                        Spacer()
                    }
                }

                PeppyLogo(size: 28)
            }
            .frame(height: 44)

            if let step {
                PepOnboardingProgress(currentStep: step, totalSteps: 7)
                    .padding(.top, 22)

                Text("Step \(step) of 7")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.pepPrimary)
                    .padding(.top, 10)
            }

            title
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pepTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.top, 28)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Color.pepTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            ScrollView {
                content
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 10) {
                PepButton(
                    title: primaryTitle,
                    isLoading: isPrimaryLoading,
                    action: primaryAction
                )

                if canGoBack {
                    PepButton(title: "Back", style: .secondary, action: backAction)
                }

                if showsSkip {
                    Button("Skip this step", action: skipAction)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.pepTextSecondary)
                        .frame(minHeight: 44)
                        .buttonStyle(.plain)
                }
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, Self.bottomSafeAreaPadding)
        .background(Color.pepBackground.ignoresSafeArea())
    }
}

#Preview("Onboarding Scaffold") {
    OnboardingScaffold(
        step: 4,
        title: Text("What peptides are you taking?"),
        subtitle: "Select anything relevant so Peppy can personalize your baseline.",
        primaryAction: {},
        backAction: {},
        skipAction: {}
    ) {
        VStack(spacing: 12) {
            PepSelectionChip(title: "Retatrutide", isSelected: true) {}
            PepSelectionChip(title: "Semaglutide", isSelected: false) {}
            PepSelectionChip(title: "Tirzepatide", isSelected: true) {}
        }
    }
    .previewLayout(.fixed(width: 393, height: 852))
}

#Preview("Onboarding Scaffold - Accessibility") {
    OnboardingScaffold(
        step: 7,
        title: Text("What are your goals?"),
        subtitle: "Choose what you want Peppy to help you understand over time.",
        primaryAction: {},
        backAction: {},
        skipAction: {}
    ) {
        VStack(spacing: 12) {
            PepSelectionChip(title: "Understand my body better", isSelected: true) {}
            PepSelectionChip(title: "Build consistent habits", isSelected: false) {}
            PepSelectionChip(title: "See what's actually working", isSelected: true) {}
        }
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .previewLayout(.fixed(width: 393, height: 852))
}
