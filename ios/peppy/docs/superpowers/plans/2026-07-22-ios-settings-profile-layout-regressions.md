# iOS Settings Profile Layout Regressions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the native iOS tab bar and make Profile detail use the readable, scrollable, safe-area-aware visual hierarchy already used by the More overview.

**Architecture:** Keep `TabView` as the sole owner of bottom navigation and preserve every existing route and settings data flow. Simplify `ProfileSettingsView` into one normal scrollable vertical hierarchy, then replace raster-derived fixed text sizes with More-aligned scaled metrics while retaining the existing cards, controls, editors, and view model.

**Tech Stack:** Swift 5, SwiftUI, Observation, XCTest, Xcode 26.6, iOS 17+

## Global Constraints

- Change Profile detail typography only; do not restyle the More overview.
- Preserve `ProfileSettingsViewModel`, `SettingsStore`, API contracts, validation, save/discard behavior, section order, copy, colors, icons, and editor sheets.
- Preserve all five tabs, `ProtocolNavigationCoordinator`, cross-tab routes, and the native Insights unread badge.
- Keep every interactive control at least 44 points and allow Dynamic Type content to expand and scroll naturally.
- Do not add dependencies, edit `project.pbxproj`, or touch backend/web code.
- Run Xcode through `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild` because the machine's active developer directory points at Command Line Tools.
- Use the available `iPhone 17` simulator; `iPhone 16 Pro` is not installed.

---

## File Structure

- `ios/peppy/App/MainTabView.swift` — remove the settings-specific custom tab presentation and restore the native Insights badge.
- `ios/peppy/App/PeppyApp.swift` — keep the debug Profile visual-QA route buildable and make it display the same native tab bar as the app.
- `ios/peppy/Features/Settings/Views/ProfileSettingsView.swift` — simplify safe-area/scroll layout and adopt readable scaled Profile typography.
- `ios/peppy/peppyTests/ProfileSettingsViewModelTests.swift` — replace obsolete custom-tab assertions and add measurable safe-layout/typography regression coverage.

### Task 1: Restore Native Bottom Navigation Ownership

**Files:**
- Modify: `ios/peppy/App/MainTabView.swift:21-194`
- Modify: `ios/peppy/App/PeppyApp.swift:45-70`
- Modify: `ios/peppy/peppyTests/ProfileSettingsViewModelTests.swift:227-267`

**Interfaces:**
- Consumes: `Tab`, `ProtocolNavigationCoordinator.selectedTab`, `InsightsStore.unreadCount`, and the five existing `.tabItem` declarations.
- Produces: one system-owned bottom tab bar, native unread badge presentation, and a debug Profile QA host with the same navigation presentation.

- [ ] **Step 1: Run a failing source-structure regression check**

Run from the repository root:

```bash
if rg -n 'struct PeppyTabBar|safeAreaInset\(edge: \.bottom|toolbar\(\.hidden, for: \.tabBar' \
  ios/peppy/App/MainTabView.swift ios/peppy/App/PeppyApp.swift; then
  echo 'FAIL: custom tab presentation still overlays the native TabView'
  exit 1
fi
```

Expected: exit 1 after matching `PeppyTabBar`, `.toolbar(.hidden, for: .tabBar)`, and `.safeAreaInset(edge: .bottom...)` in both app entry paths.

- [ ] **Step 2: Remove obsolete custom-tab test expectations**

In `ProfileSettingsViewModelTests.swift`, delete the three `PeppyTabBarFigmaLayout` assertions from `testProfileFramePreservesMeasuredFigmaContract()` and delete `testTabBarBadgePresentationPreservesInsightsCount()`. Those assertions encode the component being removed and would otherwise prevent the target from compiling.

Keep the Profile geometry and presentation assertions:

```swift
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
```

- [ ] **Step 3: Restore the native `TabView` implementation**

In `MainTabView.swift`:

1. Delete `PeppyTabBarFigmaLayout` and `PeppyTabBarPresentation`.
2. Add the native badge back to the Insights tab:

```swift
InsightsTab()
    .tabItem {
        Label(Tab.insights.rawValue, systemImage: Tab.insights.icon)
    }
    .badge(deps.insightsStore.unreadCount)
    .tag(Tab.insights)
```

