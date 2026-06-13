# Peppy iOS Engineering Guide

## Project

- Open `peppy/peppy.xcodeproj` in Xcode.
- The app target and scheme are both named `peppy`.
- The minimum deployment target is iOS 17.
- Keep implementation focused on shipping the iOS MVP.

## Architecture

- Build UI with SwiftUI and follow the feature structure already under `peppy/`.
- Use the existing `Dependencies` environment for services and shared app state.
- Keep networking behind `APIClientProtocol` and use `MockAPIClient` for previews, tests, and isolated UI work.
- Reuse the design tokens and components in `peppy/Design` before adding new styling abstractions.
- Put feature-specific screens and logic under `peppy/Features`.
- Keep secrets and authentication tokens in `KeychainService`; never commit credentials.

## Engineering Workflow

- Read the surrounding implementation before changing architecture or naming.
- Keep changes scoped to the requested MVP behavior.
- Add or update tests when introducing business logic or fixing a regression.
- Build after meaningful changes with:

  `xcodebuild -project peppy/peppy.xcodeproj -scheme peppy -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`

- When an iOS Simulator runtime is available, verify important user flows in the simulator.
- Do not modify `project.pbxproj` by hand unless Xcode cannot express the required project change.
- Do not overwrite unrelated local changes in the Xcode project or workspace state.

## Available Skills And Plugins

- Use the Superpowers plugin for substantial engineering work:
  - Start unclear features with `brainstorming`, then use `writing-plans` after the design is approved.
  - Use `test-driven-development` for behavior and business-logic changes.
  - Use `systematic-debugging` for defects instead of guessing at fixes.
  - Use parallel agents or subagent-driven development when tasks are genuinely independent.
  - Use code-review workflows for meaningful changes and `verification-before-completion` before reporting success.
  - Use the branch-finishing workflow when work is ready to commit, publish, or merge.
- Use the Product Design plugin for product and UI work:
  - Run `get-context` before new screens, redesigns, prototypes, or broad visual changes.
  - Use `research` for current, evidence-backed user pain and product opportunities.
  - Use `ideate` for visual exploration; when there is no visual target, present three directions and wait for selection before building.
  - Use `audit` for evidence-based UX, flow, and accessibility reviews.
  - Use `design-qa` to compare a chosen design or screenshot with the rendered iOS implementation before handoff.
  - Preserve Peppy's existing design tokens, components, assets, and brand direction unless the approved brief changes them.
  - Treat Product Design prototypes as exploration; implement production MVP screens in the existing SwiftUI app unless the user explicitly requests a separate prototype.
- Use the GitHub plugin for repository, issue, pull request, review, CI, and publishing workflows.
- Use the Browser plugin for local web targets or web-based companion flows, not as a substitute for iOS Simulator testing.
- Use the image generation skill when the product needs a new raster illustration, texture, mockup, or image asset.
- Use document, presentation, and spreadsheet skills only when the requested deliverable calls for those artifact types.
- Follow the relevant skill instructions whenever a task triggers one of these capabilities.

## MVP Quality Bar

- Prioritize a working end-to-end user flow over speculative abstractions.
- Include loading, empty, success, and actionable error states for networked screens.
- Preserve accessibility labels, Dynamic Type behavior, and usable tap targets.
- Avoid placeholder navigation or buttons that appear functional but do nothing.
- Report build or simulator limitations clearly when verification cannot be completed.
