# iOS Settings Integrated Manual QA And Release Gates

Date: 2026-07-23

Evidence cutoff: 2026-07-23 22:08 EDT (-0400)

Branch/HEAD observed at cutoff: `feat/ios-settings` / `8b5e183654e4b740bde073afc10fab350eb81e63`

## Status Legend

- **PASS**: Fresh evidence completed the named gate.
- **FAIL**: Fresh evidence completed the gate and found a failure.
- **BLOCKED**: The gate could not be completed with the available environment or evidence.
- **FOUND**: Repository evidence exists, but it is not by itself a release pass.
- **MISSING**: Required real-world evidence was not found.

## Overall Release Verdict

**BLOCKED — not release-ready.**

Automated backend tests, web checks/build, an iPhone 17 Pro simulator test run,
and the unsigned generic iOS Release build completed successfully after scoped
test-maintenance fixes. Release remains blocked by:

1. The prescribed direct `.venv/bin/pytest -q` backend command failing before
   collection; the passing module-form invocation does not silently replace it.
2. The required repository-wide backend Ruff gate failing with 67 errors.
3. The required iPhone 16 Pro simulator destination being unavailable.
4. Missing authenticated simulator interaction, VoiceOver, Dynamic Type, and
   three exact-screen comparison captures.
5. All physical-device/APNs delivery/security gates lacking device evidence.
6. Missing production credential, encryption/transport, backup, AI-provider,
   vendor-contract, and legal-approval evidence.
7. The approved live Help Center URL returning HTTP 404 on a mobile request.

No physical-device, production, contract, legal, or accessibility pass is
inferred from source code or unit tests.

## Fresh Automated Command Evidence

All commands below were run on 2026-07-23 in
`/Users/gabri/peppy/.worktrees/ios-settings`.

| Status | Command | Exit | Fresh result |
|---|---|---:|---|
| FAIL | `cd backend && .venv/bin/pytest -q` | 4 | The virtualenv console script failed before collection with `ModuleNotFoundError: No module named 'app'`. The same virtualenv interpreter could import `app`; the module-form invocation below is the working equivalent. |
| PASS | `cd backend && .venv/bin/python -m pytest -q` | 0 | Initial run: 340 passed in 50.43s. Final run after adding two required security tests: **342 passed in 55.50s**. |
| FAIL | `cd backend && .venv/bin/ruff check app tests` | 1 | **67 errors**; 47 marked auto-fixable. Findings span broad pre-existing backend code (import ordering, unused imports, SQLAlchemy boolean comparisons, and test import issues). They were not masked or bulk-fixed in this settings verification task. |
| PASS | `cd backend && .venv/bin/ruff check tests/test_data_export.py tests/test_settings_profile.py` | 0 | The two test files changed by Task 16 pass focused lint. The configuration deprecation warning remains. |
| PASS | `cd web && /opt/homebrew/bin/npm run lint` | 0 | 0 errors, 1 warning in `src/components/Logo.tsx` for raw `<img>`. |
| PASS | `cd web && /opt/homebrew/bin/npm run type-check` | 0 | `tsc --noEmit` passed. |
| BLOCKED | `cd web && /opt/homebrew/bin/npm run build` (sandboxed) | 1 | Network access to three existing Google Fonts was unavailable. This was an environmental failure. |
| PASS | `cd web && /opt/homebrew/bin/npm run build` (network permitted) | 0 | Production build compiled, type-checked, and generated **18 routes**. Warnings: multiple-lockfile workspace-root inference and Node `module.register()` deprecation. |
| BLOCKED | `xcodebuild test ... -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` | 70 | No iPhone 16 Pro exists in the installed iOS 26.5 simulator runtime. Available phones are iPhone 17-family devices. |
| FAIL | Supplemental first run: `xcodebuild test ... -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | 65 | Result bundle reported 458 total: **453 passed, 5 failed, 0 skipped**. Five stale tests called the newly guarded logout path on an unauthenticated mock. |
| PASS | Focused serial rerun of the five corrected iOS tests | 0 | **5 passed, 0 failed**. |
| PASS | Supplemental final full run: `xcodebuild test ... -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | 0 | Result bundle: **458 passed, 0 failed, 0 skipped**, iPhone 17 Pro, iOS 26.5 (23F77). This does not convert the missing iPhone 16 Pro gate to PASS. |
| PASS | `xcodebuild ... -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` | 0 | `** BUILD SUCCEEDED **`. AppIntents metadata reported no AppIntents dependency/shortcuts; no build failure. |

