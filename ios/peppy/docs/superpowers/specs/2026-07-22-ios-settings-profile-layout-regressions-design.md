# iOS Settings Profile Layout Regression Repair

**Date:** 2026-07-22

**Status:** Approved for implementation planning

## Objective

Repair the layout regressions introduced while implementing the iOS settings Profile detail without changing settings data, editing, validation, or save behavior.

The completed repair must:

- restore the original functional native bottom tab bar;
- remove the duplicate custom bottom navigation;
- make Profile detail typography match the readable, Dynamic Type-aware hierarchy used by the More overview;
- keep the Profile detail vertically scrollable when its content does not fit; and
- keep the Profile heading and header controls fully visible below the top safe area.

## Root Cause

`MainTabView` still defines five native SwiftUI tab items, but the settings implementation also hides the system tab bar and inserts a second `PeppyTabBar` through a bottom `safeAreaInset`. On affected runtime and container combinations, the custom presentation overlaps the native tab interface instead of reliably replacing it.

`ProfileSettingsView` translates raster measurements directly into fixed 8–12 point text sizes. Those sizes do not match the More overview's readable scaled typography. The same view pulls its content upward with negative top adjustments and duplicates the header controls through a hidden layout copy plus a `ZStack` overlay. This makes the top layout sensitive to device safe-area and container differences and can clip the Profile heading.

## Design

### Bottom Navigation

Use the native `TabView` presentation already responsible for tab selection:

- keep the existing five `.tabItem` and `.tag` declarations;
- remove the custom `PeppyTabBar`, its layout and presentation helpers, the tab-bar hiding modifier, and the bottom safe-area inset;
- restore the native Insights unread badge on `InsightsTab`; and
- preserve `ProtocolNavigationCoordinator` and every cross-tab route unchanged.

This returns tab visuals and interaction to one owner and restores the behavior that existed before the settings-specific tab replacement.

### Profile Header And Scrolling

Keep `ProfileSettingsView` inside a vertical `ScrollView`, but simplify its content hierarchy:

- place the header controls and Profile title in normal vertical layout order;
- remove the hidden duplicate of `headerControls`;
- remove the overlay `ZStack` used to position the visible controls;
- remove negative header and body top adjustments;
- add ordinary positive top and bottom spacing using existing Peppy spacing tokens; and
- respect the container safe area rather than allowing content to paint above the scroll view's bounds.

The Profile page remains scrollable at all supported sizes. Larger Dynamic Type content is allowed to increase the page height and scroll naturally rather than being compressed to reproduce the raster's original one-screen composition.

### Profile Typography

Change only Profile detail typography. The More overview remains unchanged.

Profile will follow the More overview's rounded system-font hierarchy and scaling behavior:

- the page title uses a 24-point scaled baseline relative to `.title`, and its description uses a 12-point scaled baseline relative to `.body`, matching More;
- section headings use a 13-point scaled baseline relative to `.headline`, while section descriptions use an 11-point scaled baseline relative to `.subheadline`;
- row titles and primary values use a 13-point scaled baseline, while supporting labels and descriptions use an 11-point scaled baseline;
- edit actions and segmented controls use at least a scaled `.subheadline`, the save action uses a semibold scaled `.body`, and security/footer copy uses `.footnote`; and
- existing colors, cards, icons, dividers, controls, copy, and information order remain intact.

Dynamic Type must reflow multiline content without truncating essential profile values or shrinking interactive controls below the existing 44-point minimum target.

## Data Flow And Error Handling

No settings data flow changes are required. `ProfileSettingsViewModel`, `SettingsStore`, editor sheets, account/profile API calls, validation messages, discard confirmation, save state, and weight-unit preference propagation remain unchanged.

Existing inline validation and save errors continue to appear within the scrollable content and must use readable semantic text sizing.

## Testing And Verification

Implementation will follow red-green TDD where the existing test seams can express the regression:

1. Update the Profile layout contract test first so it rejects negative top positioning and raster-sized typography assumptions.
2. Run the focused Profile settings test and confirm the expected failure before production changes.
3. Restore the native tab structure and Profile layout/typography with the smallest scoped source changes.
4. Run focused settings, navigation, and Profile tests.
5. Run the complete iOS test suite on the available iPhone 17 simulator.
6. Run the generic iOS Simulator Debug build with code signing disabled.
7. Inspect Profile on the simulator to confirm one functional bottom tab bar, readable More-style typography, natural vertical scrolling, and a fully visible header.

Because the duplicate tab bar is a SwiftUI presentation-structure regression rather than business logic, final verification includes source-structure inspection and simulator evidence in addition to unit tests.

## Non-Goals

- Redesigning the More overview.
- Changing Profile fields, copy, section order, editors, validation, or persistence.
- Extracting a new shared settings component library.
- Rebuilding Profile with `Form` or `List`.
- Implementing later settings-plan destinations.
- Changing backend or network contracts.

## Files Expected To Change

- `ios/peppy/App/MainTabView.swift`
- `ios/peppy/Features/Settings/Views/ProfileSettingsView.swift`
- `ios/peppy/peppyTests/ProfileSettingsViewModelTests.swift`

The implementation plan may narrow this list, but it must not expand into unrelated settings or backend work.
