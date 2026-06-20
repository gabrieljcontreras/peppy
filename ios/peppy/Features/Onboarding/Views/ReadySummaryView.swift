import SwiftUI

struct ReadySummaryRow: Equatable, Identifiable {
    let icon: String
    let title: String
    let value: String

    var id: String { title }
}

struct ReadySummaryView: View {
    let draft: OnboardingDraft
    let continueAction: () -> Void
    let signInAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 10)

                PeppyLogo(size: 40)

                Text("You're ready.")
                    .font(.system(size: 31, weight: .bold, design: .serif))
                    .foregroundStyle(Color.pepTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Your baseline and preferences are ready to personalize peppy.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pepTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(Self.rows(for: draft)) { row in
                        summaryRow(row)
                    }
                }
                .padding(.top, 4)

                PepButton(title: "Go to my dashboard", action: continueAction)
                    .padding(.top, 8)

                Button("Already have an account? Sign in", action: signInAction)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.pepPrimary)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.pepBackground.ignoresSafeArea())
    }

    static func rows(for draft: OnboardingDraft) -> [ReadySummaryRow] {
        var rows: [ReadySummaryRow] = []

        if let baseline = baselineValue(for: draft) {
            rows.append(
                ReadySummaryRow(
                    icon: "birthday.cake",
                    title: "Baseline",
                    value: baseline
                )
            )
        }

        if !draft.selectedPeptides.isEmpty {
            rows.append(
                ReadySummaryRow(
                    icon: "pills",
                    title: "Peptides",
                    value: draft.selectedPeptides.joined(separator: ", ")
                )
            )
        }

        if let medications = draft.otherMedications {
            rows.append(
                ReadySummaryRow(
                    icon: "cross.case",
                    title: "Medications",
                    value: medications
                )
            )
        }

        if let days = draft.workoutDaysPerWeek {
            rows.append(
                ReadySummaryRow(
                    icon: "figure.run",
                    title: "Activity",
                    value: workoutValue(for: days)
                )
            )
        }

        if !draft.goals.isEmpty || draft.customGoal != nil {
            var values = draft.goals.map(\.title).sorted()
            if let customGoal = draft.customGoal {
                values.append(customGoal)
            }

            rows.append(
                ReadySummaryRow(
                    icon: "target",
                    title: "Goals",
                    value: values.joined(separator: ", ")
                )
            )
        }

        rows.append(
            ReadySummaryRow(
                icon: "heart.text.square",
                title: "Apple Health",
                value: draft.healthOutcome == .requested ? "Requested" : "Not connected"
            )
        )
        rows.append(
            ReadySummaryRow(
                icon: "bell",
                title: "Notifications",
                value: draft.notificationOutcome == .authorized ? "Enabled" : "Not enabled"
            )
        )

        return rows
    }

    private static func baselineValue(for draft: OnboardingDraft) -> String? {
        var values: [String] = []

        if let age = draft.age {
            values.append("Age \(age)")
        }

        if let height = heightValue(for: draft) {
            values.append(height)
        }

        if let weight = weightValue(for: draft) {
            values.append(weight)
        }

        return values.isEmpty ? nil : values.joined(separator: ", ")
    }

    private static func heightValue(for draft: OnboardingDraft) -> String? {
        guard let centimeters = draft.heightCentimeters else { return nil }

        switch draft.preferredHeightUnit {
        case .feetAndInches:
            let parts = HeightStepView.imperialParts(from: centimeters)
            return "\(parts.feet) ft \(parts.inches) in"
        case .centimeters:
            return "\(Int(centimeters.rounded())) cm"
        }
    }

    private static func weightValue(for draft: OnboardingDraft) -> String? {
        guard draft.weightKilograms != nil else { return nil }

        let value = WeightStepView.displayedValue(
            from: draft.weightKilograms,
            unit: draft.preferredWeightUnit
        )

        switch draft.preferredWeightUnit {
        case .pounds:
            return "\(value) lb"
        case .kilograms:
            return "\(value) kg"
        }
    }

    private static func workoutValue(for days: Int) -> String {
        switch days {
        case 0:
            return "Rest-focused"
        case 1:
            return "1 day per week"
        default:
            return "\(days) days per week"
        }
    }

    private func summaryRow(_ row: ReadySummaryRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.pepPrimary)
                .frame(width: 38, height: 38)
                .background(Color.pepPrimaryMuted)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)

                Text(row.value)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pepBorder, lineWidth: 1)
        }
    }
}

#Preview("Ready Summary") {
    var draft = OnboardingDraft()
    draft.age = 32
    draft.selectedPeptides = ["Retatrutide", "BPC-157"]
    draft.workoutDaysPerWeek = 4
    draft.goals = [.trackProtocols, .seeWhatWorks]
    draft.healthOutcome = .requested
    draft.notificationOutcome = .authorized

    return ReadySummaryView(draft: draft, continueAction: {}, signInAction: {})
}
