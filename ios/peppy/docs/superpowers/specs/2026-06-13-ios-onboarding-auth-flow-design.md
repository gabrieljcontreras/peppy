# Peppy iOS Onboarding and Authentication Flow Design

## Objective

Build the first iOS MVP entry flow with near-identical visual fidelity to the
supplied `Peppy IOS.fig` file:

1. Native launch screen showing the Peppy P mark.
2. Full pre-auth onboarding questionnaire.
3. Personalized "You're ready" summary.
4. Authentication choice and account creation/sign-in.
5. Main dashboard entry.

Authenticated users skip onboarding and authentication. Signed-out users who
previously created an account on the device go to sign-in. New users receive
the complete onboarding flow.

The future paywall belongs between the ready summary and authentication, but it
is bypassed in this phase.

## Scope

### Included

- Native iOS launch screen using the Peppy P mark.
- Production 1024x1024 app icon using the Peppy P mark.
- Explicit app-flow routing.
- Figma-matched onboarding intro and seven questionnaire steps.
- Optional Apple Health and notification permission steps.
- Personalized ready summary.
- Registration and sign-in handoff.
- Local draft persistence, interrupted-flow resume, and per-user association.
- Routing, persistence, validation, and service tests.
- Simulator verification and visual comparison against Figma.
- `BACKEND.md` describing future API and data requirements.

### Excluded

- Paywall UI, purchases, subscriptions, or StoreKit.
- Backend schema or API implementation.
- Cross-device onboarding synchronization.
- Oura and Whoop authorization.
- Full dashboard implementation beyond the existing main app destination.
- Creating a protocol automatically from a selected peptide. The onboarding
  selection is personalization data until backend/profile support exists.

## Visual Source of Truth

`/Users/gabrielcontreras/Downloads/Peppy IOS.fig` is the primary visual source.
The implementation must closely match its:

- Warm off-white background and coral/ink palette.
- Peppy P mark and wordmark usage.
- Serif accent typography and bold sans-serif hierarchy.
- Segmented coral progress bars.
- Centered numeric pickers and unit toggles.
- Rounded cards, borders, fields, pills, and full-width actions.
- Bottom-aligned Continue, Back, and Skip controls.
- Spacing, alignment, icon scale, and transition direction.

Existing tokens and components under `Design/` remain the implementation
foundation. New styling primitives are allowed only when the Figma pattern is
repeated and cannot be represented cleanly by an existing component.

Native system permission alerts are not restyled. Dynamic Type, VoiceOver,
Reduce Motion, safe areas, keyboard avoidance, and minimum 44-point tap targets
take priority over pixel-level matching when the two conflict.

## App Flow

### States

`AppFlowCoordinator` owns one explicit route:

```text
launching
onboarding
readySummary
futurePaywall
authentication
dashboard
```

`futurePaywall` is a real routing point that immediately advances to
`authentication` in this phase. This keeps paywall insertion from requiring a
navigation rewrite.

Authentication carries a presentation mode:

```text
register
signIn
```

### Launch Resolution

While `launching`, the app checks Keychain and local flow metadata before
showing an interactive screen:

1. A valid access token and successful `/auth/me` response route to
   `dashboard`.
2. An expired access token uses the existing refresh behavior. Successful
   refresh and `/auth/me` route to `dashboard`.
3. Invalid credentials are cleared.
4. If this device records that an account was previously created or used,
   route to `authentication(.signIn)`.
5. If an unauthenticated draft has completed all onboarding questions, route
   to `readySummary`.
6. If an incomplete draft exists, resume `onboarding` at its saved step.
7. Otherwise start `onboarding` at the intro.

The launch screen itself is the native, static iOS launch experience. A
SwiftUI launch-resolution view may continue displaying the same background and
mark briefly while session validation runs, avoiding a flash of the wrong
screen.

### New User Route

```text
Launch
→ Onboarding intro
→ Age
→ Height
→ Weight
→ Peptides
→ Other medications
→ Workout frequency
→ Goals
→ Apple Health explanation and permission
→ Notifications explanation and permission
→ You're ready summary
→ Future paywall bypass
→ Create account
→ Dashboard
```

The intro and ready summary include an "Already have an account? Sign in"
action. Using it changes the route to `authentication(.signIn)` without
destroying the draft.

The ready summary's primary action is "Go to my dashboard." In this phase it
advances to account creation because authentication is required before the
dashboard. The authentication screen should make that requirement clear
without implying the account already exists.

### Returning User Route

- Authenticated returning user: launch to dashboard.
- Known account, signed out: launch to sign-in.
- Logout: sign-in, never onboarding.
- Reinstall or new device: onboarding is shown because device-local account
  history is unavailable; the visible sign-in action provides the escape.

## Onboarding Experience

### Intro

Match the Figma "Let's make peppy yours" screen. Explain the three benefits:
understand a baseline, track a protocol, and connect changes over time.

Primary action: `Continue`.

