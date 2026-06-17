import SwiftUI

struct OnboardingQuestionnaireStep: Equatable {
    let step: Int
    let title: String
    let subtitle: String
}

enum OnboardingFlowScreen: Equatable {
    case intro
    case questionnaire(OnboardingQuestionnaireStep)
    case placeholder
}

struct OnboardingFlowView: View {
    @Environment(\.dependencies) private var deps
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = deps.onboardingViewModel

        Group {
            switch Self.screen(for: model.draft.currentStep) {
            case .intro:
                OnboardingIntroView(
                    continueAction: model.continueToNextStep,
                    signInAction: deps.flow.showSignIn
                )
            case .questionnaire(let step):
                questionnaire(model: model, step: step) {
                    questionnaireContent(for: model.draft.currentStep, model: model)
                }
            case .placeholder:
                Color.pepBackground
                    .ignoresSafeArea()
            }
        }
        .id(model.draft.currentStep)
        .transition(stepTransition(for: model))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: model.draft.currentStep)
    }

    static func screen(for step: OnboardingStep) -> OnboardingFlowScreen {
        switch step {
        case .intro:
            return .intro
        case .age:
            return .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 1,
                    title: "How old are you?",
                    subtitle: "Your age helps peppy contextualize your health patterns and personalize your insights."
                )
            )
        case .height:
            return .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 2,
                    title: "What's your height?",
                    subtitle: "Your height helps peppy contextualize your health patterns and trends."
                )
            )
        case .weight:
            return .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 3,
                    title: "What is your current weight?",
                    subtitle: "This creates your starting point. You can update it during daily check-ins."
                )
            )
        case .peptides:
            return .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 4,
                    title: "What peptides are you taking?",
                    subtitle: "Select any you're currently using or planning to start. You can always update this later."
                )
            )
        case .medications:
            return .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 5,
                    title: "Any other medications?",
                    subtitle: "This is optional. It helps peppy flag potential interactions and provide safer insights."
                )
            )
        case .workout:
            return .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 6,
                    title: "How often do you work out?",
                    subtitle: "This helps peppy understand your activity level and tailor recovery insights."
                )
            )
        case .goals:
            return .questionnaire(
                OnboardingQuestionnaireStep(
                    step: 7,
                    title: "What do you hope to get out of peppy?",
                    subtitle: "Pick as many as you'd like. This helps us shape your experience."
                )
            )
        case .health, .notifications:
            return .placeholder
        }
    }

    @ViewBuilder
    private func questionnaireContent(for step: OnboardingStep, model: OnboardingViewModel) -> some View {
        @Bindable var model = model

        switch step {
        case .age:
            AgeStepView(
                age: Binding(
                    get: { model.draft.age },
                    set: model.setAge
                )
            )
        case .height:
            HeightStepView(
                centimeters: Binding(
                    get: { model.draft.heightCentimeters },
                    set: { model.setHeightCentimeters($0, unit: model.draft.preferredHeightUnit) }
                ),
                unit: Binding(
                    get: { model.draft.preferredHeightUnit },
                    set: { model.setHeightCentimeters(model.draft.heightCentimeters, unit: $0) }
                )
            )
        case .weight:
            WeightStepView(
                kilograms: Binding(
                    get: { model.draft.weightKilograms },
                    set: { model.setWeightKilograms($0, unit: model.draft.preferredWeightUnit) }
                ),
                unit: Binding(
                    get: { model.draft.preferredWeightUnit },
                    set: { model.setWeightKilograms(model.draft.weightKilograms, unit: $0) }
                )
            )
        case .peptides:
            PeptidesStepView(
                selected: model.draft.selectedPeptides,
                toggle: model.togglePeptide
            )
        case .medications:
            MedicationsStepView(
                text: Binding(
                    get: { model.draft.otherMedications ?? "" },
                    set: { model.setOtherMedications(MedicationsStepView.limitedText($0)) }
                )
            )
        case .workout:
            WorkoutStepView(
                selectedDays: model.draft.workoutDaysPerWeek,
                select: model.setWorkoutDays
            )
        case .goals:
            GoalsStepView(
                selected: model.draft.goals,
                toggle: model.toggleGoal,
                customGoal: Binding(
                    get: { model.draft.customGoal ?? "" },
                    set: model.setCustomGoal
                )
            )
        case .intro, .health, .notifications:
            EmptyView()
        }
    }

    private func questionnaire<Content: View>(
        model: OnboardingViewModel,
        step: OnboardingQuestionnaireStep,
        @ViewBuilder content: () -> Content
    ) -> some View {
        OnboardingScaffold(
            step: step.step,
            title: Text(step.title),
            subtitle: step.subtitle,
            primaryAction: model.continueToNextStep,
            backAction: model.goBack,
            skipAction: model.skipCurrentStep,
            content: content
        )
    }

    private func stepTransition(for model: OnboardingViewModel) -> AnyTransition {
        guard !reduceMotion else { return .opacity }

        let insertion: Edge = model.navigationDirection == .forward ? .trailing : .leading
        let removal: Edge = model.navigationDirection == .forward ? .leading : .trailing

        return .asymmetric(
            insertion: .move(edge: insertion).combined(with: .opacity),
            removal: .move(edge: removal).combined(with: .opacity)
        )
    }
}

#Preview("Onboarding Flow - Intro") {
    OnboardingFlowView()
        .withDependencies(.mock())
        .previewLayout(.fixed(width: 393, height: 852))
}

#Preview("Onboarding Flow - Age") {
    let deps = Dependencies.mock()
    deps.onboardingViewModel.draft.currentStep = .age

    return OnboardingFlowView()
        .withDependencies(deps)
        .previewLayout(.fixed(width: 393, height: 852))
}

#Preview("Onboarding Flow - Accessibility") {
    let deps = Dependencies.mock()
    deps.onboardingViewModel.draft.currentStep = .height

    return OnboardingFlowView()
        .withDependencies(deps)
        .environment(\.dynamicTypeSize, .accessibility3)
        .previewLayout(.fixed(width: 393, height: 852))
}

#Preview("Onboarding Flow - Peptides") {
    let deps = Dependencies.mock()
    deps.onboardingViewModel.draft.currentStep = .peptides
    deps.onboardingViewModel.draft.selectedPeptides = ["Retatrutide", "BPC-157"]

    return OnboardingFlowView()
        .withDependencies(deps)
        .previewLayout(.fixed(width: 393, height: 852))
}
