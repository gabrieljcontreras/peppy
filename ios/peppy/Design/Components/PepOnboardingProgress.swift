import SwiftUI

struct PepOnboardingProgress: View {
    let currentStep: Int
    let totalSteps: Int

    var accessibilityText: String {
        "Step \(currentStep) of \(totalSteps)"
    }

    var body: some View {
        HStack(spacing: 7) {
            ForEach(1...max(totalSteps, 1), id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.pepPrimary : Color.pepPrimary.opacity(0.18))
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

#Preview("Onboarding Progress") {
    PepOnboardingProgress(currentStep: 3, totalSteps: 7)
        .padding(24)
        .background(Color.pepBackground)
        .previewLayout(.fixed(width: 393, height: 120))
}

#Preview("Onboarding Progress - Accessibility") {
    PepOnboardingProgress(currentStep: 7, totalSteps: 7)
        .padding(24)
        .background(Color.pepBackground)
        .environment(\.dynamicTypeSize, .accessibility3)
        .previewLayout(.fixed(width: 393, height: 120))
}
