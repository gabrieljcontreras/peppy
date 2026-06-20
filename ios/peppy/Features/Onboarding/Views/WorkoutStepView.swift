import SwiftUI

struct WorkoutStepView: View {
    let selectedDays: Int?
    let select: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0...7, id: \.self) { days in
                    dayButton(days)
                }
            }

            Text(Self.summary(for: selectedDays))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.pepTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.pepSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

            Text("days per week")
                .font(.system(size: 12))
                .foregroundStyle(Color.pepTextTertiary)
        }
    }

    static func summary(for days: Int?) -> String {
        guard let days else { return "Choose your weekly rhythm" }

        switch days {
        case 0:
            return "Rest-focused"
        case 1:
            return "1 day per week"
        case 2...5:
            return "2-5 days per week"
        case 6:
            return "6 days per week"
        case 7:
            return "Daily"
        default:
            return "Choose your weekly rhythm"
        }
    }

    private func dayButton(_ days: Int) -> some View {
        let isSelected = selectedDays == days

        return Button {
            select(days)
        } label: {
            Text("\(days)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.pepTextPrimary)
                .frame(width: 52, height: 52)
                .background(isSelected ? Color.pepPrimary : Color.pepSurface)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(isSelected ? Color.pepPrimary : Color.pepBorder, lineWidth: 1.2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(days) workout days per week")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Workout Step") {
    WorkoutStepView(selectedDays: 3, select: { _ in })
        .padding(24)
        .background(Color.pepBackground)
        .previewLayout(.fixed(width: 393, height: 280))
}
