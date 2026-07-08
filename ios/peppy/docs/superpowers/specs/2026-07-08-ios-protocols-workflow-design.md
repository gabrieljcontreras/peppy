# iOS Protocols Workflow Design

**Date:** 2026-07-08  
**Status:** Approved for implementation planning  
**Platform:** iOS 17+, SwiftUI

## Objective

Deliver the complete iOS protocol lifecycle as one coherent vertical workflow:

- View all protocols.
- View protocol details and dose activity.
- Create and edit protocols.
- Add, edit, and remove compounds.
- Log doses.
- Complete starter-protocol setup.
- Activate, deactivate, reactivate, and delete protocols.
- Enter the same protocol workflows from the Dashboard and Protocols tab.

The local `Peppy IOS.fig` export is the visual source of truth. The implementation must match its protocol frames exactly wherever a frame exists.

## Scope

### Included

- Protocols tab list, empty, loading, and failure states.
- Protocol detail and recent dose activity.
- Protocol creation and editing.
- Compound creation, editing, and removal.
- Dose logging.
- Starter protocol setup and activation.
- Protocol activation, deactivation, reactivation, and deletion.
- Dashboard navigation to starter setup or the relevant protocol detail.
- Shared state reconciliation after every protocol mutation.
- Unit, navigation, integration, and visual verification.

### Excluded

- Unrelated backend protocol features outside this approved workflow. The implementation
  includes connecting every in-scope screen and action to the existing backend APIs and
  making narrowly scoped backend changes when an API contract required by the PRD is
  missing or incomplete.
- Redesigning Dashboard content outside protocol navigation and refresh behavior.
- New analytics, protocol recommendations, or clinical decision support.
- A separate iPad-specific composition.
- Offline mutation queues. Existing data may remain visible during transient failures, but writes require connectivity.

## Visual Source Of Truth

The implementation must use the local Figma export and extracted frames as authoritative references:

- Protocols list
- Protocol detail
- Create protocol
- Add compound
- Log dose
- Set up your first protocol
- Dashboard protocol entry states

For each referenced screen, match:

- Frame hierarchy and content order
- Safe-area and navigation placement
- Dimensions and spacing
- Typography and line wrapping
- Colors, fills, borders, shadows, and corner radii
- Icons and control states
- Sheet and modal presentation
- Scrolling behavior

Existing Peppy design tokens and components should be reused only when their rendered values match the Figma reference. Any mismatch should be handled with narrowly scoped Protocols feature styling rather than a broad design-system change.

Product states not represented in Figma must extend the current Peppy visual language and preserve the closest referenced composition.

## Architecture

### Feature Boundary

The Protocols feature will own:

- Protocol list and detail presentation.
- Protocol and compound editors.
- Dose logging.
- Protocol navigation destinations.
- Protocol-specific view models and presentation state.
- A shared `ProtocolStore` that coordinates loaded data and mutations.

Networking will continue through the existing `APIClientProtocol`, `Endpoint`, dependency injection, and API model conventions.

### Shared Protocol Store

`ProtocolStore` is the authoritative in-memory source for:

- The current protocol collection.
- The selected protocol detail, when loaded.
- Initial loading, refresh, and mutation state.
- Reconciliation after create, update, status, compound, dose, and delete operations.

The store does not own transient form fields or navigation. Each editor view model owns its draft and validation state.

After a successful mutation, the store applies the returned server representation when complete. When the response does not contain enough data to guarantee consistency, it reloads the affected protocol and list. Dashboard data also refreshes after mutations that can change its protocol card.

### Focused View Models

Use separate view models for:

- Protocol list
- Protocol detail
- Protocol editor
- Compound editor
- Dose logger
- Starter protocol setup

Each view model exposes typed presentation state and delegates persisted data changes through the store or API client. Editors remain independently testable and do not directly mutate another screen's local state.

### Navigation Ownership

The Protocols tab owns a dedicated `NavigationStack` and typed destinations for list, detail, create, edit, compound editor, and dose logging.

Dashboard protocol actions resolve to one of two destinations:

- Pending starter protocol: starter setup.
- Configured protocol: protocol detail.

Dashboard and tab entry points must use the same feature views and mutation behavior. They must not create parallel protocol implementations.

## User Flows

### Protocol List

1. Opening the Protocols tab loads protocols when data is absent or stale.
2. The list renders the Figma-defined protocol summaries, compound information, schedule, and status.
3. Selecting a protocol opens its detail.
4. The create action opens the protocol editor.
5. Pull-to-refresh reloads the list without discarding valid visible data.
6. A first-time empty state provides a direct create action.

### Protocol Detail

1. Detail loads the selected protocol and dose activity.
2. The screen presents status, compounds, dosage schedules, progress, and recent doses according to Figma.
3. The primary dose action opens the dose logger with protocol and compound context.
4. Management actions expose edit, add compound, activate or deactivate, and delete where valid.
5. Returning from a successful child flow shows reconciled server data.

### Create And Edit Protocol

1. Create begins with an empty protocol draft; edit begins from a loaded server representation.
2. The form captures the Figma-defined protocol fields, including name, start date, and supported notes or status fields.
3. A protocol must contain at least one valid compound schedule before submission.
4. Compound drafts are added or edited through the shared compound editor.
5. Submission is disabled while invalid or already submitting.
6. Success updates the shared store and routes to the resulting detail screen.
7. Failure preserves all entered data.

### Compound Editor

The shared editor supports creation and modification of:

