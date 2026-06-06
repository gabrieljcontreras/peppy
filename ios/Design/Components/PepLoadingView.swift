import SwiftUI

struct PepLoadingView: View {
    var message: String? = nil

    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(.pepPrimary)
                .scaleEffect(1.5)

            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.pepTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pepBackground)
    }
}

#Preview {
    PepLoadingView(message: "Loading protocols...")
}
