# iOS Development Progress

## 2026-06-16 to 2026-06-17

Branch: `iOS_onboarding_dev`

### Completed

- Finished Task 4 from the onboarding/auth flow plan: native permission services for onboarding.
- Added HealthKit and notification permission abstractions with live and mock implementations.
- Moved shared permission outcome state into `Core/Permissions/PermissionOutcome.swift`.
- Injected permission services through `Dependencies.live()` and `Dependencies.mock()`.
- Added HealthKit entitlement and the Health share usage description to the Xcode project.
- Added unit coverage for permission service mocks.
- Finished Task 5 from the onboarding/auth flow plan: deterministic app-flow routing.
- Added `AppFlowCoordinator` with explicit launch, onboarding, ready-summary, future-paywall, authentication, dashboard, authentication-success, and logout routes.
- Injected the shared coordinator through `Dependencies.live()` and `Dependencies.mock()`.
- Added unit coverage for launch routing, session-validation errors, future-paywall bypass, draft association after auth, and logout routing.
- Finished Task 6 from the onboarding/auth flow plan: onboarding state management.
- Added `OnboardingViewModel` with draft resume, immediate persistence, step navigation, skip handling, permission requests, optional text normalization, and completion state.
- Injected one stable onboarding view model through `Dependencies.live()` and `Dependencies.mock()`.
- Added unit coverage for every Task 6 view-model behavior.
- Finished Task 7 from the onboarding/auth flow plan: shared Figma-matched onboarding components.
- Added `PepOnboardingProgress`, `PepSelectionChip`, and `OnboardingScaffold` using the existing Peppy design tokens.
- Added component coverage for progress accessibility text, chip selection/action state, and scaffold navigation defaults.
- Finished Task 8 from the onboarding/auth flow plan: intro and baseline questionnaire screens.
- Added `OnboardingIntroView`, `AgeStepView`, `HeightStepView`, `WeightStepView`, and `OnboardingFlowView`.
- Added resume-aware baseline display helpers for persisted height and weight values without saving untouched defaults.
- Added flow metadata coverage for the intro, age, height, weight, and later-step placeholders.
- Finished Task 9 from the onboarding/auth flow plan: peptide, medication, workout, and goal onboarding steps.
- Added `PeptideCatalog` under `Core/Data` with alphabetized, deduplicated Android peptide display names and no dosing guidance.
- Added `PeptidesStepView`, `MedicationsStepView`, `WorkoutStepView`, and `GoalsStepView` with Peppy design tokens, persisted bindings, selected chips, text limits, workout summaries, and goal multi-select.
- Replaced the `.peptides`, `.medications`, `.workout`, and `.goals` placeholders in `OnboardingFlowView` with steps 4 through 7.
- Added questionnaire-step coverage for catalog uniqueness, peptide suggestions, custom peptide duplicate prevention, medication limits, workout summaries, goal options, and flow metadata.
- Finished Task 10 from the onboarding/auth flow plan: permission screens and ready summary.
- Added `HealthPermissionView`, `NotificationPermissionView`, and `ReadySummaryView`.
- Wired `.health` and `.notifications` into `OnboardingFlowView`; notification request and skip now complete the draft before showing the ready-summary route.
- Added Task 10 coverage for permission flow metadata, Apple Health read categories, notification cards, truthful ready-summary rows, and notification completion routing.
- Finished Task 11 from the onboarding/auth flow plan: root routing and authentication handoff.
- Replaced `RootView`'s old `appState.isAuthenticated` split with `deps.flow.route` rendering for launch, onboarding, ready summary, future-paywall bypass, authentication, and dashboard.
- Added `LaunchResolutionView` for launch retry/error handling.
- Guarded root launch resolution so `resolveLaunch()` only runs while the coordinator is still on `.launching`.
- Connected registration and sign-in success to `AppFlowCoordinator.didAuthenticate(user:)`, preserving token save order and the registration success toast.
- Replaced nested auth navigation links with coordinator route switches and coordinator-owned auth back-button behavior.
- Fixed the review-found fresh-onboarding sign-in trap: intro sign-in can now return to onboarding, sign-in to registration preserves that back path, and known signed-out launch sign-in still hides back.
- Added accessible Back labels to auth icon back buttons.
- Retired `WelcomeView` from launch routing; it remains only as a temporary preview/product reference.

### Verified

- Focused permission service tests passed.
- Task 5 TDD red test failed for the expected reason: `AppFlowCoordinator` did not exist yet.
- Focused `AppFlowCoordinatorTests` passed with 10 tests.
- Task 6 TDD red test failed for the expected reason: `OnboardingViewModel` did not exist yet.
- Focused `OnboardingViewModelTests` passed with 12 tests.
- Task 7 TDD red test failed for the expected reason: `PepOnboardingProgress`, `PepSelectionChip`, and `OnboardingScaffold` did not exist yet.
- Focused `OnboardingComponentTests` passed with 4 tests.
- Task 8 TDD red test failed for the expected reason: `OnboardingIntroView`, `AgeStepView`, `HeightStepView`, `WeightStepView`, and `OnboardingFlowView` did not exist yet.
- Focused `OnboardingBaselineFlowTests` passed with 6 tests.
- Task 9 TDD red test failed for the expected reason: `PeptidesStepView`, `MedicationsStepView`, `WorkoutStepView`, and `GoalsStepView` did not exist yet.
- Focused Task 9 tests passed with 13 tests across `OnboardingQuestionnaireStepsTests`, `OnboardingDraftTests`, and `OnboardingBaselineFlowTests`.
- Task 10 TDD red test failed for the expected reason: `OnboardingFlowScreen` did not yet have `.healthPermission` or `.notificationPermission`.
- Focused Task 10 tests passed across `OnboardingBaselineFlowTests`, `OnboardingQuestionnaireStepsTests`, and `OnboardingViewModelTests`.
- Task 11 TDD red tests failed for the expected reasons: coordinator/root/auth helper seams did not exist yet, then the root launch-resolution guard did not exist yet.
- Focused `AppFlowCoordinatorTests` passed with 20 tests.
- Full iOS test suite passed with 64 tests on `iPhone 17` iOS 26.5.
- Generic simulator debug build passed with `CODE_SIGNING_ALLOWED=NO`.
- Task 11 root rendering now shows `.readySummary`, bypasses `.futurePaywall` into registration, and sends auth success through the coordinator.
- Existing Swift concurrency warnings remain in `Core/Network/APIClient.swift`; they were not introduced by the permission task.
- In-app simulator visual walkthrough remains pending for final onboarding QA.

### External Follow-Up

- Apple Developer configuration still needs the HealthKit capability enabled for the app identifier before device/archive signing.
- No backend API changes were required for Tasks 4, 5, 6, 7, 8, 9, 10, or 11.

### Task 12 Resume Point

- Next implementation task is Task 12: create the app icon and native launch screen.
- Resume Task 12 from the approved plan by generating the app icon and launch logo assets from the supplied Figma source, adding `LaunchBackground`, wiring `LaunchScreen.storyboard`, and matching the first SwiftUI launch frame.

### Workspace Notes

- Gabriel committed the completed Task 4 work.
- Task 5, Task 6, Task 7, Task 8, Task 9, Task 10, and Task 11 changes are implemented and verified locally.
- Task 9, Task 10, and Task 11 were verified but not committed because this pass is continuing task-by-task without an explicit commit request.
- Only Xcode local UI state may remain modified and should stay out of commits unless intentionally changed.
