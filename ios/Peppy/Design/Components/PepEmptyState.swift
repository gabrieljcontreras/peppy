import SwiftUI

struct PepEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.pepTextTertiary)

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.pepTextPrimary)

                Text(message)
                    .font(.body)
                    .foregroundColor(.pepTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                PepButton(title: actionTitle, style: .primary, action: action)
                    .frame(width: 200)
            }
        }
        .padding(Spacing.xl)
    }
}

#Preview {
    VStack {
        PepEmptyState(
            icon: "pills.fill",
            title: "No Protocols Yet",
            message: "Create your first protocol to start tracking your journey.",
            actionTitle: "Create Protocol"
        ) {}
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.pepBackground)
}
