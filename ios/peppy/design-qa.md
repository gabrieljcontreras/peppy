# Task 14 Design QA

- Source visual truth: `/Users/gabrielcontreras/Downloads/Peppy IOS.fig`
- Implementation screenshots: not captured in this pass
- Automated verification device: iPhone 17, iOS 26.5
- Intended state: fresh-install onboarding through authentication

## Evidence

- The generic iOS Simulator build completed successfully with `CODE_SIGNING_ALLOWED=NO`.
- The complete unit suite passed on `iPhone 17` iOS 26.5.
- Initial sandboxed `simctl` discovery failed at the CoreSimulator service boundary, but rerunning outside the sandbox found a booted `iPhone 17` simulator.
- No valid implementation screenshots were captured, so no full-view or focused side-by-side Figma comparison was completed in this pass.

## Findings

- **P0 — Live visual and end-to-end QA remain open.** Launch, onboarding, permission denial, resume, authentication, logout, Dynamic Type, VoiceOver, keyboard, and Figma fidelity still require a simulator walkthrough with screenshots.
- **P2 — Small interaction targets found in source review.** Selection chips used a 40-point height, authentication back buttons used a 34-point target, and the password visibility control had no minimum target. These were changed to expose at least 44 points.
- **P2 — Password visibility state lacked a specific announcement.** The control now announces `Show password` or `Hide password`.

## Required Fidelity Surfaces

- Fonts and typography: pending matched screenshots and Dynamic Type inspection.
- Spacing and layout rhythm: pending matched screenshots.
- Colors and visual tokens: pending matched screenshots.
- Image quality and asset fidelity: pending launch and screen captures.
- Copy and content: source strings are present, but visual wrapping and truncation remain pending screenshot review.

## Patches Made

- Raised `PepSelectionChip` to a 44-point minimum target.
- Added a 44-point password visibility target and state-specific accessibility label.
- Added 44-point authentication back-button and secondary text-action targets.
- Added regression coverage for the measurable target-size constants.

## Remaining Verification

1. Capture launch and every required onboarding/authentication state.
2. Compare each implementation capture with the corresponding Figma frame at the same aspect ratio.
3. Exercise fresh install, permission denial, resume, authentication, logout, and returning-user routes.
4. Verify Accessibility 2 Dynamic Type, VoiceOver, Reduce Motion, keyboard avoidance, and target sizes on-device.

final result: automated build and tests passed; manual visual and end-to-end QA pending

---

# Dashboard Task 10 QA

- Source visual truth: `/Users/gabri/Downloads/Peppy IOS.fig`
- Implementation screenshots: not captured in this pass
- Automated verification device: `iPhone 17`, iOS 26.5
- Intended state: authenticated Home dashboard vertical slice with pending starter protocol, daily check-in, starter protocol setup, insight empty state, and connected-context card

## Evidence

- Backend focused dashboard-slice tests passed: 65 tests.
- Full backend test suite passed: 118 tests.
- Affected iOS focused test slice passed on `iPhone 17` iOS 26.5:
  `CheckinViewModelTests`, `DashboardViewModelTests`, `StarterProtocolViewModelTests`,
  `ProfileAttachTests`, and `AppFlowCoordinatorTests`.
- Generic iOS Simulator debug build passed with `CODE_SIGNING_ALLOWED=NO`.
- `git diff --check` and `git diff --cached --check` completed with no whitespace errors.

## Findings

- **P0 — Manual screenshot comparison remains open.** The simulator is available, but the app has no existing QA launch mode or UI test harness for opening authenticated dashboard states with mock dashboard summaries. Adding a temporary product hook only for screenshots was intentionally avoided in this final verification pass.
- **P2 — Connected context action depth is intentionally minimal.** The dashboard shows the connected-context status and truthful empty copy, while full labs/connected-health flows are deferred to later branches.
- **P2 — Secondary tabs remain placeholders by design.** `Protocols`, `Insights`, and `More` are not fully implemented in this vertical slice and will be connected as those app areas are built in separate branches.

## Remaining Visual Verification

1. Capture the dashboard with pending starter protocol.
2. Capture the dashboard with no onboarding peptides.
3. Capture the dashboard after a check-in is logged.
4. Capture starter protocol setup.
5. Capture profile sync recovery.
6. Compare each screenshot against the corresponding Figma frame for spacing, card density, button hierarchy, visual tone, and text wrapping.

final result: Task 10 automated backend and iOS verification passed; manual dashboard screenshot comparison remains pending until a QA launch path or UI test harness exists for the required authenticated states

---

# iOS Settings Task 10 — Profile Design QA

- Source visual truth: `/Users/gabri/Downloads/Peppy IOS (2).fig`
- Extracted Profile frame: `/tmp/peppy-profile-fig.zkzfyW/images/d3b52eb20b079d591deb8f8fbefce8a1ed8804fa`
- Implementation screenshot: `/tmp/peppy-profile-task10-final.png`
- Same-viewport comparison: `/tmp/peppy-profile-task10-final-comparison.png`
- Verification device: iPhone 17, iOS 26.5, light appearance, deterministic 9:41 status bar
- Intended state: authenticated Profile settings with a staged change so the primary action matches the enabled Figma state

## Evidence

- The reference and implementation were normalized to the same 853 × 1844 viewport and inspected together.
- The comparison covers the full page: header, account, preferences, baseline information, onboarding goals, save action, security footer, and bottom navigation.
- The custom bottom navigation matches the compact Figma bar while retaining the existing Insights unread badge behavior and 44-point touch targets.
- The full header is visible on the iPhone 17 and scrolls with the page; it is not clipped by the page-style tab container.

## Findings

- **No P0 or P1 visual issues remain.** Section positions, card dimensions, corner radii, dividers, typography hierarchy, control states, and bottom navigation closely track the source frame.
- **Intentional — email is read-only.** The source frame shows an Email Edit button, but Task 10 explicitly requires accessible read-only email, so that action is omitted.
- **Intentional — goal values use canonical product data.** The implementation uses the shared onboarding goal vocabulary rather than the example values embedded in the design frame.
- **Intentional — current-device status chrome differs.** The iPhone 17 Dynamic Island is taller than the status area represented in the source frame, so the top control row sits below it while retaining the Figma alignment for the page content below.
- **P2 — platform glyph variation.** The closest SF Symbols are used for the Figma icons, following the existing Peppy design system; a few glyph silhouettes vary slightly from the source artwork.

## Functional Fidelity

- Full name, baseline date, baseline weight, baseline height, and all goal rows open their editors.
- Weight and height segmented controls update the displayed units without changing canonical stored values.
- Save is disabled for unchanged/invalid drafts, calls both account endpoints on success, then updates the account-scoped unit preference.
- Failed saves retain the draft and expose a retryable error; Back prompts before discarding unsaved changes.
- Email exposes a read-only accessibility value and no edit action.

final result: passed
