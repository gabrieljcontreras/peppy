# Peppy iOS Check-in Hub Design

## Status

Approved on July 17, 2026.

## Objective

Turn the iOS Check-in tab from a one-use data-entry form into a useful hub where
users can see what they logged, review prior check-ins, edit today's entry, and
understand how the same saved data connects to Home.

The experience follows the approved **Check-in Hub** direction and the visual
language of the supplied `Peppy IOS.fig` file. It must reuse Peppy's existing
SwiftUI design tokens and components rather than introduce a parallel style.

## Current State

- `CheckinView` is only an entry form.
- A successful save dismisses the form, so the Check-in tab does not show the
  saved result or any history.
- Home knows whether today's check-in exists and its identifier, but the card
  does not show the values the user entered.
- Home says an existing check-in can be updated, but iOS does not currently
  expose the backend's update operation.
- The backend already supports listing, fetching, creating, updating, and
  deleting check-ins. Deletion is not required for this project.
- Check-in weight is entered and displayed in kilograms only.

## Product Principles

1. **Saved data is the product.** After entry, the user's recorded response
   should remain visible and useful.
2. **One source of truth.** Home and Check-in must present the same server-backed
   record instead of maintaining independent copies.
3. **Fast daily entry.** The hub adds history and detail without making today's
   check-in difficult to start or edit.
4. **Progressive detail.** Home gives a concise preview; the Check-in tab owns
   complete details and history.
5. **Respect the visual system.** Match the Figma-derived card hierarchy,
   spacing, typography, and action emphasis already established in the app.

## Scope

### Included

- A Check-in hub as the Check-in tab root.
- Today's complete saved details when a check-in exists.
- A prominent action to add today's check-in when it does not exist.
- Editing today's saved check-in.
- A recent-history list and read-only detail screens for older entries.
- A Home preview of today's saved values.
- Cross-tab navigation from Home into the appropriate Check-in destination.
- Shared check-in state used by both Home and Check-in.
- Pounds as the default weight display and input unit.
- An inline lb/kg selector that persists the user's last selection.
- Loading, empty, stale-content, success, and actionable error states.
- Unit, store, view-model, navigation, and presentation tests.

### Excluded

- Deleting check-ins.
- Editing historical check-ins.
- Pagination beyond the backend's current default list response.
- New charts or trend analysis beyond the existing Home response snapshot.
- Changes to backend weight storage; the API remains kilogram-based.
- Per-entry storage of a display unit.
- Cross-device synchronization of the inline weight-unit preference.
- A separate weight-unit control in the More tab.
- Insight generation changes.
- Broad navigation or design-system refactors.

## User Experience

### Check-in Hub Root

The Check-in tab opens to a hub titled `Your check-ins` with supporting copy
that explains users can review what they logged and track their response.

The root has four possible states:

1. **First load:** show `PepLoadingView` using the existing Check-in tone.
2. **No history and no entry today:** show a focused empty state with an
   `Add today's check-in` primary action.
3. **History exists but today is missing:** show the same primary action above
   the recent-history list.
4. **Today exists:** show today's full saved detail first, followed by recent
   history. Today's record must not be repeated in the history list.

The list displays the records returned by the existing list endpoint, ordered
newest first. The backend currently returns at most 100 by default. Pagination
and infinite scrolling are future work.

### Today's Saved Detail

Today's card displays only values that were actually recorded:

- Weight in the user's preferred unit.
- Energy.
- Mood.
- Sleep quality.
- Appetite.
- Nonzero symptoms with their severities.
- Notes when present.

Unset metrics are omitted instead of displaying placeholder values. A saved
entry that contains only notes remains valid and shows those notes.

The card includes `Edit today's check-in`. Editing opens the same editor used
for creation, prefilled with the saved record. A successful edit returns to the
hub and immediately replaces the stored record.

### Recent History

Each history row shows:

- A user-friendly date.
- A compact summary of available high-value signals: weight, energy, mood, and
  whether symptoms were recorded.
- A disclosure affordance.

Selecting a row opens a read-only detail view using the same detail component as
today's card. Historical editing and deletion are intentionally absent.

### Check-in Editor

The existing form remains the foundation of the editor. Its metrics, symptom,
and notes sections keep their current validation and Figma-derived styling.

Creation is available only when the shared store has no record for today.
Editing is available only for today's existing record. The editor title and
primary action distinguish `Add check-in` from `Update check-in`.

