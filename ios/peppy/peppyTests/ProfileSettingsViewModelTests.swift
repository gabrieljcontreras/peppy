import SwiftUI
import XCTest
@testable import peppy

@MainActor
final class ProfileSettingsViewModelTests: XCTestCase {
    private let now = APIDateOnly.date(from: "2026-07-22")!

    func testOnboardingGoalServerValuesRoundTripThroughSharedVocabulary() throws {
        for goal in OnboardingGoal.allCases {
            XCTAssertEqual(OnboardingGoal(serverValue: goal.serverValue), goal)
        }
        XCTAssertNil(OnboardingGoal(serverValue: "settings_only_goal"))
    }

    func testSharedHeightAndWeightConversionsRoundTripProfileValues() {
        let centimeters = HeightUnit.feetAndInches.centimeters(feet: 5, inches: 10)
        let parts = HeightUnit.feetAndInches.imperialParts(centimeters: centimeters)

        XCTAssertEqual(centimeters, 177.8, accuracy: 0.001)
        XCTAssertEqual(parts.feet, 5)
        XCTAssertEqual(parts.inches, 10)
        XCTAssertEqual(HeightUnit.feetAndInches.format(centimeters: centimeters), "5 ft 10 in")
        XCTAssertEqual(HeightUnit.centimeters.format(centimeters: centimeters), "178 cm")
        XCTAssertEqual(WeightUnit.pounds.kilograms(from: 186.4), 84.55, accuracy: 0.01)
    }

    func testDraftMapsConfirmedAccountAndKeepsEmailReadOnly() {
        let fixture = makeFixture()

        XCTAssertEqual(fixture.model.draft.fullName, "Alex Morgan")
        XCTAssertEqual(fixture.model.draft.email, "alex.morgan@example.com")
        XCTAssertEqual(fixture.model.draft.weightUnit, .pounds)
        XCTAssertEqual(fixture.model.draft.heightUnit, .feetAndInches)
        XCTAssertEqual(fixture.model.draft.primaryGoal, .trackProtocols)
        XCTAssertEqual(fixture.model.draft.secondaryGoal, .buildHabits)
        XCTAssertEqual(fixture.model.draft.focusArea, .understandBody)
        XCTAssertFalse(ProfileSettingsPresentation.isEmailEditable)
        XCTAssertEqual(
            ProfileSettingsPresentation.emailAccessibilityValue(fixture.model.draft.email),
            "alex.morgan@example.com, read only"
        )
    }

    func testBaselineDatePresentationPreservesTheAPIDateAcrossLocalTimeZones() throws {
        let date = try XCTUnwrap(APIDateOnly.date(from: "2025-05-01"))

        XCTAssertEqual(ProfileSettingsPresentation.baselineDateText(date), "May 1, 2025")
    }

    func testUnchangedDraftDisablesSave() {
        let fixture = makeFixture()

        XCTAssertFalse(fixture.model.hasUnsavedChanges)
        XCTAssertFalse(fixture.model.canSave)
        XCTAssertNil(fixture.model.validationErrorMessage)
    }

    func testValidationRequiresNamePrimaryGoalAndNonFutureBaselineDate() {
        let fixture = makeFixture()

        fixture.model.draft.fullName = "   "
        XCTAssertEqual(fixture.model.validationErrorMessage, "Enter your full name.")
        XCTAssertFalse(fixture.model.canSave)

        fixture.model.draft.fullName = String(repeating: "a", count: 101)
        XCTAssertEqual(
            fixture.model.validationErrorMessage,
            "Full name must be 100 characters or fewer."
        )

        fixture.model.draft.fullName = "Alex Morgan"
        fixture.model.draft.primaryGoal = nil
        XCTAssertEqual(fixture.model.validationErrorMessage, "Choose a primary goal.")

        fixture.model.draft.primaryGoal = .trackProtocols
        fixture.model.draft.baselineDate = now.addingTimeInterval(86_400)
        XCTAssertEqual(
            fixture.model.validationErrorMessage,
            "Baseline date cannot be in the future."
        )
    }

    func testDraftEditsConvertDisplayUnitsIntoCanonicalValues() {
        let fixture = makeFixture()
        fixture.model.draft.weightUnit = .pounds
        fixture.model.draft.heightUnit = .feetAndInches

        fixture.model.setBaselineWeight(displayValue: 186.4)
        fixture.model.setBaselineHeight(feet: 5, inches: 10)

        XCTAssertEqual(try XCTUnwrap(fixture.model.draft.baselineWeightKg), 84.55, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(fixture.model.draft.baselineHeightCm), 177.8, accuracy: 0.001)
    }

