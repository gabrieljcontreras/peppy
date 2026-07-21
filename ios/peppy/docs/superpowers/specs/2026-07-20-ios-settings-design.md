# Peppy iOS Settings Design

**Date:** 2026-07-20
**Status:** Approved by Gabriel during the 2026-07-20 brainstorming session
**Architecture:** Hybrid account-backed settings

## Objective

Replace the placeholder More tab with Peppy's release-ready account and app
settings experience. The shipped slice must match the approved newest Figma
frames, persist account-owned settings on the backend, keep device-owned
capabilities on iOS, and provide complete privacy, export, security, support,
logout, and account-deletion workflows suitable for App Store review.

The release should feel complete for the data Peppy actually supports today.
Rows for unavailable systems are omitted instead of appearing as disabled or
nonfunctional promises.

## Source Context

- **PRD:** `docs/adr/PRD-001-peppy-mvp.md`.
- **Visual source of truth:** `/Users/gabri/Downloads/Peppy IOS (2).fig`, the
  newest supplied Figma export (exported 2026-06-12 at 03:10 UTC).
- **Approved frames:** More, Profile, Notifications, Data Export, Security &
  Privacy, and Help & About.
- **Current iOS state:** `MainTabView` renders a placeholder for the More tab.
  The app already uses SwiftUI, `Dependencies`, `APIClientProtocol`,
  `MockAPIClient`, `AppFlowCoordinator`, and `KeychainService`.
- **Current backend state:** profile onboarding GET/PUT/PATCH, notification
  preference GET/PATCH, APNs device registration routes, authentication,
  protocols, dose logs, check-ins, and insights already exist. Password change,
  account deletion, export, auth-version invalidation, reminder schedule fields,
  and a production APNs adapter do not.
- **Current web state:** About, Contact, bug report, feature request, Privacy,
  and Terms routes exist. A searchable Help Center route does not.

## Locked Product Decisions

| Area | Decision |
|---|---|
| Scope | Ship Profile, Notifications, Data Export, Security & Privacy, Help/About/Legal, logout, and permanent account deletion. |
| Deferred rows | Omit Labs, Connected Data, and Timeline from More. Omit Active Sessions and Data Permissions from Security. |
| Profile | Full name and profile preferences are editable. Email is visible and read-only. |
| Profile model | Add baseline date plus ordered primary goal, optional secondary goal, and optional focus area alongside height, weight, and unit preferences. |
| Notifications | Account-backed preferences with local iOS scheduling for dose and daily check-in reminders and server push for insights. |
| Reminder setup | Enabling dose or check-in reminders opens a setup sheet before requesting system permission. |
| Notification privacy | Generic content by default. Detailed lock-screen content requires an explicit opt-in offered after notification authorization. |
| Quiet hours | Suppress daily check-ins and routine insights. Dose reminders and alert-level insights still deliver. |
| Export | Export only available data. Account/profile/preferences are always included; Protocols and dose logs, Check-ins, and Insights are selectable. |
| Export formats | PDF summary or a ZIP containing separate CSV files, while retaining the Figma label `CSV data`. |
| Export delivery | Generate and stream immediately over the authenticated request, share through iOS, retain no server-side export artifact or history. |
| App lock | Optional Face ID on cold launch and after five minutes in the background. It never requires a password merely because Peppy was closed. |
| Password change | Require the current password, rotate the account auth version, invalidate all access and refresh tokens, then require sign-in. |
| Account deletion | Require password reauthentication and a separate irreversible confirmation, then permanently delete the account and associated data. |
| Active sessions | Omitted for this release; retain as a future security requirement. |
| Help/legal | Web-backed through `get-peppy.com`, with a native medical disclaimer and native version/build display. |
| Help Center | Add `https://get-peppy.com/help` with searchable, categorized FAQs. |
| AI disclosure | Disclose a third-party AI processing service and its data use without naming the provider. |
| HIPAA wording | Peppy may describe underlying services as supporting HIPAA-eligible configurations when factually verified, but must not claim Peppy is HIPAA compliant or has BAAs. |