After a successful create or update:

1. The API response is reconciled into the shared store.
2. The editor closes or pops back to the hub.
3. The hub shows the saved details.
4. Home recomputes its preview from the same store.
5. The dashboard summary refreshes so its existing logged/id state stays
   consistent with the store.

### Home Connection

When today is saved, the Home card shows:

- A saved-state label.
- Up to three concise highlights in this priority order: weight, energy, mood,
  then symptom count when one of the first three is absent.
- `Notes added` when the check-in has notes but none of those highlights are
  available. Notes content is not previewed on Home.
- A `View full check-in` action.

Selecting a saved Home card switches to the Check-in tab and opens that record's
detail. Selecting an unsaved Home card switches to the Check-in tab and opens
the creation editor directly.

If the dashboard summary says today is logged but the shared store has not yet
loaded the record, Home retains the truthful saved state and can navigate using
the summary's `checkin_id`. The detail destination loads the record if it is not
already in memory.

## Weight Units

### User Behavior

- New installations default to pounds.
- The editor places an inline `lb` / `kg` selector beside the weight field.
- Changing the selector immediately converts a valid in-progress value so the
  represented weight does not change accidentally.
- The selected unit persists locally and becomes the display unit for future
  editors, hub details, history summaries, and Home previews.
- The preference reuses the existing `WeightUnit` model. When an associated
  onboarding draft is available, its `preferredWeightUnit` seeds the first
  Check-in preference; otherwise the preference defaults to pounds.
- Changing the selector updates every visible weight presentation immediately.
- Existing installations without an onboarding or Check-in preference default
  to pounds.

### Data Rules

The backend contract and database remain kilogram-based.

- Pound input is converted to kilograms before creating or updating a check-in.
- Kilogram API values are converted to pounds for display when pounds are
  selected.
- Validation occurs against the converted kilogram value so the existing API
  limit of greater than zero and at most 500 kg remains authoritative.
- Display values use one decimal place and standard unit labels, for example
  `164.9 lb` or `74.8 kg`.
- Unit conversions use one shared utility and are not duplicated in views.
- If the in-progress weight text is incomplete or invalid when the selector is
  changed, preserve the text and surface normal validation rather than guessing
  a converted value.

The selector is a device-local presentation preference, not per-entry health
data. Store it in `UserDefaults` behind a small injectable preference interface
so defaults and persistence can be tested without global state. The existing
backend `preferred_weight_unit` remains onboarding/profile metadata in this MVP;
account-level preference synchronization is future work.

## Architecture

### Shared Check-in Store

Add a `CheckinStore` to `Dependencies`, following the existing shared-store
pattern. It owns:

- The loaded check-in collection.
- Derived access to today's record.
- List and detail loading.
- Create and update mutations.
- Newest-first reconciliation and deduplication by identifier.
- Loading, refresh, and mutation errors.
- A revision or equivalent observable change signal for interested consumers.

The store exposes intent-based methods such as `load`, `loadDetail`, `create`,
and `update`. Views do not execute endpoints or manipulate the collection
directly.

Already-loaded content remains visible during refresh. A refresh failure sets an
inline error without erasing valid records.

### View Models and Views

Keep the feature split into focused units:

- `CheckinHubViewModel` derives hub state and presentation rows from the store.
- The existing `CheckinViewModel` evolves into the editor responsibility for
  create and edit modes, form normalization, unit conversion, and validation.
- `CheckinHubView` renders root states and navigation actions.
- `CheckinDetailView` renders a complete saved record and can be reused inside
  today's card and the historical detail destination.
- `CheckinHistoryRow` renders compact list summaries.
- `CheckinEditorView` contains the existing form sections and create/update
  actions.

Exact file renames are an implementation detail, but each unit must retain one
clear responsibility.

### Navigation

Add a small `CheckinRoute` model with destinations for creation, detail, and
editing. Extend the existing cross-tab coordinator with a Check-in path and a
method that:

1. Selects the Check-in tab.
2. Replaces the Check-in path with the requested destination.

Retain the current coordinator type/name during this project to avoid an
unrelated app-wide rename. Document that its role has expanded beyond protocols.

### Networking

Use existing backend routes:

```text
GET   /api/v1/checkins
GET   /api/v1/checkins/{checkin_id}
POST  /api/v1/checkins
PATCH /api/v1/checkins/{checkin_id}
GET   /api/v1/dashboard/summary
```