### Scoped Failure Repair

The five iOS failures reproduced serially: 5 executed tests with 11 assertion
failures. Root cause was stale test setup after `AppFlowCoordinator.logout()`
was intentionally changed to no-op when there is no authenticated session.
Each affected test now authenticates its mock `AppState` before exercising
logout. No production behavior changed.

Affected tests:

- `CheckinViewModelTests.testLogoutInvalidatesDelayedListResponse()`
- `CheckinViewModelTests.testLogoutInvalidatesDelayedDetailResponse()`
- `CheckinViewModelTests.testLogoutInvalidatesDelayedCreateResponse()`
- `CheckinViewModelTests.testLogoutInvalidatesDelayedUpdateResponse()`
- `ProtocolNavigationTests.testSessionResetClearsCheckinPathAndReturnsCheckinTabToHome()`

## API Security Coverage

Fresh focused command:

```text
.venv/bin/python -m pytest -q \
  tests/test_settings_profile.py::test_profile_reads_are_isolated_between_two_accounts \
  tests/test_notification_settings.py::test_patch_preferences_rejects_foreign_compound_before_mutation \
  tests/test_data_export.py::test_csv_export_contains_manifest_and_only_selected_owned_data \
  tests/test_password_rotation.py::test_password_change_invalidates_old_access_and_refresh_tokens \
  tests/test_account_deletion.py::test_deletion_inventory_enumerates_every_user_owned_model \
  tests/test_account_deletion.py::test_delete_account_removes_complete_user_inventory \
  tests/test_data_export.py::test_csv_export_preserves_utf8_and_escapes_formula_leading_cells \
  tests/test_data_export.py::test_export_response_closes_temporary_stream_after_completion
```

Result: **PASS — 8 passed in 3.34s**.

| Security case | Status | Direct automated evidence |
|---|---|---|
| Two-account profile isolation | PASS | `backend/tests/test_settings_profile.py::test_profile_reads_are_isolated_between_two_accounts` creates two accounts, writes distinct profiles, and verifies each token reads only its own profile. Added because no existing test directly exercised two accounts. |
| Cross-user reminder access/mutation | PASS | `backend/tests/test_notification_settings.py::test_patch_preferences_rejects_foreign_compound_before_mutation` rejects a reminder for another user's compound and verifies the owned preference/reminder remains unchanged. |
| Cross-user export access | PASS | `backend/tests/test_data_export.py::test_csv_export_contains_manifest_and_only_selected_owned_data` seeds two accounts and asserts the second account's identifying data is absent from the authenticated archive. |
| Old tokens after password change | PASS | `backend/tests/test_password_rotation.py::test_password_change_invalidates_old_access_and_refresh_tokens` verifies old access and refresh tokens return 401 and replacement-version tokens work. |
| Deletion inventory is complete | PASS | `backend/tests/test_account_deletion.py::test_deletion_inventory_enumerates_every_user_owned_model` verifies the declared inventory matches every transitively user-owned SQLAlchemy model. |
| Deletion removes every inventoried row | PASS | `backend/tests/test_account_deletion.py::test_delete_account_removes_complete_user_inventory` starts with one row in every inventoried model and verifies every count becomes zero. |
| Deleted token fails | PASS | The same deletion test verifies the deleted account's original access token returns 401 from `/api/v1/auth/me`. |
| CSV formula execution prevention | PASS | `backend/tests/test_data_export.py::test_csv_export_preserves_utf8_and_escapes_formula_leading_cells` verifies cells beginning with `=`, `+`, `@`, and `-` receive a leading apostrophe. |
| No durable server export record | PASS | `backend/tests/test_data_export.py::test_pdf_export_is_valid_and_no_export_record_is_persisted` passed in the full suite and verifies no `exports` table/record is introduced. |
| Temporary stream cleanup after successful response | PASS | `backend/tests/test_data_export.py::test_export_response_closes_temporary_stream_after_completion` verifies the successful streaming response consumes and closes its temporary stream. Added because only failure-path closure had direct prior coverage. |
| Temporary stream cleanup after generation failure | PASS | `backend/tests/test_data_export.py::test_csv_generator_closes_temporary_stream_after_generation_failure` passed in the full suite. |

