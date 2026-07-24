# iOS Insights Readiness Bug Fix Design

**Date:** 2026-07-24  
**Status:** Approved by Gabriel on 2026-07-24  
**Scope:** Peppy iOS Insights list and its existing backend API/generation flow

## Objective

Fix two connected Insights regressions:

1. Opening Insights must not show the false “You don't have permission to do
   that.” error for an authenticated user.
2. Once a user has completed at least three check-ins, Insights must return an
   evidence-backed observation instead of continuing to show the learning
   state solely because none of the stronger rules fired.

The pre-readiness state keeps Peppy's existing Figma direction and uses only:

- Title: `peppy is learning your patterns.`
- Message: `Keep checking in daily and logging doses`

## Confirmed Root Causes

### False permission error

The iOS client requests `GET /api/v1/insights`, while the backend list route is
registered as `@router.get("/")`. FastAPI redirects the request to
`/api/v1/insights/`. The redirected request can lose its bearer authorization
header, after which FastAPI's `HTTPBearer` dependency returns `403 Not
authenticated`. iOS maps every HTTP 403 response to “You don't have permission
to do that.”

Other working collection routes, including Protocols and Check-ins, register
their root handlers at `@router.get("")` and therefore do not redirect the
matching iOS paths.

### Learning state after several check-ins

The iOS screen selects the learning state whenever its fetched insight list is
empty. Existing backend rules intentionally return no candidates unless their
specific conditions are met, such as a one-percent weight drop, a fourteen-day
plateau, a seven-day streak, or dose-linked symptom and energy thresholds.
Three or more legitimate check-ins can therefore produce no insight even
though there is enough data for a neutral baseline summary.

## Chosen Approach

Keep health interpretation on the backend and add a conservative fallback to
the existing deterministic Insights engine. Client-side pattern calculations
are rejected because they would duplicate health logic and could disagree with
the backend. A new readiness endpoint or response envelope is rejected because
the existing insight model can represent this observation without expanding
the API contract.

## Backend Design

### Canonical list route

Register the list handler at `@router.get("")`, matching the existing iOS
`/insights` path exactly. Do not add a second alias or change the iOS endpoint.
The canonical request must return directly without a redirect and retain its
bearer authorization header.

### Three-check-in baseline fallback

Run all existing high-signal rules first. When they collectively return no
candidates, evaluate a baseline fallback:

- Require at least three completed check-ins in the existing analysis window.
- Use the latest three check-ins, ordered by date.
- Require at least one recorded value among weight, energy, mood, or sleep
  quality. Three date-only rows are not enough to claim a pattern.
- Emit one informational `trend` candidate titled
  `Your recent check-in pattern`.
- Build the description from available deterministic values:
  - weight: first recorded value to latest recorded value;
  - energy, mood, and sleep quality: arithmetic average, rendered on their
    existing 1–10 scales.
- Keep the card description concise by using at most two available metrics in
  this priority order: weight, energy, mood, sleep quality.
- Add every available metric as structured supporting data, including the
  number and date range of check-ins analyzed.
- Explain that the observation was computed from the user's latest three
  check-ins; do not call a value “improving,” “declining,” anomalous, or
  dose-related without meeting an existing stronger rule.
- Use a moderate confidence value of `0.6`, reflecting a useful early baseline
  rather than a strong longitudinal conclusion.
- Use a stable `checkin_baseline_v1` source reference so this introductory
  fallback is generated only once per user. Freeze the analyzed dates and
  values in `supporting_data` and the explanation. Later check-ins can still
  produce the existing stronger insight types, but do not create a new neutral
  baseline card after every daily check-in.

The fallback is only considered when the normal rule set returns no candidate.
It must never replace, suppress, or dilute a stronger trend, anomaly,
suggestion, or milestone.

Existing event-driven generation after check-in writes remains the primary
trigger. To recover users whose check-ins predate this fix, the list route
checks whether the user has ever stored an insight. When there are no stored
insights, it runs one synchronous generation pass before returning and then
re-queries the list. This makes the first successful Insights open return the
baseline immediately for an eligible user instead of scheduling work that
requires a later refresh. Once any insight exists, the existing six-hour
generate-if-stale background behavior remains unchanged.

## iOS Design

Keep the existing `InsightsListView`, `PepEmptyState`, header, filters, colors,
spacing tokens, and navigation. This is not a redesign.

Change only the learning-state text to the approved copy:

- `peppy is learning your patterns.`
- `Keep checking in daily and logging doses`

The empty state remains centered beneath the existing filters with the
sparkles icon, existing semantic text colors, and existing type hierarchy.
The implementation should stay visually consistent with the approved
`insights-list` Figma frame and shared Peppy components. Verification is one
practical simulator comparison for hierarchy, spacing, typography, clipping,
and Dynamic Type behavior; pixel-by-pixel iteration is explicitly out of
scope.

When the list request succeeds with the fallback or any stronger insight, the
normal unread/earlier card sections render and the learning state disappears.

## Error Handling

- An authenticated list request must not redirect or surface a permission
  toast.
- Real 401 and 403 responses retain their existing global error mapping.
- Failed network requests retain the current stale-cache and toast behavior.
- Fewer than three qualifying check-ins continue to show the approved learning
  state.
- Three check-ins with no supported metric values continue to show the learning
  state rather than inventing a finding.
- Narration remains optional. The deterministic fallback text must work when
  the external narrator is disabled or fails.

## Testing

Backend regression coverage:

- Authenticated `GET /api/v1/insights` returns `200` without following a
  redirect.
- Two qualifying check-ins produce no fallback.
- Three qualifying check-ins with supported metrics produce the baseline
  candidate when all stronger rules are silent.
- A stronger rule result prevents the fallback from being added.
- The fallback description, explanation, confidence, and supporting rows are
  derived from the same latest three check-ins, while its source reference
  remains the stable one-time baseline key.
- Repeated generation does not create another neutral baseline for the user.
- An eligible user with no stored insights receives the generated baseline in
  the same list response.
- Narrator-disabled generation persists the deterministic fallback.

iOS regression coverage:

- The learning-state title and message match the approved copy exactly.
- An empty successful response still renders the learning state.
- A non-empty response renders insight sections instead of the learning state.

Verification:

- Run focused backend insight tests and the full relevant backend test suite.
- Run focused iOS Insights tests.
- Build the iOS app for a generic iOS Simulator with code signing disabled.
- When a simulator runtime is available, inspect one Insights empty-state
  screenshot against the existing Figma reference without entering an
  open-ended pixel-matching loop.

## Out of Scope

- New insight categories, medical recommendations, or new LLM prompts.
- Client-side health-pattern calculations.
- A new readiness/progress API or progress meter.
- Changes to the Insights detail or weekly-summary screens.
- Broad visual redesign or pixel-by-pixel Figma iteration.