    func testImperialHeightEditorUsesTheCanonicalProfileBounds() {
        XCTAssertFalse(ProfileSettingsValidation.isValidHeight(feet: 3, inches: 0))
        XCTAssertTrue(ProfileSettingsValidation.isValidHeight(feet: 3, inches: 4))
        XCTAssertTrue(ProfileSettingsValidation.isValidHeight(feet: 8, inches: 2))
        XCTAssertFalse(ProfileSettingsValidation.isValidHeight(feet: 8, inches: 3))
    }

    func testSuccessfulSaveTrimsNameClearsOptionalGoalsAndPropagatesWeightPreference() async {
        let fixture = makeFixture()
        let confirmedUser = makeUser(displayName: "Alex Morgan-Smith")
        let confirmedProfile = makeProfile(
            preferredWeightUnit: "kg",
            secondaryGoal: nil,
            focusArea: nil
        )
        fixture.api.setMockResponse(
            confirmedUser,
            for: .updateCurrentUser(
                UpdateCurrentUserRequest(displayName: "Alex Morgan-Smith", timezone: nil)
            )
        )
        fixture.api.setMockResponse(
            confirmedProfile,
            for: .updateProfile(makeProfileRequest())
        )

        fixture.model.draft.fullName = "  Alex Morgan-Smith  "
        fixture.model.draft.weightUnit = .kilograms
        fixture.model.draft.secondaryGoal = nil
        fixture.model.draft.focusArea = nil

        XCTAssertEqual(fixture.preferences.unit, .pounds)
        let didSave = await fixture.model.save()
        XCTAssertTrue(didSave)
        XCTAssertEqual(fixture.preferences.unit, .kilograms)
        XCTAssertFalse(fixture.model.hasUnsavedChanges)
        XCTAssertNil(fixture.model.errorMessage)
        XCTAssertEqual(fixture.api.requestLog.count, 2)

        guard case .updateCurrentUser(let userRequest) = fixture.api.requestLog[0],
              case .updateProfile(let profileRequest) = fixture.api.requestLog[1] else {
            return XCTFail("Expected ordered account then profile updates")
        }
        XCTAssertEqual(userRequest.displayName, "Alex Morgan-Smith")
        XCTAssertNil(userRequest.timezone)
        XCTAssertEqual(profileRequest.preferredWeightUnit, "kg")
        XCTAssertNil(profileRequest.secondaryGoal)
        XCTAssertNil(profileRequest.focusArea)
    }

    func testAccountUpdateFailureRetainsCompleteDraftAndDoesNotChangePreference() async {
        let fixture = makeFixture()
        fixture.api.setMockError(
            .serverError,
            for: .updateCurrentUser(
                UpdateCurrentUserRequest(displayName: "Failure Draft", timezone: nil)
            )
        )
        fixture.model.draft.fullName = "Failure Draft"
        fixture.model.draft.weightUnit = .kilograms

        let didSave = await fixture.model.save()
        XCTAssertFalse(didSave)

        XCTAssertEqual(fixture.model.draft.fullName, "Failure Draft")
        XCTAssertEqual(fixture.model.draft.weightUnit, .kilograms)
        XCTAssertEqual(fixture.preferences.unit, .pounds)
        XCTAssertNotNil(fixture.model.errorMessage)
        XCTAssertEqual(fixture.api.requestLog.count, 1)
    }

    func testProfileUpdateFailureAfterAccountSuccessRetainsDraftAndDoesNotChangePreference() async {
        let fixture = makeFixture()
        fixture.api.setMockResponse(
            makeUser(displayName: "Partial Draft"),
            for: .updateCurrentUser(
                UpdateCurrentUserRequest(displayName: "Partial Draft", timezone: nil)
            )
        )
        fixture.api.setMockError(.serverError, for: .updateProfile(makeProfileRequest()))
        fixture.model.draft.fullName = "Partial Draft"
        fixture.model.draft.weightUnit = .kilograms

        let didSave = await fixture.model.save()
        XCTAssertFalse(didSave)

        XCTAssertEqual(fixture.model.draft.fullName, "Partial Draft")
        XCTAssertEqual(fixture.model.draft.weightUnit, .kilograms)
        XCTAssertEqual(fixture.preferences.unit, .pounds)
        XCTAssertNotNil(fixture.model.errorMessage)
        XCTAssertEqual(fixture.api.requestLog.count, 2)
    }

    func testDismissRequestsConfirmationAndDiscardRestoresConfirmedValues() {
        let fixture = makeFixture()
        fixture.model.draft.fullName = "Unsaved name"

        XCTAssertFalse(fixture.model.requestDismiss())
        XCTAssertTrue(fixture.model.isDiscardConfirmationPresented)

        fixture.model.cancelDiscardConfirmation()
        XCTAssertFalse(fixture.model.isDiscardConfirmationPresented)
        XCTAssertEqual(fixture.model.draft.fullName, "Unsaved name")

        _ = fixture.model.requestDismiss()
        fixture.model.discardChanges()
        XCTAssertEqual(fixture.model.draft.fullName, "Alex Morgan")
        XCTAssertFalse(fixture.model.hasUnsavedChanges)
        XCTAssertFalse(fixture.model.isDiscardConfirmationPresented)
        XCTAssertTrue(fixture.model.requestDismiss())
    }