No passwords, tokens, health content, notification detail text, archive contents,
or AI inputs were logged in this QA record.

## Simulator Interaction And Accessibility Checklist

Available simulator evidence:

- `simctl list devices available`: iPhone 17 Pro (iOS 26.5) available; no iPhone
  16 Pro.
- Peppy was installed as `com.gabriel.peppy`.
- The iPhone 17 Pro was booted successfully.
- Fresh launch PID: `33069`.
- Fresh inspected screenshot:
  `/private/tmp/peppy-task16/01-launch.png`.
- The screenshot is a valid 1206 × 2622 launch capture showing the signed-out
  sign-in screen. It is not a Settings capture.

The environment had no supplied authenticated test account and no supported
simulator UI-driving/accessibility-inspection harness. The app stopped at the
sign-in wall, so the following gates are not claimed from unit tests:

| Interaction/accessibility gate | Status | Evidence or blocker |
|---|---|---|
| Every visible More row | BLOCKED | Authenticated Settings was inaccessible in the fresh simulator run. |
| Cached/offline/error/retry states | BLOCKED | No deterministic authenticated state launcher/UI harness. |
| Profile unit conversion and unsaved discard | BLOCKED | Automated model coverage exists, but live interaction was not performed. |
| Denied notification permission | BLOCKED | No live permission-state interaction. |
| Reminder setup | BLOCKED | No authenticated interaction. |
| Generic/detailed preview | BLOCKED | Automated behavior coverage exists; live screen state was not exercised. |
| Quiet hours | BLOCKED | Automated scheduling coverage exists; live UI was not exercised. |
| Export cancellation/share cleanup | BLOCKED | Backend and iOS service tests are supplementary; live share-sheet cancellation was not exercised. |
| Face ID mock states | BLOCKED | Unit tests are supplementary; no live simulator state walkthrough. |
| Password failure/success | BLOCKED | Automated API/view-model coverage is supplementary; no live UI walkthrough. |
| Deletion failure/success | BLOCKED | Automated API/view-model coverage is supplementary; no live UI walkthrough. |
| Support links | BLOCKED | No live native interaction; production URL status was checked separately below. |
| Default, AX3, and Accessibility Dynamic Type | BLOCKED | No authenticated screen capture or accessibility inspector. |
| VoiceOver focus order | BLOCKED | VoiceOver was not driven/observed. |
| 44-point tap targets | BLOCKED | Some measurable constants have automated coverage, but live hit testing was not performed. |

## Exact Visual Comparison

Controller-owned Task 16 design evidence is recorded in `design-qa.md`; this
Task 16 verification did not edit that file.

| Surface | Status | Reference | Implementation | Combined input |
|---|---|---|---|---|
| More | FOUND | `/Users/gabri/Downloads/more_page.png` | `/private/tmp/peppy-task9-settings-final.png` | `/private/tmp/peppy-task9-settings-comparison.png` |
| Profile | FOUND | `/Users/gabri/Downloads/profile_page.png` | `/private/tmp/peppy-profile-task10-final.png` | `/private/tmp/peppy-profile-task10-final-comparison.png` |
| Notifications | FOUND | `/Users/gabri/Downloads/notifications.png` | `/private/tmp/peppy-task11-notifications.png` | `/private/tmp/peppy-task11-comparison.png` |
| Data Export | BLOCKED | `/Users/gabri/Downloads/data_export.png` | Missing | Missing |
| Security & Privacy | BLOCKED | `/Users/gabri/Downloads/security_privacy_overview.png` | Missing | Missing |
| Help & About | BLOCKED | `/Users/gabri/Downloads/help_settings.png` | Missing | Missing |

The three found comparisons use 853 × 1844 references and normalized iPhone 17
Pro implementation captures. They support prior More/Profile/Notifications
comparison work, but they are not a fresh complete six-screen Task 16 pass.
Data Export, Security & Privacy, and Help & About cannot be assessed for header
position, spacing, type, icon size, radii, color, tab bar, safe areas, or text
fit without implementation captures. Overall visual gate: **BLOCKED**.

### Approved Intentional UI Differences

- Profile email is read-only; the Figma email-edit action is intentionally
  omitted.
- Future/unavailable More rows (Labs, Connected Data, Timeline) are intentionally
  omitted so the release has no dead destinations.
