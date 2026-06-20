import SwiftUI

struct PeptidesStepView: View {
    let selected: [String]
    let toggle: (String) -> Void
    @State private var query = ""

    static let suggestionLimit = 6

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var availableSuggestions: [String] {
        Self.suggestions(for: query)
            .filter { suggestion in
                !selected.contains { $0.caseInsensitiveCompare(suggestion) == .orderedSame }
            }
    }

    private var canAddCustom: Bool {
        Self.canAddCustomPeptide(trimmedQuery, selected: selected)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !selected.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(selected, id: \.self) { name in
                        PepSelectionChip(title: name, isSelected: true) {
                            toggle(name)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PepTextField(
                placeholder: "Search peptides",
                text: $query,
                autocapitalization: .words
            )

            if !availableSuggestions.isEmpty || canAddCustom {
                VStack(spacing: 0) {
                    ForEach(availableSuggestions, id: \.self) { name in
                        suggestionButton(title: name, systemImage: "plus.circle.fill") {
                            toggle(name)
                            query = ""
                        }
                    }

                    if canAddCustom {
                        suggestionButton(
                            title: "Add \"\(trimmedQuery)\"",
                            systemImage: "plus.circle"
                        ) {
                            toggle(trimmedQuery)
                            query = ""
                        }
                    }
                }
                .background(Color.pepSurface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(Color.pepBorder, lineWidth: 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func suggestions(for query: String, names: [String] = PeptideCatalog.names) -> [String] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        return names
            .filter { $0.localizedCaseInsensitiveContains(trimmedQuery) }
            .prefix(suggestionLimit)
            .map { $0 }
    }

    static func canAddCustomPeptide(
        _ query: String,
        selected: [String],
        names: [String] = PeptideCatalog.names
    ) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return false }

        let matchesCatalog = names.contains {
            $0.caseInsensitiveCompare(trimmedQuery) == .orderedSame
        }
        let matchesSelected = selected.contains {
            $0.caseInsensitiveCompare(trimmedQuery) == .orderedSame
        }

        return !matchesCatalog && !matchesSelected
    }

    private func suggestionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.pepTextPrimary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 12)

                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.pepPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        var points: [CGPoint] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }

        return (
            CGSize(width: min(usedWidth, maxWidth), height: y + rowHeight),
            points
        )
    }
}

#Preview("Peptides Step") {
    PeptidesStepView(
        selected: ["Retatrutide", "BPC-157"],
        toggle: { _ in }
    )
    .padding(24)
    .background(Color.pepBackground)
    .previewLayout(.fixed(width: 393, height: 320))
}
