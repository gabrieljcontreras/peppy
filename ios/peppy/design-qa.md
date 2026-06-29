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
