import SwiftUI

struct OnboardingIntroView: View {
    let continueAction: () -> Void
    let signInAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 28)

                PeppyLogo(size: 54)

                (Text("Let's make\n")
                    + Text("peppy").foregroundColor(.pepPrimary)
                    + Text(" yours."))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                Text("A few details help peppy organize your protocol and make your trends more meaningful.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pepTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                VStack(spacing: 12) {
                    benefit(
                        icon: "chart.xyaxis.line",
                        title: "Understand your baseline",
                        body: "Capture key info so peppy can personalize your insights."
                    )
                    benefit(
                        icon: "checklist",
                        title: "Track your protocol",
                        body: "Log doses, check-ins, and notes in one simple place."
                    )
                    benefit(
                        icon: "point.3.connected.trianglepath.dotted",
                        title: "Connect the dots over time",
                        body: "See how your data, habits, and results come together."
                    )
                }
                .padding(.top, 30)

                Spacer(minLength: 20)

                Label("Your data is private and secure.", systemImage: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.pepTextSecondary)
                    .symbolRenderingMode(.monochrome)

                PepButton(title: "Continue", action: continueAction)
                    .padding(.top, 18)

                Button("Already have an account? Sign in", action: signInAction)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.pepPrimary)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.pepBackground.ignoresSafeArea())
    }

    private func benefit(icon: String, title: String, body: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.pepPrimary)
                .frame(width: 42, height: 42)
                .background(Color.pepPrimaryMuted)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)

                Text(body)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pepBorder, lineWidth: 1)
        }
    }
}

#Preview("Onboarding Intro") {
    OnboardingIntroView(continueAction: {}, signInAction: {})
        .previewLayout(.fixed(width: 393, height: 852))
}

#Preview("Onboarding Intro - Accessibility") {
    OnboardingIntroView(continueAction: {}, signInAction: {})
        .environment(\.dynamicTypeSize, .accessibility3)
        .previewLayout(.fixed(width: 393, height: 852))
}
