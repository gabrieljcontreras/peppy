import SwiftUI

struct PermissionInfoCard: Equatable, Identifiable {
    let icon: String
    let title: String
    let body: String

    var id: String { title }
}

struct HealthPermissionView: View {
    let isLoading: Bool
    let requestAction: () -> Void
    let skipAction: () -> Void
    let backAction: () -> Void

    static let readCategories = [
        "Sleep analysis",
        "Heart rate variability",
        "Resting heart rate",
        "Step count",
        "Active energy burned",
        "Body mass",
        "Workouts"
    ]

    init(
        isLoading: Bool = false,
        requestAction: @escaping () -> Void,
        skipAction: @escaping () -> Void,
        backAction: @escaping () -> Void = {}
    ) {
        self.isLoading = isLoading
        self.requestAction = requestAction
        self.skipAction = skipAction
        self.backAction = backAction
    }

    var body: some View {
        OnboardingPermissionScaffold(
            icon: "heart.text.square.fill",
            title: "Connect Apple Health",
            subtitle: "Peppy can read key signals to help connect your protocol, habits, and trends over time.",
            primaryTitle: "Continue to Apple Health",
            primaryStyle: .destructive,
            isLoading: isLoading,
            primaryAction: requestAction,
            skipTitle: "Not now",
            skipAction: skipAction,
            backAction: backAction
        ) {
            VStack(spacing: 12) {
                PermissionCard(
                    card: PermissionInfoCard(
                        icon: "lock.shield.fill",
                        title: "Read-only access",
                        body: "Peppy does not write health data in this phase. You can change access anytime in the Health app."
                    )
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Peppy would like to read")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.pepTextPrimary)

                    ForEach(Self.readCategories, id: \.self) { category in
                        Label(category, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.pepTextSecondary)
                            .symbolRenderingMode(.monochrome)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.pepSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.pepBorder, lineWidth: 1)
                }
            }
        }
    }
}

struct OnboardingPermissionScaffold<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let primaryTitle: String
    let primaryStyle: PepButtonStyle
    let isLoading: Bool
    let primaryAction: () -> Void
    let skipTitle: String
    let skipAction: () -> Void
    let backAction: () -> Void
    let content: Content

    init(
        icon: String,
        title: String,
        subtitle: String,
        primaryTitle: String,
        primaryStyle: PepButtonStyle = .primary,
        isLoading: Bool = false,
        primaryAction: @escaping () -> Void,
        skipTitle: String,
        skipAction: @escaping () -> Void,
        backAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.primaryTitle = primaryTitle
        self.primaryStyle = primaryStyle
        self.isLoading = isLoading
        self.primaryAction = primaryAction
        self.skipTitle = skipTitle
        self.skipAction = skipAction
        self.backAction = backAction
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
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

                PeppyLogo(size: 28)
            }
            .frame(height: 44)

            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.pepPrimary)
                        .frame(width: 68, height: 68)
                        .background(Color.pepPrimaryMuted)
                        .clipShape(Circle())
                        .padding(.top, 20)

                    Text(title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pepTextPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pepTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    content
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 10) {
                PepButton(
                    title: primaryTitle,
                    style: primaryStyle,
                    isLoading: isLoading,
                    action: primaryAction
                )

                Button(skipTitle, action: skipAction)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.pepTextSecondary)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.pepBackground.ignoresSafeArea())
    }
}

struct PermissionCard: View {
    let card: PermissionInfoCard

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: card.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.pepPrimary)
                .frame(width: 42, height: 42)
                .background(Color.pepPrimaryMuted)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)

                Text(card.body)
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

#Preview("Health Permission") {
    HealthPermissionView(requestAction: {}, skipAction: {})
}
