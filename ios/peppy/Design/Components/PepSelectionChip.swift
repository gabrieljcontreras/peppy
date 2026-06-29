import SwiftUI

struct PepSelectionChip: View {
    static let minimumTapTarget: CGFloat = 44

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(isSelected ? Color.pepPrimaryDark : Color.pepTextPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: Self.minimumTapTarget)
            .background(isSelected ? Color.pepPrimaryMuted : Color.pepSurface)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.pepPrimary : Color.pepBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Selection Chips") {
    FlowLayoutPreview {
        PepSelectionChip(title: "Retatrutide", isSelected: true) {}
        PepSelectionChip(title: "Semaglutide", isSelected: false) {}
        PepSelectionChip(title: "BPC-157", isSelected: true) {}
    }
    .padding(24)
    .background(Color.pepBackground)
    .previewLayout(.fixed(width: 393, height: 180))
}

#Preview("Selection Chips - Accessibility") {
    FlowLayoutPreview {
        PepSelectionChip(title: "Longer peptide option", isSelected: true) {}
        PepSelectionChip(title: "Not selected", isSelected: false) {}
    }
    .padding(24)
    .background(Color.pepBackground)
    .environment(\.dynamicTypeSize, .accessibility3)
    .previewLayout(.fixed(width: 393, height: 220))
}

private struct FlowLayoutPreview<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
