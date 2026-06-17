import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    enum NavigationDirection {
        case forward
        case backward
    }

    var draft: OnboardingDraft
    var isRequestingPermission = false
    var navigationDirection: NavigationDirection = .forward

    private let store: OnboardingStoreProtocol
    private let healthKit: HealthKitServiceProtocol
    private let notifications: NotificationPermissionServiceProtocol

    init(
        store: OnboardingStoreProtocol,
        healthKit: HealthKitServiceProtocol,
        notifications: NotificationPermissionServiceProtocol
    ) {
        self.store = store
        self.healthKit = healthKit
        self.notifications = notifications
        self.draft = store.loadAnonymousDraft() ?? OnboardingDraft()
    }

    func setAge(_ age: Int?) {
        draft.age = age
        save()
    }

    func setHeightCentimeters(_ value: Double?, unit: HeightUnit) {
        draft.heightCentimeters = value
        draft.preferredHeightUnit = unit
        save()
    }

    func setWeightKilograms(_ value: Double?, unit: WeightUnit) {
        draft.weightKilograms = value
        draft.preferredWeightUnit = unit
        save()
    }

    func togglePeptide(_ name: String) {
        if draft.selectedPeptides.contains(name) {
            draft.selectedPeptides.removeAll { $0 == name }
        } else {
            draft.selectedPeptides.append(name)
        }
        save()
    }

    func setOtherMedications(_ value: String) {
        draft.otherMedications = normalizedOptionalText(value)
        save()
    }

    func setWorkoutDays(_ days: Int?) {
        draft.workoutDaysPerWeek = days
        save()
    }

    func toggleGoal(_ goal: OnboardingGoal) {
        if draft.goals.contains(goal) {
            draft.goals.remove(goal)
        } else {
            draft.goals.insert(goal)
        }
        save()
    }

    func setCustomGoal(_ value: String) {
        draft.customGoal = normalizedOptionalText(value)
        save()
    }

    func continueToNextStep() {
        guard let next = draft.currentStep.next else { return }
        navigationDirection = .forward
        draft.currentStep = next
        save()
    }

    func goBack() {
        guard let previous = draft.currentStep.previous else { return }
        navigationDirection = .backward
        draft.currentStep = previous
        save()
    }

    func skipCurrentStep() {
        if draft.currentStep == .health {
            draft.healthChoice = .skipped
        }

        if draft.currentStep == .notifications {
            draft.notificationChoice = .skipped
            complete()
            return
        }

        continueToNextStep()
    }

    func requestHealthAccess() async {
        isRequestingPermission = true
        draft.healthChoice = .requested
        draft.healthOutcome = await healthKit.requestReadAccess()
        isRequestingPermission = false
        continueToNextStep()
    }

    func requestNotifications() async {
        isRequestingPermission = true
        draft.notificationChoice = .requested
        draft.notificationOutcome = await notifications.requestAuthorization()
        isRequestingPermission = false
        complete()
    }

    func complete() {
        draft.isComplete = true
        save()
    }

    private func save() {
        draft.updatedAt = Date()
        store.saveAnonymousDraft(draft)
    }

    private func normalizedOptionalText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