## Product Principles

1. **Only real capabilities appear.** Every visible row navigates to a working
   destination with loading, success, empty, and failure behavior where needed.
2. **Account settings follow the user.** Profile and notification configuration
   are stored server-side and cached locally for fast presentation.
3. **Device effects remain device-owned.** Face ID, local notification requests,
   protected temporary files, sharing, and browser presentation stay behind
   injectable iOS services.
4. **Sensitive data is private by default.** Notification content is generic,
   exports are transient, and health content is excluded from logs and telemetry.
5. **Destructive actions are explicit and truthful.** Password rotation and
   account deletion provide clear consequences and do not report success before
   the server has completed the operation.
6. **The Figma is the visual contract.** Existing Peppy tokens and components
   implement the supplied frame instead of introducing a parallel design system.

## Scope

### Included

- More tab root and all approved release destinations.
- Cached account/profile presentation with server refresh.
- Editable full name, units, baseline values, and ordered goals.
- Account-backed notification preferences and reminder schedules.
- Local dose/check-in reminder scheduling and APNs insight delivery.
- Privacy-safe and explicitly opted-in detailed notification content.
- Immediate PDF and CSV ZIP export of available account data.
- Optional Face ID app lock.
- Password change with sign-out everywhere.
- Immediate account deletion from active systems and local storage.
- Web-backed support, Help Center, About, Terms, and Privacy experiences.
- Native medical disclaimer and dynamic version/build information.
- Privacy-policy corrections covering AI processing and accurate security claims.
- Backend, iOS, web, accessibility, visual, and security-focused tests.

### Excluded From This Release

- Labs, Connected Data, and Timeline entry points.
- HealthKit or wearable permission management.
- Active-session listing or individual remote-session revocation.
- Email-address changes.
- Export email delivery, export history, or retained export files.
- Fully server-scheduled dose and check-in reminders.
- Custom notification copy beyond the generic/detailed privacy choice.
- A HIPAA compliance claim, BAA claim, or legal compliance certification.

### Preserved Future Requirements

- Add Labs, Timeline, Connected Data, and Data Permissions when their complete
  systems ship.
- Add account session inventory and per-session revocation.
- Move dose and check-in delivery to server push using the same account-backed
  schedule model introduced here.
- Add a verified email-change flow with confirmation and security notification.

## Navigation And Visual Contract

The More tab becomes a `NavigationStack` rooted at the approved More frame. The
bottom tab bar remains visible on the root and detail frames, matching the
references. A standard Peppy back control returns to More without changing the
selected tab.

The root order is:

1. Peppy header and profile summary card showing full name and read-only email.
2. **My data:** Notifications, Data Export.
3. **Account & app:** Security, Help and Support, About Peppy, Legal.
4. Dynamic app version/build and Log Out.

Labs, Connected Data, and Timeline are removed from the My Data group for this
release. The remaining rows close naturally without placeholder gaps.

Destination behavior:

- Profile summary -> native Profile frame.
- Notifications -> native Notifications frame.
- Data Export -> native Data Export frame.
- Security -> native Security & Privacy frame.
- Help and Support -> native Help & About frame at its top.
- About Peppy -> `https://get-peppy.com/about` in an in-app browser.
- Legal -> native Help & About frame positioned at Important Information, where
  Terms and Privacy are separate rows.
- Log Out -> confirmation, APNs token unregister attempt, local credential and
  account-cache removal, then normal sign-in. A failed unregister must not trap
  the user in the signed-in state.

All screens reuse the existing Peppy color, typography, spacing, control, icon,
and card tokens. Implementation is checked against the approved 853 x 1844
reference rasters at the corresponding iPhone viewport. Accessibility layouts
may reflow for Dynamic Type instead of clipping to the static raster.

