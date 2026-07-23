import SwiftUI

struct AppLockCoverView: View {
    let coordinator: AppLockCoordinator

    var body: some View {
        ZStack {
            Color.pepBackground
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Spacer()

                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.pepSurface)
                            .frame(width: 96, height: 96)
                            .overlay(
                                Circle()
                                    .stroke(Color.pepBorder, lineWidth: 1)
                            )

                        PeppyLogo(size: 52)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: Spacing.sm) {
                        Text("Peppy is locked")
                            .font(
                                .system(
                                    .title2,
                                    design: .rounded,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(Color.pepTextPrimary)

                        Text(message)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(Color.pepTextSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if coordinator.requiresUnlock {
                    VStack(spacing: Spacing.sm) {
                        PepButton(
                            title: "Try Face ID Again",
                            style: .primary
                        ) {
                            Task { await coordinator.retryUnlock() }
                        }

                        Button("Use Password Instead") {
                            coordinator.usePasswordInstead()
                        }
                        .font(
                            .system(
                                .body,
                                design: .rounded,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(Color.pepTextSecondary)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: SettingsFigmaLayout.minimumTapTarget
                        )
                        .buttonStyle(.plain)
                        .accessibilityHint(
                            "Signs out and returns to the Peppy sign-in screen"
                        )
                    }
                }

                Spacer()
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, SettingsFigmaLayout.horizontalPadding)
            .padding(.vertical, Spacing.xl)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var message: String {
        if let reason = coordinator.unavailabilityReason {
            return reason.message
        }
        return "Use Face ID to access your private health information."
    }
}

#Preview {
    AppLockCoverView(
        coordinator: AppLockCoordinator(
            authenticator: PreviewAppLockAuthenticator(),
            preferences: UserDefaultsAppLockPreferences(),
            logout: {}
        )
    )
}

@MainActor
private final class PreviewAppLockAuthenticator: AppLockAuthenticating {
    func availability() -> AppLockAvailability { .available }
    func authenticate(reason: String) async -> Bool { false }
}