- Compound selection or name
- Dose amount and unit
- Administration route
- Frequency or schedule
- Applicable timing and start fields represented by the API and Figma

Validation must reject missing compounds, invalid numeric doses, missing units, and incomplete schedules. Removing an existing compound requires confirmation and is unavailable when it would violate a server invariant.

### Log Dose

1. The flow opens with protocol and compound context preselected.
2. The user confirms dose amount, unit, administration date and time, route, and optional notes supported by the API.
3. Validation occurs before submission.
4. A request in progress disables duplicate submission.
5. Success dismisses the flow and refreshes protocol detail and dashboard data affected by the dose.
6. Failure leaves the form intact and displays a recoverable error.

### Starter Protocol Setup

The starter setup uses the Figma "Set up your first protocol" composition and the existing starter activation contract. It captures dose, frequency, route, and start date, validates the complete request, activates the starter protocol, refreshes shared protocol and dashboard state, and routes to the active protocol experience.

Starter setup should share validation and field components with the protocol and compound editors where behavior is identical, without forcing unrelated screens into one large view model.

### Status And Destructive Actions

- Deactivation requires confirmation and leaves the protocol available in its inactive state.
- Reactivation is available for an inactive protocol when supported by the backend contract.
- Deletion requires explicit destructive confirmation.
- Successful deletion removes the protocol from shared state and returns to the list.
- Failed status or deletion requests keep the user on the current screen and preserve the prior server-backed state.

## State Model

Screens and view models use explicit states where applicable:

- `idle`
- `loading`
- `loaded`
- `empty`
- `submitting`
- `failed`

Initial-load failure may replace content with a retry state. Refresh or mutation failure must preserve valid loaded content and present an inline or modal error appropriate to the Figma hierarchy.

Only one mutation affecting the same protocol may be submitted at a time. Controls involved in the active request remain disabled until it resolves.

## Validation And Error Handling

- Field validation appears next to the relevant control when the cause is local or can be mapped from a server response.
- Unmapped server and transport errors use a general message within the current screen or sheet.
- Entered form data survives validation and network failures.
- Destructive failures never pop navigation or remove local content.
- Empty successful responses are not treated as errors when allowed by the endpoint contract.
- Authentication and shared networking errors continue to use existing app-level handling.
- User-facing messages must be actionable and must not expose raw server or decoding errors.

## Dashboard Integration

The Dashboard protocol card must:

- Open starter setup for `pending_setup`.
- Open protocol detail for a configured protocol.
- Reflect create, activation, status, deletion, and dose changes after successful mutations.
- Preserve the Dashboard's approved visual design except for navigation wiring and state refresh required by this feature.

If typed cross-tab routing is needed, `MainTabView` should own the selected tab and pending protocol destination. The Dashboard should emit navigation intent rather than reaching into Protocols views directly.

## Accessibility And Layout

- Preserve Dynamic Type readability without overlapping or truncating critical values.
- Provide accessibility labels for icon-only controls.
- Maintain minimum tappable areas for interactive elements.
- Expose validation and mutation errors to VoiceOver.
- Keep destructive actions semantically identified as destructive.
- Verify scrolling, keyboard avoidance, sheets, and safe areas on smaller and larger supported iPhones.

Exact Figma geometry is the baseline at the reference viewport. Adaptive behavior may change wrapping or scrolling only where required to keep the interface usable on other supported sizes.

## Testing Strategy

### Unit Tests

Cover:

- Store load, refresh, selection, and mutation reconciliation.
- List, detail, empty, and failure presentation.
- Create and edit validation and request construction.
- Compound add, edit, remove, and validation behavior.
- Dose-log validation, submission locking, success, and error recovery.
- Starter activation and dashboard refresh.
- Activation, deactivation, reactivation, and deletion outcomes.
- Stale or overlapping request protection.

Use the existing dependency injection and `MockAPIClient` patterns.

### Navigation And Integration Tests

Verify:

- Protocols tab to list, detail, create, compound editor, and dose logger.
- Dashboard to starter setup.
- Dashboard to configured protocol detail.
- Successful create routes to the created detail.
- Successful deletion returns to a reconciled list.
- Child-flow mutations are visible after returning to detail and Dashboard.

### Build And Manual Verification

- Run the iOS unit-test suite.
- Produce a clean simulator build.
- Exercise the complete workflow against the available backend.
- Verify loading, empty, retry, validation, mutation failure, and destructive confirmation behavior.

### Visual Verification

Capture simulator screenshots at the same viewport as each extracted Figma frame and compare:

- Protocols list
- Protocol detail
- Create protocol
- Add compound
- Log dose
- Starter protocol setup
- Dashboard entry states

Acceptance requires no unexplained differences in hierarchy, spacing, typography, colors, borders, icons, control sizing, sheets, or safe-area placement. Also inspect a smaller and larger iPhone viewport for clipping, overlap, broken scrolling, and keyboard obstruction.

## Acceptance Criteria

The feature is ready when:

1. Every included protocol lifecycle action works against the existing API.
2. Dashboard and Protocols tab use the same screens and reconciled protocol state.
3. Forms validate correctly, prevent duplicate submission, and retain drafts on failure.
4. Destructive actions require confirmation and recover safely from errors.
5. Automated tests cover core state, validation, payload, mutation, and navigation behavior.
6. The app builds cleanly and the end-to-end workflow passes manual verification.
7. All available protocol Figma frames pass same-viewport visual comparison.
8. Supported iPhone sizes have no clipped, overlapping, inaccessible, or keyboard-obscured controls.