## Profile

The Profile screen matches the Figma grouping: Account Information,
Preferences, Baseline Information, Onboarding Goals, Save Changes, and the
account-security footer.

### Fields And Interactions

- **Full name:** editable through the Figma edit affordance, trimmed, maximum
  100 characters, and persisted as `users.display_name`.
- **Email:** visible and explicitly read-only. The Figma email Edit affordance
  is omitted so Peppy does not imply an unsupported flow.
- **Preferred weight unit:** inline `lb` / `kg` segmented control.
- **Preferred height unit:** inline `ft / in` / `cm` segmented control.
- **Baseline date:** editable date-only value that cannot be in the future.
- **Baseline weight:** editable, displayed in the selected unit, persisted in
  canonical kilograms.
- **Baseline height:** editable, displayed in the selected unit, persisted in
  canonical centimeters.
- **Primary goal:** required and selected from the canonical onboarding options.
- **Secondary goal:** optional, including an explicit None choice.
- **Focus area:** optional and selected from the canonical onboarding options.

The goal vocabulary is shared with onboarding rather than duplicated as new
Settings-only strings. Existing unordered `goals` data is migrated without loss:
the first supported item seeds primary, the second seeds secondary, and remaining
legacy/custom data stays preserved until explicitly replaced by the user.

### Save Behavior

The screen presents cached data immediately and refreshes from the backend.
Editing occurs in a staged draft. Save Changes is enabled only when the draft is
valid and differs from the last server-confirmed state.

Saving updates display name and profile data as one user-visible operation. If
one server mutation fails, the screen keeps the complete draft, reports the
failure inline, and allows retry; it does not present a false fully-saved state.
Successful responses replace the account/profile cache. Navigating away with
unsaved changes requires discard confirmation.

## Notifications

The Notifications screen retains the Figma sections and order:

1. Reminder Notifications: Dose Reminders and Daily Check-in Reminders.
2. Insights & Updates: Insights and Alert-level Insights Only.
3. Quiet Hours: start and end.
4. Notification Preview.
5. Save Changes.

### Permission And Privacy Flow

Peppy does not request notification authorization when the screen appears.
Enabling a reminder first opens its setup sheet. The system permission prompt
appears only after the user confirms a valid schedule.

Notification bodies are generic by default, for example `You have a Peppy
reminder` or `A new Peppy insight is ready`. After system authorization succeeds,
the setup flow offers **Show reminder details**. This is a separate explicit
choice and remains off unless selected. When enabled, a notification may include
the compound, dose, scheduled time, or insight category. The Figma preview card
updates to show the currently selected privacy level.

If system permission is denied, the account configuration remains saved. The
screen shows that notifications are disabled at the iOS level and provides an
Open iOS Settings action. Returning from Settings triggers authorization-state
reconciliation and schedule creation when permission becomes available.

### Dose Reminder Setup

Enabling Dose Reminders opens a sheet listing compounds from the active protocol.
Recurrence is derived from each compound's protocol start date and frequency; the
user selects a local delivery time for each compound. The master toggle and
per-compound times are saved to the account. Turning the master toggle off retains
those times for later re-enablement.

With no active protocol, the sheet explains that dose reminders require an active
protocol and offers navigation to Protocols; it cannot save an empty enabled
state.

iOS schedules a rolling horizon of dose notifications within
`UNUserNotificationCenter`'s pending-request limit and reserves capacity for the
daily check-in reminder. Schedules reconcile after Save, active-protocol changes,
app activation, significant time changes, and timezone changes.

### Daily Check-in Setup

Enabling Daily Check-in Reminders opens a sheet with one preferred local time.
The account stores the enabled state and time. iOS owns the repeating local
notification request.

### Insights And Quiet Hours

Insights use the existing device registration and notification-preference routes.
The production APNs adapter must be implemented; the current adapter is a
placeholder. Alert-level Insights Only is available only while Insights is on.

