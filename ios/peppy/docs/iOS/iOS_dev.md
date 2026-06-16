# iOS Development Progress

## 2026-06-16

Branch: `iOS_onboarding_dev`

### Completed

- Finished Task 4 from the onboarding/auth flow plan: native permission services for onboarding.
- Added HealthKit and notification permission abstractions with live and mock implementations.
- Moved shared permission outcome state into `Core/Permissions/PermissionOutcome.swift`.
- Injected permission services through `Dependencies.live()` and `Dependencies.mock()`.
- Added HealthKit entitlement and the Health share usage description to the Xcode project.
- Added unit coverage for permission service mocks.

### Verified

- Focused permission service tests passed.
- Full iOS test suite passed with 9 tests.
- Generic simulator debug build passed with `CODE_SIGNING_ALLOWED=NO`.
- Existing Swift concurrency warnings remain in `Core/Network/APIClient.swift`; they were not introduced by the permission task.

### External Follow-Up

- Apple Developer configuration still needs the HealthKit capability enabled for the app identifier before device/archive signing.
- No backend API changes were required for Task 4.

### Task 5 Resume Point

- Next implementation task is Task 5: `AppFlowCoordinator`.
- We briefly started the Task 5 TDD red test, but stopped before implementation. The incomplete WIP was removed so the workspace is not left in a broken state.
- Resume Task 5 from the approved plan by adding `peppyTests/AppFlowCoordinatorTests.swift`, confirming the expected red failure, then implementing `App/AppFlowCoordinator.swift` and injecting it into `App/Dependencies.swift`.

### Workspace Notes

- Gabriel committed the completed Task 4 work.
- Only Xcode local UI state may remain modified and should stay out of commits unless intentionally changed.
