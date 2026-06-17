import SwiftUI

struct MedicationsStepView: View {
    @Binding var text: String

    static let maxLength = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pepTextPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 136)
                    .background(Color.pepSurface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(Color.pepBorder, lineWidth: 1)
                    }
                    .onChange(of: text) { _, newValue in
                        let limitedValue = Self.limitedText(newValue)
                        if limitedValue != newValue {
                            text = limitedValue
                        }
                    }

                if text.isEmpty {
                    Text("e.g. Metformin, Levothyroxine")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.pepTextTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityLabel("Medications optional")

            HStack {
                Text("Medications (optional)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.pepTextSecondary)

                Spacer()

                Text("\(text.count)/\(Self.maxLength)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.pepTextTertiary)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.pepInfo)
                    .padding(.top, 1)

                Text("This is only for context and does not replace medical advice from your clinician.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pepInfoMuted)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        }
    }

    static func limitedText(_ value: String) -> String {
        String(value.prefix(maxLength))
    }

    static func remainingCharacters(for value: String) -> Int {
        max(0, maxLength - limitedText(value).count)
    }
}

#Preview("Medications Step") {
    MedicationsStepView(text: .constant("Metformin"))
        .padding(24)
        .background(Color.pepBackground)
        .previewLayout(.fixed(width: 393, height: 300))
}