Quiet hours are interpreted in the user's current IANA timezone and support
overnight ranges. Daily check-ins and routine insights are suppressed within the
range. Dose reminders and alert-severity insights bypass quiet hours. The device
updates the account timezone when necessary so server-side decisions do not use
the server's local clock.

### Save Ordering

Save Changes first persists the account-backed configuration. Only a successful
response replaces local notification requests and the cache. A local scheduling
failure leaves the account preference intact, surfaces a repair action, and is
retried during the next reconciliation.

## Data Export

The Data Export screen matches the Figma's three-step presentation and sensitive
information warning.

### Contents

Account identity metadata, profile fields, and preferences are always included
and identified in the export manifest. Users may independently include:

- Protocols, compound details, and dose logs.
- Check-ins, symptoms, and notes.
- Insights and their actions/explanations.

Labs and Wearable Data are omitted from the UI until those data sources ship.
Available categories begin selected. Deselecting every category remains valid and
creates an account/profile/preferences-only export.

### Formats

- **PDF Summary:** human-readable account and health summary with selected
  records, relevant tables, and charts only where the source data exists.
- **CSV Data:** preserves the Figma label and returns a ZIP with a manifest plus
  separate UTF-8 CSV files for each included data type.

Date choices are All Time, Last 30 Days, Last 90 Days, and Custom Range. The
range applies to time-based records only. A custom start must not be after its
end, and future dates are rejected.

### Delivery And Cleanup

Create Export sends one authenticated request containing the selection, format,
and date range. The backend enforces user ownership on every query and streams
the result immediately. It creates no durable export row, object-storage file,
email attachment, download URL, or export history. Request-lifetime temporary
bytes are permitted only when required to construct PDF or ZIP output and must
be removed before request cleanup.

iOS writes the response to a uniquely named temporary file using complete file
protection and excludes it from backup. It then presents the native share sheet.
The file is removed when sharing completes or is cancelled, and stale Peppy
export files are cleaned on launch after an interrupted prior attempt.

The action shows progress without navigating away. Cancellation removes partial
data. Recoverable failures preserve the user's selections and provide retry.

## Security And Privacy

The Security & Privacy screen retains Account Security, Privacy & Data, Danger
Zone, and the Help Center link. Active Sessions is omitted. Data Permissions is
omitted until Connected Data ships.

### Persistent Session And Face ID

Peppy continues to store the authenticated session in Keychain and silently
refresh it through the existing launch flow. Closing or briefly backgrounding the
app never requires password entry.

Face ID is opt-in and device-local:

- Enabling it performs a biometric capability/authentication check before the
  setting is accepted.
- It gates sensitive app content on cold launch and after at least five minutes
  continuously in the background.
- Returning sooner than five minutes does not prompt again.
- Peppy obscures the app-switcher snapshot immediately on background entry even
  when the five-minute lock threshold has not elapsed.
- Failed or cancelled authentication leaves the privacy cover in place.
- **Use Password Instead** does not implement a second local password prompt. It
  clears the saved session and opens the normal Peppy sign-in flow.
- If Face ID is unavailable or unenrolled, the toggle remains off and the user
  receives an actionable system-settings explanation.

Face ID does not replace server authentication and does not change token expiry,
refresh, password-change, or revocation rules.

### Change Password

The flow collects current password, new password, and confirmation. The server
verifies the current password, validates the replacement, stores its secure hash,
increments `users.auth_version`, and commits atomically.

Access and refresh tokens carry the account auth version. Protected requests and
refresh operations reject a token whose version differs from the current user.
After a successful password change, iOS clears tokens and account caches and
returns to sign-in. This signs out every device, including the initiating device.

### Delete Account

Delete Account uses two deliberate steps:

1. Reauthenticate with the account password and explain exactly what is removed.
2. Present a separate destructive confirmation labelled Delete Permanently.