3. End the `TabView` with only the existing tint:

```swift
}
.tint(.pepPrimary)
```

4. Delete `struct PeppyTabBar` completely.

In the debug-only `ProfileSettingsVisualQAHost` in `PeppyApp.swift`, keep the existing five-tab `TabView` and replace its trailing modifiers with:

```swift
}
.tint(.pepPrimary)
```

- [ ] **Step 4: Verify the source-structure regression is green**

Re-run the Step 1 command.

Expected: exit 0 with no matches and no `FAIL` line.

Then confirm exactly five native tab declarations and the restored badge:

```bash
test "$(rg -c '\.tabItem' ios/peppy/App/MainTabView.swift)" -eq 5
rg -n '\.badge\(deps\.insightsStore\.unreadCount\)' ios/peppy/App/MainTabView.swift
```

Expected: both commands exit 0 and the second prints the Insights badge line.

- [ ] **Step 5: Run navigation and Profile compilation tests**

Run from `ios/`:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:peppyTests/ProtocolNavigationTests \
  -only-testing:peppyTests/ProfileSettingsViewModelTests
```

Expected: `** TEST SUCCEEDED **` with no failing test cases.

- [ ] **Step 6: Commit the native navigation restoration**

```bash
git add ios/peppy/App/MainTabView.swift ios/peppy/App/PeppyApp.swift ios/peppy/peppyTests/ProfileSettingsViewModelTests.swift
git commit -m "fix: restore native ios tab navigation"
```

### Task 2: Make The Profile Header Safe-Area-Aware And Naturally Scrollable

**Files:**
- Modify: `ios/peppy/Features/Settings/Views/ProfileSettingsView.swift:3-208`
- Modify: `ios/peppy/peppyTests/ProfileSettingsViewModelTests.swift:227-247`

**Interfaces:**
- Consumes: the current `ScrollView`, `headerControls`, `header`, Profile sections, `Spacing`, and dismiss confirmation behavior.
- Produces: one vertical Profile hierarchy with positive top padding, no hidden duplicate controls, no overlay positioning, and natural scrolling.

- [ ] **Step 1: Change the layout contract test to reject negative offsets**

Rename the test and replace its two negative-offset assertions:

```swift
func testProfileLayoutUsesSafeAreaSpacingAndAccessibleGeometry() {
    XCTAssertEqual(ProfileSettingsFigmaLayout.referenceCanvasWidth, 853)
    XCTAssertEqual(ProfileSettingsFigmaLayout.referenceCanvasHeight, 1_844)
    XCTAssertEqual(ProfileSettingsFigmaLayout.horizontalPadding, 22)
    XCTAssertEqual(ProfileSettingsFigmaLayout.cardCornerRadius, 8)
    XCTAssertEqual(ProfileSettingsFigmaLayout.headerControlDiameter, 30)
    XCTAssertGreaterThanOrEqual(ProfileSettingsFigmaLayout.headerTopAdjustment, 0)
    XCTAssertGreaterThanOrEqual(ProfileSettingsFigmaLayout.bodyTopAdjustment, 0)
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
```

- [ ] **Step 2: Run the focused test and verify RED**

Run from `ios/`:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:peppyTests/ProfileSettingsViewModelTests/testProfileLayoutUsesSafeAreaSpacingAndAccessibleGeometry
```

Expected: `** TEST FAILED **`; the failure reports `-18` and `-8` are not greater than or equal to zero.

- [ ] **Step 3: Implement one normal scrollable vertical hierarchy**

First make the smallest values change that satisfies the regression:

```swift
static let headerTopAdjustment: CGFloat = Spacing.sm
static let bodyTopAdjustment: CGFloat = 0
```

Replace the `ScrollView` content with this hierarchy:

```swift
ScrollView {
    VStack(alignment: .leading, spacing: Spacing.md) {
        headerControls
        header

        if let errorMessage = model.errorMessage {
            ProfileInlineError(message: errorMessage)
        }

        accountSection
            .padding(.top, ProfileSettingsFigmaLayout.bodyTopAdjustment)
        preferencesSection
        baselineSection
        goalsSection
        saveSection
    }
    .padding(.horizontal, ProfileSettingsFigmaLayout.horizontalPadding)
    .padding(.top, ProfileSettingsFigmaLayout.headerTopAdjustment)
    .padding(.bottom, Spacing.lg)
}
.background(Color.pepBackground.ignoresSafeArea())
```

Delete `.scrollClipDisabled()`. In `header`, delete the hidden `headerControls` copy so it starts directly with `Text("Profile")`. Keep the existing sheet, confirmation dialog, task, toolbar hiding, and header-control actions unchanged.

- [ ] **Step 4: Run the focused test and verify GREEN**

Re-run the Step 2 command.

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Refactor the now-green layout names and extract current typography values**

Rename the layout constants without changing their green values:

```swift
static let contentTopPadding: CGFloat = Spacing.sm
static let firstSectionTopPadding: CGFloat = 0
```

Update the view and test to use those names. Add this internal value catalog immediately after `ProfileSettingsFigmaLayout` and replace the corresponding existing font literals with these constants, preserving the current rendered sizes for now:

```swift
enum ProfileSettingsTypography {
    static let pageTitle: CGFloat = 20
    static let pageDescription: CGFloat = 10
    static let sectionTitle: CGFloat = 10
    static let sectionDescription: CGFloat = 8
    static let rowLabel: CGFloat = 8
    static let rowValue: CGFloat = 10
    static let goalTitle: CGFloat = 9
    static let goalValue: CGFloat = 9
    static let preferenceTitle: CGFloat = 9
    static let preferenceDescription: CGFloat = 8
    static let action: CGFloat = 9
    static let control: CGFloat = 8
    static let saveAction: CGFloat = 12
    static let footer: CGFloat = 10
}
```

This is a behavior-preserving refactor that creates a measurable seam for the next red-green cycle.

- [ ] **Step 6: Re-run all Profile tests after the refactor**

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:peppyTests/ProfileSettingsViewModelTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit the safe Profile layout**

```bash
git add ios/peppy/Features/Settings/Views/ProfileSettingsView.swift ios/peppy/peppyTests/ProfileSettingsViewModelTests.swift
git commit -m "fix: keep profile settings inside safe scroll layout"
```

### Task 3: Match Profile Typography To The More Overview

**Files:**
- Modify: `ios/peppy/Features/Settings/Views/ProfileSettingsView.swift:22-720`
- Modify: `ios/peppy/peppyTests/ProfileSettingsViewModelTests.swift:227-270`

**Interfaces:**
- Consumes: `ProfileSettingsTypography`, the More overview baseline sizes, SwiftUI `@ScaledMetric`, and the existing Profile subviews.
- Produces: readable More-style default sizing that scales with Dynamic Type without changing content or interactions.

- [ ] **Step 1: Write the failing typography contract test**

Add this test below the safe-layout test:

```swift
func testProfileTypographyMatchesMoreOverviewReadableScale() {
    XCTAssertEqual(ProfileSettingsTypography.pageTitle, 24)
    XCTAssertEqual(ProfileSettingsTypography.pageDescription, 12)
    XCTAssertEqual(ProfileSettingsTypography.sectionTitle, 13)
    XCTAssertEqual(ProfileSettingsTypography.sectionDescription, 11)
    XCTAssertEqual(ProfileSettingsTypography.rowLabel, 11)
    XCTAssertEqual(ProfileSettingsTypography.rowValue, 13)
    XCTAssertEqual(ProfileSettingsTypography.goalTitle, 13)
    XCTAssertEqual(ProfileSettingsTypography.goalValue, 11)
    XCTAssertEqual(ProfileSettingsTypography.preferenceTitle, 13)
    XCTAssertEqual(ProfileSettingsTypography.preferenceDescription, 11)
    XCTAssertGreaterThanOrEqual(ProfileSettingsTypography.action, 15)
    XCTAssertGreaterThanOrEqual(ProfileSettingsTypography.control, 15)
    XCTAssertGreaterThanOrEqual(ProfileSettingsTypography.saveAction, 17)
    XCTAssertGreaterThanOrEqual(ProfileSettingsTypography.footer, 13)
}
```

- [ ] **Step 2: Run the typography test and verify RED**

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:peppyTests/ProfileSettingsViewModelTests/testProfileTypographyMatchesMoreOverviewReadableScale
```

Expected: `** TEST FAILED **` with mismatches beginning at page title `20` versus `24` and page description `10` versus `12`.

- [ ] **Step 3: Update the typography baselines**

Replace the catalog values with:

```swift
enum ProfileSettingsTypography {
    static let pageTitle: CGFloat = 24
    static let pageDescription: CGFloat = 12
    static let sectionTitle: CGFloat = 13
    static let sectionDescription: CGFloat = 11
    static let rowLabel: CGFloat = 11
    static let rowValue: CGFloat = 13
    static let goalTitle: CGFloat = 13
    static let goalValue: CGFloat = 11
    static let preferenceTitle: CGFloat = 13
    static let preferenceDescription: CGFloat = 11
    static let action: CGFloat = 15
    static let control: CGFloat = 15
    static let saveAction: CGFloat = 17
    static let footer: CGFloat = 13
}
```

- [ ] **Step 4: Make every Profile text role scale dynamically**

Add scaled metrics to `ProfileSettingsView`:

```swift
@ScaledMetric(relativeTo: .title) private var pageTitleFontSize = ProfileSettingsTypography.pageTitle
@ScaledMetric(relativeTo: .body) private var pageDescriptionFontSize = ProfileSettingsTypography.pageDescription
@ScaledMetric(relativeTo: .body) private var saveActionFontSize = ProfileSettingsTypography.saveAction
@ScaledMetric(relativeTo: .footnote) private var footerFontSize = ProfileSettingsTypography.footer
```

Use them for the Profile heading, its description, `Save changes`, and the security footer.

Add to `ProfileSection`:

```swift
@ScaledMetric(relativeTo: .headline) private var titleFontSize = ProfileSettingsTypography.sectionTitle
@ScaledMetric(relativeTo: .subheadline) private var subtitleFontSize = ProfileSettingsTypography.sectionDescription
```

Add to `ProfileValueRow`:

```swift
@ScaledMetric(relativeTo: .subheadline) private var rowLabelFontSize = ProfileSettingsTypography.rowLabel
@ScaledMetric(relativeTo: .body) private var rowValueFontSize = ProfileSettingsTypography.rowValue
@ScaledMetric(relativeTo: .body) private var goalTitleFontSize = ProfileSettingsTypography.goalTitle
@ScaledMetric(relativeTo: .subheadline) private var goalValueFontSize = ProfileSettingsTypography.goalValue
@ScaledMetric(relativeTo: .subheadline) private var actionFontSize = ProfileSettingsTypography.action
```

Use `goalTitleFontSize`/`goalValueFontSize` when `isGoal` is true and `rowLabelFontSize`/`rowValueFontSize` otherwise. Replace the action's fixed `36 × 24` frame with minimum sizing so Dynamic Type can grow:

```swift
.padding(.horizontal, Spacing.sm)
.frame(minWidth: 44, minHeight: 32)
```

Add to `ProfilePreferenceRow`:

```swift
@ScaledMetric(relativeTo: .body) private var titleFontSize = ProfileSettingsTypography.preferenceTitle
@ScaledMetric(relativeTo: .subheadline) private var subtitleFontSize = ProfileSettingsTypography.preferenceDescription
```

Add to `ProfileUnitControl`:

```swift
@ScaledMetric(relativeTo: .subheadline) private var controlFontSize = ProfileSettingsTypography.control
```

Use the scaled values in their corresponding `.font(.system(size:..., design: .rounded))` calls. Keep icon font sizes unchanged because they size SF Symbols rather than text copy.

- [ ] **Step 5: Run focused Profile and Settings tests and verify GREEN**

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:peppyTests/ProfileSettingsViewModelTests \
  -only-testing:peppyTests/SettingsNavigationTests \
  -only-testing:peppyTests/SettingsStoreTests
```

Expected: `** TEST SUCCEEDED **` with no failing test cases.

- [ ] **Step 6: Commit readable Dynamic Type typography**

```bash
git add ios/peppy/Features/Settings/Views/ProfileSettingsView.swift ios/peppy/peppyTests/ProfileSettingsViewModelTests.swift
git commit -m "fix: use readable profile settings typography"
```

### Task 4: Verify The Complete Regression Repair

**Files:**
- Verify: `ios/peppy/App/MainTabView.swift`
- Verify: `ios/peppy/App/PeppyApp.swift`
- Verify: `ios/peppy/Features/Settings/Views/ProfileSettingsView.swift`
- Verify: `ios/peppy/peppyTests/ProfileSettingsViewModelTests.swift`

**Interfaces:**
- Consumes: all changes from Tasks 1–3 and the debug `-profile-settings-visual-qa` launch path.
- Produces: fresh automated and simulator evidence for one native tab bar, readable scrollable Profile content, and a visible header.

- [ ] **Step 1: Run source and whitespace gates**

```bash
if rg -n 'struct PeppyTabBar|safeAreaInset\(edge: \.bottom|toolbar\(\.hidden, for: \.tabBar' \
  ios/peppy/App/MainTabView.swift ios/peppy/App/PeppyApp.swift; then
  exit 1
fi
test "$(rg -c '\.tabItem' ios/peppy/App/MainTabView.swift)" -eq 5
rg -n '\.badge\(deps\.insightsStore\.unreadCount\)' ios/peppy/App/MainTabView.swift
git diff --check HEAD~3..HEAD
```

Expected: all commands exit 0; the only printed source match is the native Insights badge.

- [ ] **Step 2: Run the complete iOS test suite**

Run from `ios/`:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **` and zero failed tests.

- [ ] **Step 3: Run the generic simulator build**

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project peppy/peppy.xcodeproj \
  -scheme peppy \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Build and capture the deterministic Profile QA route**

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project peppy/peppy.xcodeproj \
  -scheme peppy \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/peppy-settings-profile-regression \
  CODE_SIGNING_ALLOWED=NO
/Applications/Xcode.app/Contents/Developer/usr/bin/xcrun simctl boot 'iPhone 17'
/Applications/Xcode.app/Contents/Developer/usr/bin/xcrun simctl bootstatus 'iPhone 17' -b
/Applications/Xcode.app/Contents/Developer/usr/bin/xcrun simctl install booted /tmp/peppy-settings-profile-regression/Build/Products/Debug-iphonesimulator/peppy.app
/Applications/Xcode.app/Contents/Developer/usr/bin/xcrun simctl launch --terminate-running-process booted com.gabriel.peppy -profile-settings-visual-qa
/Applications/Xcode.app/Contents/Developer/usr/bin/xcrun simctl io booted screenshot /tmp/peppy-profile-layout-regression.png
```

If the named simulator is already booted, `simctl boot` may report that state; continue with `bootstatus`.

Inspect `/tmp/peppy-profile-layout-regression.png` and confirm:

- exactly one native bottom tab bar is visible;
- Profile and the header controls are fully below the status-area safe inset;
- Profile copy matches the More overview's readable hierarchy;
- content below the viewport is reachable by vertical scrolling; and
- cards, values, editors, and save action retain their existing order and style.

- [ ] **Step 5: Check final branch scope**

```bash
git status --short
git diff --stat 931665f..HEAD
git log --oneline --decorate -4
```

Expected: a clean worktree; changes since the design commit are limited to this plan, the four planned Swift/test files, and the focused implementation commits.

---

## Self-Review Checklist

- Every approved requirement maps to a task: native tab restoration (Task 1), safe header/scroll hierarchy (Task 2), More-style Profile typography (Task 3), and complete verification (Task 4).
- No task changes More overview styling, settings data flow, backend contracts, editor behavior, or unrelated destinations.
- The custom-tab regression uses a failing structural check because unit tests cannot reliably inspect SwiftUI tab chrome; the layout and typography contracts use XCTest red-green cycles.
- All production code changes have an explicit focused verification command before their commit.
- Final verification includes full tests, a generic build, and deterministic simulator screenshot inspection.
