import SwiftUI

struct PepCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.md)
            .background(Color.pepSurface)
            .cornerRadius(CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color.pepBorder, lineWidth: 1)
            )
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Card Title")
                    .pepHeadline()
                Text("Card description goes here with some example content.")
                    .pepSubheadline()
            }
        }

        PepCard {
            HStack {
                Image(systemName: "pills.fill")
                    .foregroundColor(.pepPrimary)
                Text("Protocol Active")
                    .pepBody()
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.pepTextTertiary)
            }
        }
    }
    .padding()
    .background(Color.pepBackground)
}
