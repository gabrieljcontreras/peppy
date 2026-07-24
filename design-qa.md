# Task 11 Notifications Design QA

- Reference: `/tmp/peppy-fig-task11.4xctE2/images/98028331c7e48cc14370a68479e7a5f309b13720`
- Implementation capture: `/tmp/peppy-task11-notifications.png`
- Combined comparison: `/tmp/peppy-task11-comparison.png`
- Reference raster: 853 × 1844 px
- Simulator viewport: iPhone 17 Pro, 402 × 874 pt (1206 × 2622 px)
- State: dose reminders, daily check-ins, and insights enabled; alert-only insights disabled; quiet hours set to 10:00 PM–7:00 AM; detailed dose preview shown

## Comparison

The full screen was compared side-by-side at a normalized height. Focused checks covered the header, grouped setting cards, switch states, quiet-hours controls, notification preview, bottom navigation, and overall density.

## Findings

- P0: none
- P1: none
- P2: none
- P3: the implementation uses the centered title and larger native type treatment established by Peppy's current More/Profile screens instead of the Figma raster's leading title.
- P3: iOS 26's taller floating tab bar leaves the save action below the initial viewport, while the screen remains vertically scrollable.
- P3: supporting copy reflects implemented behavior and live settings state rather than copying every Figma sentence verbatim.

## Iteration history

1. Grounded the implementation in the Notifications Figma raster and the existing More/Profile SwiftUI components and spacing.
2. Captured the deterministic visual-QA state in the iPhone 17 Pro simulator.
3. Compared the reference and implementation in one normalized side-by-side image.
4. Accepted the remaining P3 differences because they preserve the current Peppy More-screen hierarchy, native iOS behavior, and functional clarity.

## Final result

passed

---

# Task 16 Integrated Settings Design QA

- Source visual truth:
  - `/Users/gabri/Downloads/more_page.png`
  - `/Users/gabri/Downloads/profile_page.png`
  - `/Users/gabri/Downloads/notifications.png`
  - `/Users/gabri/Downloads/data_export.png`
  - `/Users/gabri/Downloads/security_privacy_overview.png`
  - `/Users/gabri/Downloads/help_settings.png`
- Source dimensions: 853 × 1844 px for every frame.
- Implementation screenshots:
  - More: `/private/tmp/peppy-task9-settings-final.png`
  - Profile: `/private/tmp/peppy-profile-task10-final.png`
  - Notifications: `/private/tmp/peppy-task11-notifications.png`
  - Data Export: not captured.
  - Security & Privacy: not captured.
  - Help & About: not captured.
- Implementation dimensions: 1206 × 2622 px, representing an iPhone 17 Pro
  402 × 874 pt viewport at 3× density.
- Combined comparison evidence:
  - More: `/private/tmp/peppy-task9-settings-comparison.png`
  - Profile: `/private/tmp/peppy-profile-task10-final-comparison.png`
  - Notifications: `/private/tmp/peppy-task11-comparison.png`
- Normalization: the 3× simulator captures were scaled to the 853 × 1844
  reference height and placed with each source frame in one comparison image.
- State: authenticated light-mode Settings root, editable Profile with a staged
  change, and Notifications with reminders/insights enabled and detailed preview.

## Findings

- **P0 — Three required screen comparisons cannot be performed.**
  - Location: Data Export, Security & Privacy, and Help & About.
  - Evidence: each source raster is available, but no browser- or
    simulator-rendered implementation screenshot exists for the same viewport
    and state.
  - Impact: typography, spacing, tokens, icon fidelity, copy wrapping, bottom-tab
    placement, safe areas, and interaction-state polish cannot be verified.
  - Fix: add or use a deterministic authenticated QA route for each screen,
    capture at the matching viewport, place each source and implementation in one
    comparison image, fix P0–P2 drift, and repeat the comparison.

- **P3 — More intentionally omits unavailable product rows.**
  - Location: More / My data.
  - Evidence: the source contains Labs, Connected Data, and Timeline; the release
    implementation contains only working Notifications and Data Export rows.
  - Impact: the implementation is shorter than the visual source, but it avoids
    dead navigation and is required by the approved product scope.
  - Fix: none for this release.