The backend deletes the user and all associated rows in one controlled operation,
including profile, protocols, compounds, dose logs, check-ins, labs if present,
insights and weekly summaries, wearable connections and tokens, jobs, notification
preferences, device tokens, and any other user-owned record discovered by the
required deletion inventory. A failure rolls back and leaves the signed-in account
intact. The success response is returned only after active-system deletion
commits. iOS then clears Keychain credentials, caches, local reminder requests,
temporary exports, and device settings before showing sign-in.

The release cannot promise immediate deletion from backups or third-party
retention unless production infrastructure can perform it. Backup and AI-service
retention must be verified before release; any unavoidable retention must be
accurately disclosed with a concrete duration. The UI must not contradict that
policy.

### Privacy And Public Claims

Privacy Policy opens `https://get-peppy.com/privacy`. How We Protect Your Data
opens the security section of that page. The website and native privacy card must
use claims that are supported by production configuration and contracts.

The policy discloses that relevant health and wellness data, including free-text
notes when applicable, may be processed by a third-party AI service to generate
personalized insights. It describes the categories sent, purpose, identifier
handling, retention, deletion, training use, and user controls according to the
actual production agreement. Public copy does not name the AI provider.

Permitted infrastructure wording, after factual verification, is:

> Peppy uses cloud infrastructure services that support HIPAA-eligible
> configurations.

The surrounding policy must make clear that this is not a claim that Peppy is
HIPAA compliant and must not claim Peppy has BAAs while none exist.

Health data, notification details, passwords, auth tokens, export contents, and
AI inputs are excluded from analytics events, crash breadcrumbs, and application
logs. Operational logging uses opaque record and request identifiers.

## Help, About, And Legal

The native Help & About screen matches the approved frame:

- Search Help -> `https://get-peppy.com/help`.
- Contact Support -> `https://get-peppy.com/contact`.
- Report a Problem -> `https://get-peppy.com/feedback/bug`.
- Feature Request -> `https://get-peppy.com/feedback/feature`.
- Medical Disclaimer -> native detail or sheet.
- Terms of Service -> `https://get-peppy.com/terms`.
- Privacy Policy -> `https://get-peppy.com/privacy`.
- Dynamic app version/build, current copyright year, and Peppy product footer.

Web destinations open in an allow-listed in-app browser with normal browser
controls. A load failure leaves the user in Peppy and offers Retry and Open in
Safari. No visible row may terminate at an unimplemented placeholder.

The new Help Center provides client-side or server-backed search across
categorized FAQs covering accounts, protocols and doses, check-ins, insights,
notifications, exports and privacy, and troubleshooting. It uses the existing
Peppy website visual system and remains useful on mobile without requiring app
authentication.

The native medical disclaimer is informational and requires no acceptance:

> Peppy provides informational health tracking and AI-assisted insights. It does
> not diagnose, treat, prevent, or cure any condition and is not a substitute for
> professional medical advice. Consult a qualified healthcare professional before
> starting, stopping, or changing a peptide, medication, or treatment. Contact
> local emergency services for urgent help.

## Architecture

### Backend Authority

The backend is authoritative for identity/profile data, notification preferences
and reminder configuration, export contents, password rotation, and deletion.
Existing services and routes are extended rather than replaced.

Intended API surface:

```text
GET    /api/v1/auth/me
PATCH  /api/v1/auth/me                    # display_name and device-derived timezone
POST   /api/v1/auth/change-password
DELETE /api/v1/auth/account

GET    /api/v1/profile/onboarding
PATCH  /api/v1/profile/onboarding         # units, baseline, ordered goals

GET    /api/v1/notifications/preferences
PATCH  /api/v1/notifications/preferences  # insights, reminders, quiet hours,
                                          # details, dose schedules
POST   /api/v1/notifications/devices       # existing; wire from iOS
DELETE /api/v1/notifications/devices/{id}  # existing

POST   /api/v1/profile/export              # streamed PDF or CSV ZIP
```