Secondary text action: `Already have an account? Sign in`.

### Questionnaire

The seven-step progress indicator covers:

1. Age
2. Height
3. Current weight
4. Peptides currently taken
5. Other medications
6. Workout frequency
7. Goals

All questionnaire steps are skippable. Back navigation preserves answers.
Continue validates only values that were entered. Skipping records no value,
not a fabricated default.

Age is stored as an integer in years. Height is displayed in feet/inches or
centimeters and normalized to centimeters. Weight is displayed in pounds or
kilograms and normalized to kilograms. The draft retains the selected display
units for later presentation.

Peptides use searchable multi-select suggestions based on Peppy's existing
peptide catalog, with removable selected chips. Freeform text is allowed only
when no catalog match is appropriate, so emerging or uncommon peptides do not
block onboarding.

Other medications are optional free text with the Figma safety copy explaining
that the value provides context and does not replace professional medical
advice.

Workout frequency supports 0 through 7 days per week.

Goals are multi-select:

- Track my protocols
- Understand my body better
- Build consistent habits
- See what's actually working
- Optimize recovery
- Feel more in control

An optional free-text goal is also supported.

### Apple Health

The explanatory screen appears before the native prompt. It states what Peppy
wants to read and that Peppy does not write health data in this phase.

Request read access only for the Figma categories supported by HealthKit:

- Sleep analysis
- Heart rate variability
- Resting heart rate
- Step count
- Active energy burned
- Body mass
- Workouts

Authorization is optional. The user can continue after denial, restriction,
unavailability, or selecting "Not now." The draft records the user's
onboarding choice and the service-reported authorization outcome without
claiming that individual read types were granted when HealthKit does not expose
that distinction.

### Notifications

The explanatory screen appears before the native notification prompt. It
describes dose reminders, daily check-in reminders, and important insights.

Authorization is optional. Denial or "Not now" never blocks progress.
Registering a remote push token and saving server preferences occur only after
authentication and are documented as backend follow-up work. Phase one stores
the local authorization result.

### Ready Summary

Match the Figma "You're ready" screen and summarize only information actually
provided or permissions actually connected. Do not show invented protocol,
check-in, or connected-source data.

The screen can include:

- Baseline details supplied by the user.
- Selected peptides and medications.
- Workout frequency and goals.
- Apple Health connection status.
- Notification status.

Primary action: `Go to my dashboard`, which advances to registration through
the future-paywall bypass.

Secondary action: `Already have an account? Sign in`.

## Local Data and Persistence

### Onboarding Draft

`OnboardingDraft` is `Codable`, versioned, and contains:

- Schema version.
- Current onboarding step.
- Completion status.
- Age.
- Normalized height and preferred height unit.
- Normalized weight and preferred weight unit.
- Selected peptides.
- Other medications.
- Workout days per week.
- Selected goals and optional custom goal.
- Apple Health onboarding choice and authorization outcome.
- Notification onboarding choice and authorization outcome.
- Creation and last-updated timestamps.

The draft is saved after every meaningful answer and route advance. Writes are
atomic from the caller's perspective.

### Storage Boundaries

`OnboardingStoreProtocol` exposes:

- Load and save the anonymous draft.
- Clear the anonymous draft.
- Associate the draft with a user ID after authentication.
- Load a user-associated profile draft.
- Read and write device account-history metadata.
- Reset only onboarding data for tests.

The implementation uses `UserDefaults` with encoded `Data` because the draft is
small structured preference data. Authentication credentials remain exclusively
in `KeychainService`.

User-associated drafts are keyed by stable backend user ID, not email. After
successful registration or sign-in:

1. Fetch `/auth/me`.
2. Copy or move the anonymous completed draft to the user ID.
3. Mark the device as having a known account.
4. Preserve the user draft for personalization.
5. Clear only the anonymous copy after association succeeds.

If registration or sign-in fails, the anonymous draft remains intact.

Malformed or unsupported stored data is quarantined by clearing that one draft
and starting a fresh onboarding flow. It must not crash app launch or clear
Keychain credentials.

## Dependency Boundaries

Extend the existing `Dependencies` environment with:

- `AppFlowCoordinator`
- `OnboardingStoreProtocol`
- `HealthKitServiceProtocol`
- `NotificationPermissionServiceProtocol`

Live dependencies use system frameworks and local persistence. Mock
dependencies provide deterministic authorization states and in-memory
persistence for previews and tests.

Networking remains behind `APIClientProtocol`. No onboarding screen calls the
backend directly.

## Authentication Handoff

Existing registration and sign-in remain the network boundary. Their success
paths change to notify the coordinator rather than independently deciding the
root screen.

Registration collects the existing account fields. The completed onboarding
draft is not sent in the current `/auth/register` payload because the backend
does not support it.

On successful registration:

1. Save access and refresh tokens.
2. Fetch `/auth/me`.
3. Associate the anonymous draft to the returned user ID.
4. Mark the account as known on this device.
5. Set authenticated app state.
6. Route to dashboard.