    func testWeightPreferencesAreScopedToTheActiveAccount() {
        let suite = "ProfileWeightPreferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = WeightUnitPreferences(defaults: defaults)
        let firstUser = UUID()
        let secondUser = UUID()

        preferences.activate(userID: firstUser, serverUnit: .kilograms)
        XCTAssertEqual(preferences.unit, .kilograms)

        preferences.resetSession()
        preferences.activate(userID: secondUser, serverUnit: nil)
        XCTAssertEqual(preferences.unit, .pounds)

        preferences.activate(userID: firstUser, serverUnit: nil)
        XCTAssertEqual(preferences.unit, .kilograms)
    }

    func testProfileFramePreservesMeasuredFigmaContract() {
        XCTAssertEqual(ProfileSettingsFigmaLayout.referenceCanvasWidth, 853)
        XCTAssertEqual(ProfileSettingsFigmaLayout.referenceCanvasHeight, 1_844)
        XCTAssertEqual(ProfileSettingsFigmaLayout.horizontalPadding, 22)
        XCTAssertEqual(ProfileSettingsFigmaLayout.cardCornerRadius, 8)
        XCTAssertEqual(ProfileSettingsFigmaLayout.headerControlDiameter, 30)
        XCTAssertEqual(ProfileSettingsFigmaLayout.headerTopAdjustment, -18)
        XCTAssertEqual(ProfileSettingsFigmaLayout.bodyTopAdjustment, -8)
        XCTAssertEqual(ProfileSettingsFigmaLayout.accountRowMinimumHeight, 51)
        XCTAssertEqual(ProfileSettingsFigmaLayout.baselineRowMinimumHeight, 44)
        XCTAssertEqual(ProfileSettingsFigmaLayout.compactRowMinimumHeight, 32)
        XCTAssertEqual(ProfileSettingsFigmaLayout.saveButtonVisualHeight, 32)
        XCTAssertGreaterThanOrEqual(ProfileSettingsFigmaLayout.minimumTapTarget, 44)
        XCTAssertEqual(
            ProfileSettingsPresentation.sectionTitles,
            ["Account information", "Preferences", "Baseline information", "Onboarding goals"]
        )
    }

    private func makeFixture() -> ProfileFixture {
        ProfileFixture(
            user: makeUser(),
            profile: makeProfile(),
            now: { [now] in now }
        )
    }

    private func makeUser(displayName: String = "Alex Morgan") -> User {
        User(
            id: UUID(uuidString: "B95BB392-4761-496D-9C0E-FF80B358C7C7")!,
            email: "alex.morgan@example.com",
            displayName: displayName,
            isVerified: true
        )
    }

    private func makeProfile(
        preferredWeightUnit: String = "lb",
        secondaryGoal: String? = "build_habits",
        focusArea: String? = "understand_body"
    ) -> AccountProfile {
        AccountProfile(
            id: UUID(uuidString: "B95BB392-4761-496D-9C0E-FF80B358C7C7")!,
            schemaVersion: 1,
            heightCm: 177.8,
            preferredHeightUnit: "ft_in",
            weightKg: 84.55,
            preferredWeightUnit: preferredWeightUnit,
            baselineDate: APIDateOnly.date(from: "2025-05-01"),
            primaryGoal: "track_protocols",
            secondaryGoal: secondaryGoal,
            focusArea: focusArea
        )
    }

    private func makeProfileRequest() -> ProfileUpdateRequest {
        ProfileUpdateRequest(
            schemaVersion: 1,
            heightCm: 177.8,
            preferredHeightUnit: "ft_in",
            weightKg: 84.55,
            preferredWeightUnit: "kg",
            baselineDate: APIDateOnly.date(from: "2025-05-01"),
            primaryGoal: "track_protocols",
            secondaryGoal: nil,
            focusArea: nil
        )
    }
}

@MainActor
private struct ProfileFixture {
    let api: MockAPIClient
    let preferences: WeightUnitPreferences
    let store: SettingsStore
    let model: ProfileSettingsViewModel

    init(user: User, profile: AccountProfile, now: @escaping () -> Date) {
        let api = MockAPIClient()
        let suite = "ProfileFixture.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let preferences = WeightUnitPreferences(defaults: defaults)
        let store = SettingsStore(api: api, initialUser: user, cachedProfile: profile)

        self.api = api
        self.preferences = preferences
        self.store = store
        self.model = ProfileSettingsViewModel(
            store: store,
            weightUnitPreferences: preferences,
            now: now
        )
    }
}