- **P3 — Profile intentionally removes email editing and uses live goal copy.**
  - Location: Profile / Account information and Onboarding goals.
  - Evidence: the source includes an Email Edit action and example goal values;
    the implementation exposes read-only email and canonical onboarding values.
  - Impact: visible copy and one action differ while preserving the approved
    product behavior.
  - Fix: none for this release.

- **Accepted platform-native deviation (prior Profile QA: P2) — Native
  device chrome and SF Symbol silhouettes differ slightly.**
  - Location: More, Profile, and Notifications headers, tab bar, and row icons.
  - Evidence: the simulator uses iPhone 17 Pro status geometry, native tab
    treatment, and closest matching SF Symbols. The earlier Profile QA labeled
    the glyph silhouette difference P2; Task 16 carries that classification
    forward rather than silently downgrading it.
  - Impact: minor platform-native visual variation without a usability or
    hierarchy regression.
  - Fix: accepted as an intentional, non-actionable native-platform difference
    for this release; closest matching SF Symbols remain required by the current
    design system.

## Required Fidelity Surfaces

- Fonts and typography: More, Profile, and Notifications preserve the source
  hierarchy and readable wrapping; Data Export, Security, and Help are blocked
  pending captures.
- Spacing and layout rhythm: the three compared screens preserve grouped-card
  rhythm, margins, section order, radii, and usable safe areas; the remaining
  screens are blocked.
- Colors and visual tokens: compared screens use the existing Peppy coral,
  cream, ink, and semantic accent tokens; the remaining screens are blocked.
- Image quality and asset fidelity: compared screens use the Peppy mark and
  platform icons without visible raster degradation; the remaining screens are
  blocked.
- Copy and content: compared screens are coherent with the approved intentional
  differences; wrapping and density on the remaining screens are blocked.
- Accessibility and interaction states: prior automated coverage supports
  navigation and measurable tap targets, but Dynamic Type, VoiceOver, focus
  order, export sharing, destructive confirmations, and support-link states
  require live simulator/device evidence.

## Full-View And Focused Evidence

The three available combined images are readable at full-screen scale and expose
the header, grouped rows, controls, copy, tab bar, and safe-area treatment.
Separate focused crops were not needed for those screens because their controls
and text remain legible in the original-resolution combined inputs. No valid
focused comparison is possible for the three screens without implementation
captures.

## Comparison History

1. Task 9 compared More in
   `/private/tmp/peppy-task9-settings-comparison.png`; the final comparison found
   no actionable P0–P2 drift, so no visual-fix iteration was required.
2. Task 10 found Profile safe-area/header clipping and typography-readability
   regressions. The implementation was moved into a safe scroll layout and its
   typography was made readable before the post-fix artifact
   `/private/tmp/peppy-profile-task10-final-comparison.png` was accepted. Its
   remaining SF Symbol silhouette variation was recorded as P2 and is retained
   above as an accepted, intentional platform-native deviation.
3. Task 11 compared Notifications in
   `/private/tmp/peppy-task11-comparison.png`; it found no actionable P0–P2
   drift, so no visual-fix iteration was required. The centered native title,
   floating tab-bar height, and live supporting copy remained documented P3
   differences.
4. Task 16 reopened the six-screen gate and directly rechecked those three
   source/implementation comparisons.
5. Task 16 found no implementation captures for Data Export, Security & Privacy,
   or Help & About, so no claim of visual parity is made for those screens.

## Open Questions

- What authenticated deterministic state should be used for Data Export,
  Security & Privacy, and Help & About captures?
- Should future QA add debug-only launch routes for those screens, or exercise
  them through a seeded end-to-end signed-in session?

## Implementation Checklist

1. Capture Data Export, Security & Privacy, and Help & About at the reference
   viewport and matching light-mode states.
2. Create one combined comparison input for each missing screen.
3. Check typography, spacing, tokens, icon/image quality, copy, bottom-tab
   placement, safe areas, and key interaction states.
4. Fix every actionable P0–P2 issue and capture a second comparison.
5. Repeat Dynamic Type and VoiceOver checks on the live screens.

final result: blocked