Request and response schema names may follow existing local conventions, but the
resource ownership and behavior above are contract requirements.

Required schema changes include:

- `users.auth_version`, non-null with a server default suitable for existing
  accounts.
- `onboarding_profiles.baseline_date`, `primary_goal`, `secondary_goal`, and
  `focus_area`, with additive migration and legacy-goal preservation.
- Notification preference fields for dose reminders, daily check-in reminders,
  daily check-in time, and detailed previews. Server quiet-hour calculations use
  the existing `users.timezone` field rather than duplicating timezone state.
- A normalized per-compound dose reminder configuration keyed to user and
  protocol compound, retaining local time while deriving recurrence from the
  protocol.

The existing device-token model and routes are reused. APNs credential loading,
HTTP/2 delivery, invalid-token cleanup, sandbox/production environment selection,
and bounded retries must replace the placeholder APNs adapter before insight push
is considered shipped.

### iOS Boundaries

Settings code lives under `Features/Settings` and follows existing feature,
ViewModel, store, and dependency patterns. Suggested focused responsibilities:

- `SettingsStore`: cached account/profile and notification state plus refresh and
  successful-mutation reconciliation.
- Profile and Notification ViewModels: staged drafts, validation, save intent,
  and presentation state.
- `AppLockService`: LocalAuthentication capability and authentication.
- `AppLockCoordinator`: lifecycle timestamps and privacy-cover state.
- `LocalNotificationScheduling`: permission state and idempotent schedule
  reconciliation.
- `ExportDownloading`: authenticated streamed download, protected file handling,
  cancellation, and cleanup.
- `InAppBrowsing`: allow-listed web presentation.

All network access remains behind `APIClientProtocol`; all new endpoints and
models are supported by `MockAPIClient`. Concrete device services are added to
`Dependencies` with deterministic mocks for previews and tests. Views do not
call Keychain, LocalAuthentication, `UNUserNotificationCenter`, URLSession file
APIs, or browser controllers directly.

### Cached-First Data Flow

```text
Open Settings destination
    -> render last confirmed account cache when present
    -> refresh through store/APIClientProtocol
    -> reconcile server response
    -> preserve valid cached content if refresh fails

Edit and Save
    -> validate staged draft
    -> submit account mutation
    -> reconcile confirmed server response
    -> perform device-side effect when required
    -> update visible cache and announce result
```

An authentication failure routes through the existing coordinator and clears
sensitive cached state. Network failures never silently discard a user's staged
form. Destructive operations do not use optimistic success.

## Error Handling And Edge Cases

- Profile not yet attached: create/attach the minimal profile record from current
  account/onboarding cache before saving, without erasing unrelated onboarding
  fields.
- Partial profile save: retain the entire staged draft and identify the failed
  operation; retry is idempotent.
- Notification permission denied: retain account settings, show system status,
  and provide Open iOS Settings.
- Notification scheduling failure: preserve server preferences, show repair
  state, and retry during lifecycle reconciliation.
- Protocol changed or deactivated: remove obsolete local requests and reconcile
  surviving compound schedules by stable compound identifier.
- Timezone or daylight-saving change: recompute future local requests without
  duplicating notifications.
- APNs invalid token: remove the device token and do not retry it indefinitely.
- Export has sparse data: include manifest and metadata, omit empty optional
  tables/charts, and never fabricate records.
- Export interruption: delete partial files and keep the screen ready to retry.
- Face ID unavailable or cancelled: do not enable or bypass the lock.
- Password-change failure: retain the current authenticated session and show the
  server validation error without logging sensitive input.
- Account-deletion failure: keep the account and local session intact; never show
  a deletion success state after rollback.
- Web destination unavailable: retain native navigation context and offer Retry
  or Open in Safari.

## Accessibility

