# iOS Home Dashboard Redesign

## Problem

The current Home tab (`DashboardView`) is a placeholder-grade screen: a generic
header ("Your protocol, understood."), a protocol card, a check-in card, and
three thin text-only cards (response snapshot, insight, connected context).
It doesn't match the Figma home screen (`dashboard-with-insight.png`) in tone,
information density, or professional polish, and it under-uses data the
backend can already provide (protocol timeline, insight confidence, wearable
metrics, cross-feature activity).

## Goal

Rebuild the Home tab to match the Figma reference closely: a personalized,
information-rich dashboard that surfaces real state from Protocols,
Check-ins, Insights, and (when connected) wearables — reinforcing Home as the
connective hub of the app rather than a static landing page.

Figma reference: `dashboard-with-insight.png` (extracted to
`~/.claude/projects/-Users-gabri-peppy/figma-frames/`).

## Section-by-section design

Top to bottom, replacing the current `DashboardView` body:

1. **Header row** — "peppy" wordmark top-left (`PeppyLogo(showsWordmark: true)`,
   already in use). Top-right: a small circular tappable badge using
   `PeppyLogo(showsWordmark: false)` (the icon-only mark) on a `pepPrimaryMuted`
   circle background, wrapped in a `Button` that sets
   `deps.protocolNavigation.selectedTab = .profile`. This gives the mark a
   real function (jumping to Profile/Settings) instead of being decorative.

2. **Greeting** — `"Good \(dayPart), \(name)"` where `dayPart` is
   morning/afternoon/evening based on the current hour (5–11 morning, 12–16
   afternoon, 17–4 evening), and `name` is
   `deps.appState.currentUser?.displayName`, first-name-only (split on
   whitespace, take first component), falling back to `"there"` if empty.
   Subtitle: `"Here's what's happening with your protocol today."` (static,
   matches Figma).

3. **Date row** — calendar icon + today's date (`EEEE, MMMM d` or similar,
   reuse an existing date formatter pattern from the codebase if one fits),
   right-aligned pill showing `"Protocol active • Week N"` (or the
   status-appropriate variant — see Next Dose card below for status
   handling). Week `N` is computed client-side from `protocol.startDate`
   using the same elapsed-time/week-interval math already implemented in
   `DoseLogViewModel` (`Self.weekInterval`), not reimplemented from scratch.
   Only shown when the protocol is in `active`/`inactive` status; hidden
   entirely for `missing`/`pending_setup` (no meaningful week count yet).

4. **Next Dose card** (replaces part of what `DashboardProtocolCard` does today):
   - Shown only when `protocol.status == "active"` and the protocol has at
     least one compound — a protocol you're no longer following shouldn't
     claim to have a dose "due".
   - Layout: circular icon tile (pill/bottle SF Symbol) + "NEXT DOSE" caption
     + compound name (bold) + "`dose unit`" + due-date text, "Log dose" pill
     button + chevron, tap anywhere routes like the existing card.
   - Due date/compound selection: `DashboardViewModel` calls
     `protocolStore.loadDoseLogs(protocolID:)` for the active protocol on
     load, then for each compound computes the next due date using the
     existing `DoseScheduleCalculator` + `nextDoseDateText`-style logic
     (extract/reuse rather than duplicate — see Implementation notes). Pick
     the compound with the earliest upcoming due date. If due date has
     passed (overdue), still show it with the same "Due <date>" text; no
     special overdue styling is required for this pass.
   - "Log dose" button routes to `.logDose(protocolID:compoundID:)` via
     `deps.protocolNavigation.show(...)`.
   - Fallback: for `pending_setup`, `missing`, `inactive`, or an active
     protocol with no compounds, render the existing `DashboardProtocolCard`
     treatment (finish setup / create protocol / view protocol / past
     protocol) in this slot instead. This preserves the current onboarding
     and past-protocol nudge behavior — nothing about that card's logic
     changes, it just moves under the new header/date row.

5. **Today's Check-in card** — visually restyled version of the existing
   `DashboardTodayCard`: circular icon tile (calendar/checkmark), "TODAY'S
   CHECK-IN" caption, existing title/subtitle/highlights logic unchanged,
   pill-style button ("Check in" outlined / "View" once saved) + chevron.
   No behavior change, pure visual pass to match the card language above.

