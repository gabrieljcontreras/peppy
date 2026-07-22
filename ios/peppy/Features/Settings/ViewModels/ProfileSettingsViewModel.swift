import Foundation
import Observation

enum ProfileSettingsValidation {
    static func isValidWeight(kilograms: Double) -> Bool {
        kilograms.isFinite && (27...318).contains(kilograms)
    }

    static func isValidHeight(centimeters: Double) -> Bool {
        centimeters.isFinite && (100...250).contains(centimeters)
    }

    static func isValidHeight(feet: Int, inches: Int) -> Bool {
        guard (0...11).contains(inches) else { return false }
        return isValidHeight(
            centimeters: HeightUnit.feetAndInches.centimeters(feet: feet, inches: inches)
        )
    }
}

struct ProfileDraft: Equatable {
    let schemaVersion: Int
    var fullName: String
    let email: String
    var weightUnit: WeightUnit
    var heightUnit: HeightUnit
    var baselineDate: Date?
    var baselineWeightKg: Double?
    var baselineHeightCm: Double?
    var primaryGoal: OnboardingGoal?
    var secondaryGoal: OnboardingGoal?
    var focusArea: OnboardingGoal?

    init(user: User?, profile: AccountProfile?) {
        schemaVersion = profile?.schemaVersion ?? OnboardingDraft.currentSchemaVersion
        fullName = user?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        email = user?.email ?? ""
        weightUnit = profile?.preferredWeightUnit
            .flatMap(WeightUnit.init(serverValue:)) ?? .pounds
        heightUnit = profile?.preferredHeightUnit
            .flatMap(HeightUnit.init(serverValue:)) ?? .feetAndInches
        baselineDate = profile?.baselineDate
        baselineWeightKg = profile?.weightKg
        baselineHeightCm = profile?.heightCm
        primaryGoal = profile?.primaryGoal.flatMap(OnboardingGoal.init(serverValue:))
        secondaryGoal = profile?.secondaryGoal.flatMap(OnboardingGoal.init(serverValue:))
        focusArea = profile?.focusArea.flatMap(OnboardingGoal.init(serverValue:))
    }

    var trimmedFullName: String {
        fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var userRequest: UpdateCurrentUserRequest {
        UpdateCurrentUserRequest(displayName: trimmedFullName, timezone: nil)
    }

    var profileRequest: ProfileUpdateRequest {
        ProfileUpdateRequest(
            schemaVersion: schemaVersion,
            heightCm: baselineHeightCm,
            preferredHeightUnit: heightUnit.serverValue,
            weightKg: baselineWeightKg,
            preferredWeightUnit: weightUnit.serverValue,
            baselineDate: baselineDate,
            primaryGoal: primaryGoal?.serverValue,
            secondaryGoal: secondaryGoal?.serverValue,
            focusArea: focusArea?.serverValue
        )
    }
}

@MainActor
@Observable
final class ProfileSettingsViewModel {
    private let store: SettingsStore
    private let weightUnitPreferences: WeightUnitPreferences
    @ObservationIgnored private let now: () -> Date
    private var confirmedDraft: ProfileDraft

    var draft: ProfileDraft
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    var isDiscardConfirmationPresented = false

    init(
        store: SettingsStore,
        weightUnitPreferences: WeightUnitPreferences,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.weightUnitPreferences = weightUnitPreferences
        self.now = now

        let draft = ProfileDraft(user: store.user, profile: store.profile)
        confirmedDraft = draft
        self.draft = draft

        if let userID = store.user?.id {
            weightUnitPreferences.activate(userID: userID, serverUnit: draft.weightUnit)
        }
    }

    var hasUnsavedChanges: Bool {
        draft != confirmedDraft
    }

    var canSave: Bool {
        hasUnsavedChanges && validationErrorMessage == nil && !isSaving
    }

    var validationErrorMessage: String? {
        if draft.trimmedFullName.isEmpty {
            return "Enter your full name."
        }
        if draft.trimmedFullName.count > 100 {
            return "Full name must be 100 characters or fewer."
        }
        if draft.primaryGoal == nil {
            return "Choose a primary goal."
        }
        if let date = draft.baselineDate,
           Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: now()) {
            return "Baseline date cannot be in the future."
        }
        if let kilograms = draft.baselineWeightKg,
           !ProfileSettingsValidation.isValidWeight(kilograms: kilograms) {
            return "Enter a baseline weight between 27 and 318 kg."
        }
        if let centimeters = draft.baselineHeightCm,
           !ProfileSettingsValidation.isValidHeight(centimeters: centimeters) {
            return "Enter a baseline height between 100 and 250 cm."
        }
        return nil
    }

    func refreshIfNeeded() async {
        guard store.profile == nil else { return }
        await store.refresh()
        synchronizeFromStoreIfUnedited()
    }

    func synchronizeFromStoreIfUnedited() {
        guard !hasUnsavedChanges else { return }
        let refreshed = ProfileDraft(user: store.user, profile: store.profile)
        confirmedDraft = refreshed
        draft = refreshed

        if let userID = store.user?.id {
            weightUnitPreferences.activate(userID: userID, serverUnit: refreshed.weightUnit)
        }
    }

    func setBaselineWeight(displayValue: Double?) {
        draft.baselineWeightKg = displayValue.map(draft.weightUnit.kilograms(from:))
    }

    func setBaselineHeight(feet: Int, inches: Int) {
        draft.baselineHeightCm = draft.heightUnit.centimeters(feet: feet, inches: inches)
    }

    func setBaselineHeight(centimeters: Double?) {
        draft.baselineHeightCm = centimeters
    }

    @discardableResult
    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await store.updateProfile(
                user: draft.userRequest,
                profile: draft.profileRequest
            )

            let confirmed = ProfileDraft(user: store.user, profile: store.profile)
            confirmedDraft = confirmed
            draft = confirmed

            if let userID = store.user?.id {
                weightUnitPreferences.activate(
                    userID: userID,
                    serverUnit: confirmed.weightUnit
                )
            }
            return true
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
            return false
        }
    }

    func requestDismiss() -> Bool {
        guard hasUnsavedChanges else { return true }
        isDiscardConfirmationPresented = true
        return false
    }

    func cancelDiscardConfirmation() {
        isDiscardConfirmationPresented = false
    }

    func discardChanges() {
        draft = confirmedDraft
        errorMessage = nil
        isDiscardConfirmationPresented = false
    }
}