- Notification previews default to generic copy; detailed health/reminder content
  appears only after a separate opt-in.
- Native iPhone 17 Pro chrome, tab treatment, and closest SF Symbol silhouettes
  differ slightly from the source rasters.

## Physical-Device-Only Gates

No signed physical-device run, production APNs delivery trace, or device capture
was provided or generated.

| Gate | Status |
|---|---|
| APNs production registration and delivery | BLOCKED |
| Invalid APNs token cleanup against production | BLOCKED |
| Generic and opted-in detailed production payloads | BLOCKED |
| Dose/check-in delivery across timezone changes | BLOCKED |
| Face ID cold launch and five-minute resume | BLOCKED |
| Immediate app-switcher privacy cover | BLOCKED |
| Protected share-file cleanup on device | BLOCKED |
| Open iOS Settings behavior | BLOCKED |

## Operational And Legal Gates

| Gate | Status | Evidence |
|---|---|---|
| APNs production credentials/configuration | MISSING / BLOCKED | `backend/app/config.py` defines APNs environment fields and source code integrates APNs. No real production credential or deployed configuration evidence was available. The default `apns_use_sandbox = False` is not proof of a configured production connection. |
| Database/storage encryption at rest | FOUND (code only) / BLOCKED | `backend/app/config.py` rejects the default encryption key when `debug` is false, and `backend/app/security/encryption.py` implements Fernet encryption for sensitive tokens. No deployed database/storage encryption evidence was found. Do not claim AES-256. |
| Transport security | MISSING / BLOCKED | HTTPS URLs exist in clients, but no deployed TLS policy/certificate evidence was provided. Do not claim TLS 1.3. |
| Backup retention/deletion | MISSING / BLOCKED | Product copy acknowledges limited backup/provider retention, but no backup schedule, retention period, deletion SLA, or provider evidence was found. |
| Active-system deletion behavior | PASS (automated scope only) | The full deletion inventory test removes every inventoried application row and rejects the deleted token. This does not prove backup/provider deletion. |
| AI provider retention/training terms | MISSING / BLOCKED | Source names Anthropic models and privacy copy describes third-party processing. No executed vendor terms, zero-retention setting, or training-use evidence was found. |
| Vendor contracts / BAAs | MISSING / BLOCKED | ADR/PRD text describes intended HIPAA-capable infrastructure, but no executed vendor contract or BAA evidence was found. |
| Legal approval of privacy/terms/support copy | MISSING / BLOCKED | No counsel approval or dated sign-off was found. |
| Production live URLs with mobile user agent | FAIL | `/contact`, `/feedback/bug`, `/feedback/feature`, `/terms`, and `/privacy` returned 200. `https://get-peppy.com/help` returned **404**. |

Repository planning documents that mention HIPAA-capable infrastructure, BAAs,
AES-256, or TLS 1.3 are future-state design statements and are not accepted as
production evidence. Public copy must not be strengthened to claim HIPAA
compliance, BAAs, AES-256, TLS 1.3, guaranteed backup deletion, or unsupported
AI retention/training behavior.

## Remaining Release Blockers

1. Repair the backend virtualenv console-script invocation so
   `cd backend && .venv/bin/pytest -q` collects and passes, or formally approve
   the module-form command as the prescribed replacement.
2. Make `ruff check app tests` pass without broad unsafe auto-fixes.
3. Provision the required iPhone 16 Pro destination or formally approve the
   iPhone 17 Pro deviation.
4. Provide an authenticated deterministic Settings QA session and complete the
   full interaction, permission, retry, share, Face ID, Dynamic Type, VoiceOver,
   focus-order, and tap-target walkthrough.
5. Capture Data Export, Security & Privacy, and Help & About at the matching
   viewport, build combined reference/implementation inputs, fix P0–P2 drift,
   and repeat.
6. Complete the physical-device checklist with signed-device evidence.
7. Supply production APNs, encryption/transport, backup, AI-provider,
   vendor-contract/BAA, and legal sign-off evidence.
8. Deploy/fix the production Help Center route and recheck all six URLs.

## Release Decision

**BLOCKED. Do not release based on this record.**

The successful automated subsets are useful engineering evidence, but they do
not override the failed direct backend test invocation, lint/live-URL gates, or
the blocked simulator, accessibility, visual, device, operational, and legal
gates.