Sign-in follows the same association rules. This preserves an onboarding draft
when a user initially chose onboarding but later signs into an existing
account. Future server sync decides whether local or remote profile data wins.

## Error Handling

- Session validation failure caused by invalid credentials clears credentials
  and continues through signed-out routing.
- Temporary session-validation network failure must not incorrectly erase
  credentials. Show a retryable launch error or use an established offline
  authenticated policy when one exists; phase one should prefer explicit retry
  over exposing signed-out screens.
- Registration and sign-in errors stay on the current form, use the existing
  toast system, and preserve the draft.
- HealthKit unavailable, denied, restricted, or errored shows an actionable but
  non-blocking status.
- Notification permission denied or errored shows a non-blocking status.
- Local persistence errors preserve the in-memory draft for the current
  session and show an unobtrusive retry message when progress may not survive
  termination.
- Inputs reject impossible entered values while retaining a visible Skip
  action.

## Accessibility and Motion

- Every icon-only button has an accessibility label.
- Progress announces "Step X of 7" and the step title.
- Picker controls expose their values and increment/decrement actions.
- Selected pills expose selected state.
- Text supports Dynamic Type without clipping; scrolling is enabled where
  required.
- Keyboard focus and submission behavior match the field sequence.
- Screen transitions use subtle forward/back movement and opacity. Reduce
  Motion replaces movement with a short dissolve.
- Color is never the only indication of selection, progress, permission state,
  validation, or errors.

## App Icon and Launch Screen

Create a full-resolution 1024x1024 app icon from the supplied P logo source,
centered with App Store-safe optical padding and an opaque background matching
the approved Figma presentation. Do not upscale the existing 81x90 raster as
the final source if a higher-resolution Figma asset can be exported.

The native launch screen uses the P mark centered on Peppy's warm background.
It contains no animation or loading text. The first SwiftUI launch-resolution
frame visually matches it.

## Backend Handoff

Create `BACKEND.md` in the iOS workspace. It must document, without changing
backend code:

- Proposed user profile/onboarding schema and normalized units.
- `GET`, `PUT`, and `PATCH` profile/onboarding endpoints.
- Idempotent anonymous-draft attachment after registration/sign-in.
- Profile versioning and local-to-server migration.
- Conflict resolution and `updated_at` semantics.
- Personalization consumers for dashboard, check-ins, protocols, insights, and
  reminders.
- Apple Health provenance, sync cursor, sample deduplication, and deletion.
- Notification device-token registration and preference sync.
- Field-level privacy, export, deletion, consent, and audit requirements.
- Server validation ranges and enumerations.
- Empty, partial, and skipped-answer behavior.
- Cross-device restore and account logout/deletion behavior.
- Recommended request/response examples and error codes.

The document distinguishes MVP-required backend work from later enhancements.

## Testing

### Unit Tests

- Every launch-resolution branch.
- Invalid-session versus temporary-network-failure behavior.
- New, incomplete, completed, and malformed drafts.
- Draft save/resume and normalization conversions.
- Skipped values remaining absent.
- Registration and sign-in association to user ID.
- Logout routing to sign-in.
- Known-account routing after relaunch.
- HealthKit unavailable, denied, and authorized outcomes.
- Notification denied and authorized outcomes.
- Future-paywall bypass.

### UI and Simulator Verification

- Fresh install completes the entire flow.
- Force-quit at each onboarding step resumes correctly.
- Back and Skip behavior preserves expected data.
- Sign-in escape works from intro and ready summary.
- Registration failure and retry preserve onboarding.
- Authenticated relaunch skips onboarding.
- Logout and relaunch go to sign-in.
- Permission denial never blocks completion.
- Dynamic Type, VoiceOver labels, keyboard presentation, and small-screen
  scrolling remain usable.

### Visual QA

Capture every implemented state at the Figma reference viewport where
practical. Compare source and simulator images side by side, then correct:

- Element position and dimensions.
- Spacing and safe-area behavior.
- Typography size, weight, line height, and accent styling.
- Colors, borders, shadows, and radii.
- Logo and icon sizing.
- Selected, disabled, error, and permission states.

## Acceptance Criteria

- The app starts with the P launch screen and never flashes an incorrect route.
- New users complete the full Figma onboarding before seeing authentication.
- The ready summary appears before account creation/sign-in.
- Existing authenticated users enter the app directly.
- Known signed-out users see sign-in rather than onboarding.
- Answers survive interruption and associate with the authenticated user.
- HealthKit and notification permissions are real, optional native requests.
- Permission denial and network errors do not destroy onboarding progress.
- The app icon is a production-quality P logo asset.
- UI is visually close to Figma while remaining accessible.
- `BACKEND.md` fully describes the deferred server integration.
- The required Xcode build passes and the key flow is verified in Simulator
  when a runtime is available.
