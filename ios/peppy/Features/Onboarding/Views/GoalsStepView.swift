import SwiftUI

struct GoalsStepView: View {
    let selected: Set<OnboardingGoal>
    let toggle: (OnboardingGoal) -> Void
    @Binding var customGoal: String

    static let options = OnboardingGoal.allCases

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 142), spacing: 10)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(Self.options) { goal in
                    PepSelectionChip(title: goal.title, isSelected: selected.contains(goal)) {
                        toggle(goal)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PepTextField(
                placeholder: "Anything else?",
                text: $customGoal
            )
        }
    }
}

#Preview("Goals Step") {
    GoalsStepView(
        selected: [.trackProtocols, .seeWhatWorks],
        toggle: { _ in },
        customGoal: .constant("")
    )
    .padding(24)
    .background(Color.pepBackground)
    .previewLayout(.fixed(width: 393, height: 320))
}