iOS already models list, detail, and create endpoints. Add the missing typed
update request/endpoint and keep all calls behind `APIClientProtocol`.

No backend schema or route change is required. Home obtains full preview values
from `CheckinStore`; the dashboard summary remains the fallback for logged state
and identifier.

## Data Flow

```text
Check-in editor
    -> CheckinStore create/update
    -> APIClientProtocol
    -> existing check-in API
    -> returned Checkin reconciled by ID
    -> hub, history, detail, and Home update from shared state
```

On initial authenticated app use:

```text
Home or Check-in appears
    -> CheckinStore loads recent records once
    -> today is derived from the returned collection
    -> Home uses today for preview
    -> Check-in uses the collection for today + history
```

Force refresh remains available after errors and when resolving a server/client
conflict.

## Error Handling

### Load and Refresh

- Initial failure with no content shows a clear error card and retry action.
- Refresh failure with existing content preserves the content and shows an
  inline retry message.
- Missing detail returns to the hub with an actionable `Check-in not found`
  message rather than an empty screen.

### Create and Update

- The editor keeps all user input after a failed request.
- Validation errors appear near the form action using current Peppy error
  styling.
- A create conflict for a duplicate day triggers a forced store reload. When
  today's server record is found, iOS opens that detail and explains that the
  existing check-in was loaded.
- An update failure leaves the editor open and does not mutate the store.
- Duplicate taps are rejected while a mutation is in progress.

### Partial Dashboard State

- Home can show the dashboard's logged state while check-in detail is loading.
- Home does not fabricate metric values when the record is unavailable.
- A CheckinStore failure does not discard the rest of a successfully loaded
  dashboard.

## Accessibility

- Preserve Dynamic Type and multiline text behavior.
- Keep interactive rows and icon actions at least 44 by 44 points.
- Provide descriptive accessibility labels for dates, units, metric scores, and
  symptom severities.
- Do not communicate saved, error, or selected state by color alone.
- Use a native accessible control for the lb/kg selection.
- Ensure read-only detail labels and values have a sensible VoiceOver order.

## Testing Strategy

### Unit Tests

- `CheckinStore` loads and sorts newest first.
- Today's record is excluded from the history rows.
- Detail loading reconciles by identifier without duplicates.
- Create inserts the returned record and increments observable state.
- Update replaces the matching record only after API success.
- Failed mutations preserve prior records.
- A duplicate-day conflict reloads and selects the existing record.
- The editor produces create and update requests with normalized values.
- Pounds are the default when no preference exists.
- The unit selector persists the last choice.
- An associated onboarding draft seeds the initial unit preference.
- lb/kg conversion is correct in both directions and request payloads remain kg.
- Display formatting uses one decimal place and the selected unit.
- Home preview priority and fallbacks use only available values.
- Cross-tab actions select Check-in and set the correct create/detail route.

### View and Integration Tests

- Hub loading, empty, today-saved, history-only, and inline-error states.
- Today's complete detail presentation, including omitted unset values.
- Historical rows navigate to read-only detail.
- Create and edit success return to refreshed hub content.
- Home saved and unsaved cards navigate to the correct destinations.
- Dynamic Type and accessibility labels for unit and metric presentation.

### Verification

- Run the focused iOS test suite for Check-in, Dashboard, and navigation.
- Build the `peppy` scheme for a generic iOS Simulator with code signing
  disabled.
- When a simulator runtime is available, verify create, edit, history detail,
  Home navigation, lb/kg persistence, loading, and failure recovery.
- Compare the implemented screens with `Peppy IOS.fig` for tone, spacing, card
  density, typography, action hierarchy, and tab behavior.

## Acceptance Criteria

- Saving a check-in leaves its complete details visible in the Check-in hub.
- Relaunching or refreshing reloads the saved entry from the server.
- The hub shows recent check-ins newest first and opens read-only details.
- Today's saved entry can be edited without creating a duplicate-day conflict.
- Home displays real values from today's saved entry and opens that record in
  the Check-in tab.
- Home opens the editor directly when today has not been logged.
- Both Home and Check-in reconcile immediately after create or update.
- Weight defaults to pounds, can be switched inline to kilograms, and remembers
  the user's last choice.
- The backend continues receiving and returning kilograms.
- Network errors preserve user input or already-loaded content and offer a
  recovery action.
- The app builds and the relevant automated tests pass.