- Every row, toggle, segmented control, time picker, icon button, and destructive
  action has an explicit accessibility label, value, hint where necessary, and a
  minimum 44 x 44 point target.
- Dynamic Type reflows cards and rows without clipping, overlap, or horizontal
  scrolling for primary content.
- Color never communicates toggle, severity, error, or selection state alone.
- Save, export, authentication, and deletion results are announced through
  VoiceOver.
- Sheets provide a clear title, dismissal control, keyboard handling, and focus
  restoration to the invoking control.
- Reduce Motion is respected by loading, progress, and lock-cover transitions.

## Testing And Verification

### Backend

- Migration upgrade/downgrade coverage and preservation of existing profiles and
  goal data.
- Profile validation, unit normalization, display-name authorization, and user
  ownership.
- Notification preference validation, overnight quiet hours, timezone handling,
  alert bypass, and dose configuration ownership.
- APNs adapter success, provider error mapping, invalid-token cleanup, generic vs
  detailed payloads, and no sensitive payload logging.
- Auth-version enforcement for access and refresh tokens, including immediate
  invalidation on password change.
- Deletion inventory and cascade tests proving every user-owned model is removed
  and rollback leaves all data intact on injected failure.
- Export authorization, date/category filtering, PDF/CSV contents, CSV injection
  protection, manifest accuracy, cancellation cleanup, and absence of durable
  export artifacts.

### iOS

- Store cached-first loading, refresh preservation, mutation reconciliation, and
  auth-failure cleanup using `MockAPIClient`.
- Profile draft validation, unit conversion, ordered goals, email read-only
  presentation, save success/failure, and discard confirmation.
- Notification permission transitions, setup-sheet gating, privacy mode, quiet
  hours, stable identifiers, rolling-horizon limits, timezone reconciliation,
  and protocol-change cleanup with mocked scheduling.
- App lock cold launch, less-than-five-minute resume, five-minute resume,
  cancellation, unavailable biometrics, privacy cover, and sign-in fallback.
- Export progress, cancellation, file protection attributes, share completion,
  stale-file cleanup, and error retention.
- Password-change, logout, account-deletion, and coordinator transitions.
- Route coverage ensuring every visible More row reaches its intended destination.

### Web And Integrated QA

- Help search, category filtering, no-results state, responsive layout, keyboard
  access, and all support/legal links.
- Privacy copy reviewed against actual production infrastructure and AI-service
  handling before publication.
- Visual comparison of each iOS screen with its approved Figma raster at the same
  viewport, followed by fixes and a second comparison.
- Manual device verification for notification authorization, local dose/check-in
  delivery, APNs insight delivery, Face ID lifecycle behavior, native sharing,
  and account deletion followed by failed token reuse.
- VoiceOver, Dynamic Type, Reduce Motion, dark-environment contrast where
  applicable, and app-switcher privacy-cover checks.

## Release Gates

Settings is not release-ready until all of the following are true:

1. Production APNs credentials and delivery are verified on a physical device.
2. Account deletion removes every active-system record and backup/third-party
   retention is either compatible with the promise or disclosed accurately.
3. Privacy and security statements are supported by production configuration,
   vendor terms, and legal review; no HIPAA compliance or BAA claim is implied.
4. The AI-processing disclosure accurately describes actual data categories,
   retention, training use, and controls without naming the provider.
5. `get-peppy.com/help` and every support, About, Terms, and Privacy route are live
   and usable on mobile.
6. Export files are protected, transient, complete, and absent from server
   storage/history after request completion.
7. Every approved Settings row is functional, inaccessible future rows are
   omitted, automated tests pass, and visual/accessibility QA is complete.

## Success Criteria

A signed-in user can open More, understand their account state, update supported
profile and notification settings across devices, receive privacy-appropriate
reminders, securely export available data, optionally protect Peppy with Face ID,
change their password and invalidate every session, permanently delete their
account, and reach current help/legal information without encountering a
placeholder or misleading privacy claim.