6. **Weight Trend card** — replaces `responseSnapshot`. Shows:
   - Caption "WEIGHT TREND", latest weight as a large number formatted via
     the existing `WeightUnitPreferences`/`WeightUnit` formatter, and a
     delta line ("↓ 2.3 lb this week" / "↑ …" / no-change styling) computed
     from the first vs. last point in `weight_trend` for points within the
     last 7 days.
   - A real sparkline: `Chart` (Swift Charts, already used in
     `WeeklySummaryView`) with an `AreaMark` + `LineMark` over
     `response_snapshot.weight_trend`, day-of-week axis labels, styled with
     `pepPrimary`/`pepPrimaryLight` to match the Figma red gradient line.
   - Empty state (no weight points): keep a short prompt ("Log a few
     check-ins to see your trend.") in place of the chart, no crash on empty
     data.

7. **Wearable stat tiles** — three tiles (Sleep / HRV / Readiness), each an
   icon + value + colored progress-style bar + "From Oura"/"From Whoop"
   caption, mirroring Figma. Data comes from a new call to the existing
   `GET /wearables/data/latest` endpoint (new `Endpoint.getLatestWearableData`
   case, called once per active connection or once generally — see
   Implementation notes for exact contract). **Only rendered when
   `connected_context.has_wearables` is true and the API call returns data**;
   otherwise this entire row is omitted (no placeholder/prompt card) per
   the earlier decision — most users have no way to connect a wearable yet,
   so this stays dormant until that flow exists.

8. **Latest Insight card** — restyled version of the existing insight card:
   circular sparkle icon tile, "LATEST INSIGHT" caption, title/empty-message
   logic unchanged, "See why" pill button, plus a new confidence badge
   ("High confidence" / "Medium confidence" / "Low confidence" derived from
   the new `confidence` float: ≥0.75 High, ≥0.5 Medium, else Low) shown only
   when an insight (not an empty state) is present. Tap behavior unchanged
   (`showInsight`/`showInsightsTab`).

9. **Recent Activity feed** — new section, up to 5 rows, each: icon tile
   (colored by type), title, subtitle, relative/short timestamp, chevron
   only for navigable types. Sourced from the new `recent_activity` field
   on `DashboardSummary` (see Backend section). Row tap behavior:
   - `dose_logged` → `deps.protocolNavigation.show(.detail(protocolID))`
   - `checkin_completed` → `deps.protocolNavigation.showCheckin(.detail(checkinID))`
   - `wearable_synced`, `lab_added` → no navigation (plain row, no chevron)
   Section is omitted entirely if the array is empty (e.g., a brand new
   account).

Existing states preserved as-is, just re-themed to the new visual language:
sync-recovery card (top, when `showsProfileSyncRecovery`), loading state
(`PepLoadingView`), and error state.

## Backend changes

All changes are additive to existing schemas/endpoints — no breaking
changes, no new tables, no new endpoints beyond the activity feed.

### `app/api/schemas/dashboard.py`

- `DashboardProtocolSummary` gains `start_date: Optional[date]`.
- `DashboardInsightSummary` gains `confidence: Optional[float] = None`.
- New `DashboardActivityItem` model:
  ```python
  class DashboardActivityItem(BaseModel):
      type: str  # "dose_logged" | "checkin_completed" | "wearable_synced" | "lab_added"
      title: str
      subtitle: str
      timestamp: datetime
      protocol_id: Optional[UUID] = None
      checkin_id: Optional[UUID] = None
  ```
- `DashboardSummary` gains `recent_activity: list[DashboardActivityItem]`.

### `app/services/dashboard.py`

- `_protocol_summary` includes `start_date` from the `Protocol` row.
- `_insight_summary` includes `confidence` from the `Insight` row (omitted/
  `None` for the empty-message branches).
- New `_recent_activity(user_id)` method: queries the last few rows (e.g.
  limit 5 each, then merge-sort by timestamp and take the top 5 overall)
  from `DoseLog` (→ `dose_logged`, title = compound name, subtitle = dose +
  unit), `Checkin` (→ `checkin_completed`, subtitle summarizing logged
  fields, reusing whatever summary phrasing already exists for check-ins if
  any), `WearableConnection.last_sync_at` (→ `wearable_synced`, title =
  provider display name), and `LabResult` (→ `lab_added`, title = lab name/
  type). No new indices required; these are all small per-user row counts
  filtered by `user_id` and already-indexed columns.

### Tests

- Extend `backend/tests/test_dashboard_service.py` /
  `test_dashboard_routes.py` for the three additive fields and the merged
  activity ordering (including the empty-activity case and a case with all
  four types present).

## iOS changes

### Networking

- `Core/Network/Endpoint.swift`: new `getLatestWearableData` case → `GET
  /wearables/data/latest`.
- `Core/Network/APIModels.swift` (or a new `WearableAPIModels.swift`
  alongside the existing pattern): decode the existing
  `WearableDataResponse` shape (already documented in
  `backend/app/api/schemas/wearable.py`) into a Swift `WearableDataSnapshot`.

### Dashboard models/view model

- `DashboardModels.swift`: add `startDate` to `DashboardProtocolSummary`,
  `confidence` to `DashboardInsightSummary`, and new
  `DashboardActivitySummary`/`DashboardActivityItem` Codable types plus
  `recentActivity` on `DashboardSummary`. Update the two `mock*` fixtures
  and `replacingProtocol(with:)` accordingly.
- `DashboardViewModel.swift`:
  - After loading the summary, if the protocol is active with compounds,
    call `protocolStore?.loadDoseLogs(protocolID:)` and expose a computed
    `nextDose: (compound: Compound, dueDate: Date)?` for the view.
  - New `loadWearableSnapshot()` (or fold into `load()`) that calls
    `.getLatestWearableData` when `connected_context.has_wearables` is true,
    exposing `wearableSnapshot: WearableDataSnapshot?`.
  - Existing `todayPreview`/`checkinRoute` logic unchanged.

### Next-dose calculation reuse

`ProtocolDetailViewModel.nextDoseDateText` currently contains the
recurrence math (fixed-days / twice-weekly / monthly via
`DoseScheduleCalculator`) as a private method scoped to that view model.
Extract the compound-level "next due date" computation (not the
string-formatting wrapper) into a shared static helper — e.g. a static
method on `DoseScheduleCalculator` itself, or a small
`NextDoseCalculator` — that both `ProtocolDetailViewModel` and
`DashboardViewModel` call. `ProtocolDetailViewModel` is refactored to call
the shared helper instead of duplicating it. This is a targeted refactor of
existing logic, not new business rules.

### Views

- `DashboardView.swift`: rewritten body implementing the 9 sections above.
  Existing loading/error/sync-recovery branches preserved.
- `DashboardCards.swift`: existing `DashboardProtocolCard`/`DashboardTodayCard`
  restyled (icon tiles, caption labels, pill buttons) to match the new
  visual language; add new `DashboardNextDoseCard`, `DashboardWeightTrendCard`
  (with embedded `Chart`), `DashboardWearableTilesRow`, restyle the insight
  card into `DashboardInsightCard` with confidence badge, and add
  `DashboardActivityFeed`/`DashboardActivityRow`.
- No new design tokens needed — existing `Color.pep*`, `Spacing`,
  `CornerRadius` cover the card/pill/badge language already.

### Tests

- `DashboardViewModelTests.swift`: cover next-dose selection (multiple
  compounds, no compounds, no logs yet, overdue), wearable snapshot
  fetch gating on `has_wearables`, and the new model decoding.
- Snapshot/logic tests for any new pure functions (day-part greeting,
  confidence tier, weight delta calculation) — no UI snapshot testing
  infrastructure exists in this repo today, so visual verification is
  manual (per existing project convention — see "No simulator UI driving").

## Out of scope / explicitly deferred

- No in-app wearable-connection UI or Labs UI — those are separate features.
  The wearable tiles and two of the four activity-feed event types will
  simply stay dormant for most users until those flows exist; this is
  expected, not a bug.
- No push/local notification changes.
- No changes to the bottom tab bar — it already matches the Figma tab bar
  (Home / Check-in / Protocols / Insights / More).
- Overdue-dose visual treatment (e.g., red "overdue" styling) is not
  specified by Figma for this screen and is left as plain "Due <date>" text.

## Manual verification checklist (handed to Gabriel, not automated)

- Fresh account (no protocol): header shows create-protocol card, no next
  dose/week pill, no activity feed.
- Pending-setup starter protocol: finish-setup card shown, week pill hidden.
- Active protocol with logged doses: next-dose card shows the soonest
  compound, "Log dose" opens the correct compound's log-dose flow.
- Check-in not yet done today vs. already saved — both card states.
- Weight trend with 0, 1, and several check-ins (chart doesn't crash on
  sparse data).
- No wearable connection: stat-tile row absent.
- Insight present vs. empty-state message; confidence badge only on real
  insights.
- Activity feed with a mix of dose/check-in rows; tapping each lands on the
  right destination.
- Greeting matches device clock's time of day and shows the real display
  name from account registration.
