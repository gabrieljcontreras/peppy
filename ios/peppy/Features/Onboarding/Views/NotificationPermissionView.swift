import SwiftUI

struct NotificationPermissionView: View {
    let isLoading: Bool
    let requestAction: () -> Void
    let skipAction: () -> Void
    let backAction: () -> Void

    static let cards = [
        PermissionInfoCard(
            icon: "pills.fill",
            title: "Dose reminders",
            body: "Gentle nudges help you stay aligned with your protocol."
        ),
        PermissionInfoCard(
            icon: "checklist",
            title: "Daily check-ins",
            body: "Short prompts make it easier to capture how you feel over time."
        ),
        PermissionInfoCard(
            icon: "sparkles",
            title: "Important insights",
            body: "Peppy can let you know when a meaningful pattern is ready to review."
        )
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
            icon: "bell.badge.fill",
            title: "Stay consistent without the noise",
            subtitle: "Turn on notifications for helpful reminders and important insights. You can adjust them later.",
            primaryTitle: "Turn on notifications",
            isLoading: isLoading,
            primaryAction: requestAction,
            skipTitle: "Not now",
            skipAction: skipAction,
            backAction: backAction
        ) {
            VStack(spacing: 12) {
                ForEach(Self.cards) { card in
                    PermissionCard(card: card)
                }
            }
        }
    }
}

#Preview("Notification Permission") {
    NotificationPermissionView(requestAction: {}, skipAction: {})
}
