# Peppy iOS Insights (AI) Design

**Date:** 2026-07-12
**Status:** Approved by Gabriel (brainstorming session 2026-07-12)
**Predecessors:** `2026-06-30-ios-dashboard-vertical-slice-design.md`, `2026-07-08-ios-protocols-workflow-design.md`

## Objective

Ship the Insights tab as Peppy's flagship AI surface: users see explainable,
AI-written observations about their own protocol response, act on them
(accept / dismiss / snooze), and read an AI weekly summary of what changed.

This is the "AI Personalized Medicine" heart of the PRD (user stories 12–16):
alerts on deviation, AI-generated insights, visible reasoning, and user
control over suggestions.

## Source Context

- **PRD:** `docs/adr/PRD-001-peppy-mvp.md` — Insights Engine returns insights
  with confidence scores and explanations; users accept/dismiss; explanations
  build trust.
- **Figma (visual source of truth, exact-match target):** frames extracted
  from `Peppy IOS (2).fig` to
  `~/.claude/projects/-Users-gabri-peppy/figma-frames/`:
  - `insights-list.png` — list screen
  - `insight-detail.png` — detail screen
  - `ai-weekly-summary.png` — weekly summary screen
  - `dashboard-with-insight.png` — dashboard latest-insight card
- **Backend today:** full insights REST API (`/insights` list/get/read/action/
  generate), `InsightsEngine` with 2 rules (weight_trend, weight_plateau),
  insight model with type/severity/confidence/explanation. No LLM anywhere.
  The celery `run_async` path exists but is never dispatched (dead code —
  leave as-is).
- **iOS today:** Insights tab is a placeholder. All 5 insight endpoints and
  the `Insight` model already exist in `Core/Network`. Dashboard shows a
  latest-insight summary card (not yet tappable into insights).

## Decisions (locked during brainstorming)

| Question | Decision |
|---|---|
| AI approach | **Hybrid**: deterministic rules compute every number; Claude writes the prose. LLM never invents statistics. |
| Scope | All three screens (list, detail, weekly summary) + dashboard card wiring + tab unread badge. |
| New rules | symptom_after_dose, adherence_consistency (incl. milestones), dose_day_energy_dip. (Sleep→energy correlation deferred.) |
| Generation trigger | Event-driven after check-in / dose-log writes + generate-if-stale (6 h) on insights list fetch. FastAPI BackgroundTasks — no celery/redis. |
| Weekly summary | On-demand, cached per (user, completed Mon–Sun week). No scheduler. |
| LLM data boundary | The AI reads the user's **full data picture**: derived stats + longitudinal snapshot (check-ins, doses, protocols, labs, profile) **+ free-text notes**. No name/email/account identifiers. Privacy copy updated to stay honest. |
| Actions | Functional-lite: accept = acknowledge & keep; dismiss = hide from default list; snooze = hide 7 days via `snoozed_until`, resurfaces unread. |
| Supporting-reference rows | Static this slice (no deep links). |
| Empty state | Educational ("peppy is learning your patterns") — no sample insights, no progress meter. |
| Models | Split: Haiku tier for per-insight narratives, Sonnet tier for weekly summary. Exact model IDs pinned in the implementation plan. |

## Product Principle

Every number the user sees traces to a deterministic computation stored with
the insight. Every promise the UI makes (evidence rows, "remind me later",
"vs last week", "explainable") is backed by a durable server-side artifact.
The LLM is an enhancement layer — the product functions fully without it.

Two commitments extend this:

1. **The AI reads everything the user shares.** When generating narratives,
   the AI receives the user's full data picture — check-in history, dose
   logs, protocols and compounds, labs, onboarding profile (goals, peptides,
   baseline), and free-text notes — not just the single finding that
   triggered generation. Depth of context is what makes an insight read as
   personal rather than templated.

2. **Organized longitudinal data, AI-enhanced.** The platform continuously
   computes and organizes what the user shares over time — weekly
   aggregates, weight/energy/mood trends, adherence rates, symptom
   timelines — into a structured longitudinal snapshot. These computed
   series are the product's ground truth: the AI enhances them with
   narrative and meaning, and never contradicts, recalculates, or replaces
   them.

---

## Backend Design

### New rules (join existing 2 in `app/ml/rules/`)

All rules compute their numbers deterministically, emit templated
title/description/explanation (the LLM fallback text), and attach structured
`supporting_data` rows for the detail screen.

1. **`symptom_after_dose`** → type `anomaly`, severity `warning`.
   For each symptom field on check-ins (nausea, injection_site_reaction,
   fatigue, headache, gi_issues; 0–10 severity): if severity ≥ 3 on the dose
   day or the day after for **≥ 3 of the last 4 dose events**, and the
   dose-window occurrence rate is ≥ 2× the non-dose-day rate, emit e.g.
   "Nausea is appearing after dose day". Confidence scales with occurrence
   count and dose-day vs non-dose-day contrast. Minimum data: ≥ 3 dose
   events in window.

2. **`adherence_consistency`** → types `milestone` (info) and `suggestion`.
   Computes dose adherence (logged doses vs expected from active protocol
   compound frequencies) and check-in streaks. Emits milestones (7-day
   check-in streak, 4 weeks on protocol, 100 % adherence week) and a gentle
   suggestion when adherence < ~70 % over 2 weeks.

3. **`dose_day_energy_dip`** → type `trend`, severity info→warning by gap
   size. Compares mean energy and mood on dose days (+ day after) vs other
   days over the window. Requires ≥ 3 dose days and ≥ 4 check-ins; emits when
   the gap ≥ 1.5 points (1–10 scale).

### Schema changes (one alembic migration, additive-only)

- `insights.supporting_data` — Text (JSON): ordered list of
  `{icon_key, label, sublabel, value}` rows written by the rule at detection
  time. Evidence is frozen with the finding (no recompute-at-read drift).
- `insights.snoozed_until` — DateTime nullable. Snooze sets now + 7 days and
  clears `read_at`; default list query excludes rows with
  `snoozed_until > now`; after expiry the insight reappears unread.
- `weekly_summaries` table — `id`, `user_id` (FK, indexed), `week_start`
  (Date, Monday), `payload` (Text JSON), `model_used` (String, nullable),
  timestamps. Unique `(user_id, week_start)`. Payload holds: hero weight
  delta + from/to values, what_changed grid values, what_to_watch items,
  provider_questions, narrative line, per-day weights for the sparkline.
- `users.last_insight_run_at` — DateTime nullable, staleness marker.

### LLM layer — new `app/ml/narrator.py`

- Thin wrapper over the Anthropic SDK. New settings:
  `anthropic_api_key` (empty = fallback-text mode, dev works offline),
  `insight_narrative_model` (Haiku tier), `summary_narrative_model`
  (Sonnet tier).
- **Longitudinal snapshot builder:** a shared helper assembles the user's
  organized data picture for any window — check-in time series (weight,
  energy, mood, sleep quality, symptoms), dose history with compound
  names/frequencies, active protocol details, labs when present, onboarding
  profile (goals, peptides, baseline), and free-text notes. All aggregates
  in the snapshot are computed deterministically. Both narrator entry points
  consume it; it is also the natural seam for future AI features (chat,
  deeper analysis) to read the same organized data.
- **Insight enrichment:** one batched call per generation run. Input: all new
  candidates' rule findings/stats + the longitudinal snapshot for the
  analysis window. Output: structured JSON with a rewritten `description`
  ("Plain-English observation") per candidate. Rule-written `title` and
  `explanation` remain deterministic. Any failure (API error, timeout,
  malformed JSON) → discard wholesale, persist the rules' templated text.
  Generation never blocks on Claude.
- **Weekly summary:** single Sonnet-tier call. Input: computed week-over-week
  stats + the longitudinal snapshot (both weeks). Output JSON: narrative
  line, what_to_watch (may rephrase
  rule-confirmed findings, never invent numbers), provider_questions
  (phrased as questions). The "What changed" grid is purely computed — no
  LLM involvement.
- Prompt guardrails: informational tone; no dosing instructions or medical
  advice; provider questions only as questions; numbers must be repeated
  verbatim from input.

### Triggers & API

- `POST /checkins` and the dose-log create route schedule a FastAPI
  background task after commit: run engine → enrich → persist. Existing
  `exists_matching` dedup makes overlapping/rerun triggers idempotent.
- `GET /insights` gains generate-if-stale: if `last_insight_run_at` is null
  or > 6 h old, schedule the same background task; the response returns
  current data immediately (next fetch sees new insights).
- **New** `GET /insights/summary/weekly` — returns the most recent
  **completed** calendar week (Mon–Sun) with ≥ 3 check-ins, computing +
  caching (with the Sonnet call) on first request. Immutable once cached.
  If the narrative call fails: return computed stats with null narrative and
  **do not cache**, so the next open retries. No qualifying week → empty
  response; iOS hides the entry card.
- `record_action("snooze")` gains real semantics per schema above. All other
  existing routes/filters unchanged. Alert-severity push logic untouched.

---

## iOS Design

### Structure (mirrors Protocols/Dashboard conventions)

```
Features/Insights/
├── Models/InsightModels.swift        # UI models, filter enum, InsightRoute
├── ViewModels/
│   ├── InsightsListViewModel.swift
│   ├── InsightDetailViewModel.swift
│   └── WeeklySummaryViewModel.swift
└── Views/
    ├── InsightsListView.swift        # replaces InsightsTab placeholder
    ├── InsightCardView.swift
    ├── InsightDetailView.swift
    └── WeeklySummaryView.swift
```

- `Core/Network/APIModels.swift`: extend `Insight` with optional
  `supportingData` and `snoozedUntil`; add weekly-summary response models.
- `Core/Network/Endpoint.swift`: add `getWeeklySummary` case.
- `MockAPIClient` gets insight + summary fixtures (previews, tests).
- Every new file manually registered in `project.pbxproj` (PBXBuildFile,
  PBXFileReference, group children, Sources phase — known project gotcha).

### Shared state

`InsightsStore` in `Dependencies` (same shape as `protocolStore`): insight
list cache (in-memory, stale-while-revalidate) + derived unread count.
Consumed by the tab badge (`.badge(unreadCount)`), the dashboard insight
card, and the list screen. ViewModels stay thin over the store.

### Screens (exact-match to Figma frames)

**Insights list** (`insights-list.png`):
peppy header + avatar; "Insights" title with unread-count chip; subtitle
"AI-powered insights from your check-ins and protocol data."; horizontal
filter chips All / Trends / Anomalies / Suggestions / Milestones (maps to
`type` query param; `PepSelectionChip`); **AI weekly summary entry card** at
top when a qualifying week exists (week label + weight delta → pushes
summary screen — this is the summary's entry point); **Unread** section;
**Earlier** section (read/acted); rust privacy footer card. Card anatomy:
tinted icon circle, type badge, `New` badge, title, two-line description,
date row, color-coded confidence label, chevron. Pull-to-refresh; fetch on
appear (server generates-if-stale). Empty state: educational
`PepEmptyState` — "peppy is learning your patterns" + what it looks for +
keep-checking-in nudge.

**Insight detail** (`insight-detail.png`):
back chevron + avatar; type chip; large title; timestamp; three-stat card —
Type icon+label / Severity icon+label / **Confidence ring** (custom
`Circle().trim()` view, percentage + High/Medium/Low label);
"Plain-English observation" quote card (LLM-enriched description);
"Why peppy noticed this" card (deterministic explanation) with
**Supporting references** rows from `supporting_data` (static, chevrons
per Figma but non-navigating this slice); blue "Informational only, not
medical advice" banner; fixed bottom action bar — Snooze ("Remind me
later") / Dismiss ("Not helpful") / rust **Accept** ("Helpful insight").
Opening fires mark-read (updates store badge). Actions call API → update
store → pop with standard toast.

**AI weekly summary** (`ai-weekly-summary.png`):
"AI weekly summary" title + "Week of {start} – {end}" subtitle; hero delta
card (arrow icon circle, big signed weight delta, "vs last week",
encouraging line, from→to footer, **Swift Charts sparkline** of the week's
weights); "What changed" 2×2 grid (sleep, dose adherence, HRV, check-ins —
render only metrics that exist; wearable metrics absent until ingestion
lands, grid reflows); "What to watch" bullets; "Questions for your
provider" bullets; explainability footer. States: full / stats-with-no-
narrative (LLM failed; narrative sections hidden) / no qualifying week
(entry card hidden upstream).

### Navigation

Typed `InsightRoute` enum in a `NavigationStack` per app convention.
Cross-tab: dashboard latest-insight card tap switches to Insights tab and
pushes detail, following the existing coordinator pattern used for
Protocols.

### Design tokens

Type-badge/confidence colors map to existing semantic tokens (success green
= Trend/High confidence, warning amber = Anomaly/Medium) plus a soft info
blue added to `Colors.swift` (Figma uses it for sleep/severity chips).
Cream cards, no shadows, pill buttons, weight ceiling 600, sentence case —
per `DESIGN.md` / `APP_DEV.md` §6. Design-QA pass against the three frames
at 853×1844 before completion.

---

## Error Handling & Edge Cases

- **LLM failures never surface.** Insight enrichment falls back to templated
  rule text. Summary returns stats with null narrative and is not cached, so
  the next open retries.
- **iOS network errors:** typed `APIError` → global toast; stale cache stays
  on screen. Action buttons disable in-flight; failures re-enable with toast
  (no optimistic mutations).
- **Sparse data:** rule minimums (≥ 3 dose events, ≥ 4 check-ins) keep rules
  silent instead of emitting junk; summary requires ≥ 3 check-ins in the
  completed week; what-changed grid renders only available metrics.
- **Idempotence:** `exists_matching` dedup + staleness marker make
  overlapping triggers harmless no-ops.

## Privacy

The user's health data — the longitudinal snapshot (check-ins, doses,
protocols, labs, profile) including free-text notes — is sent to the Claude
API for narrative generation (decision above). Therefore:

- List-footer copy changes from "never shared" to honest copy, e.g.:
  *"Your data is used only to generate your insights. It's never sold and
  never used to train AI models."*
- Backend uses the Anthropic API under standard no-training terms. No
  name/email/account identifiers in prompts.
- `ANTHROPIC_API_KEY` via `.env`; missing key = fallback-text mode (fully
  offline dev).

## Testing

**Backend (pytest, existing suite conventions):**
- Per-rule unit tests over seeded fixtures: fires when expected, silent
  below thresholds, correct supporting_data payloads.
- Snooze semantics: hidden while snoozed, resurfaces unread after expiry.
- Weekly summary: window selection (completed Mon–Sun), compute
  correctness, cache hit (one LLM call), failed-narrative-not-cached.
- Narrator: batched enrichment with mocked Anthropic client; malformed
  response → wholesale fallback. No real API calls in tests.
- Trigger wiring: check-in POST schedules generation; stale list fetch
  schedules generation; fresh list fetch does not.

**iOS (XCTest, MockAPIClient pattern):**
- List VM: sectioning (unread/earlier), filter mapping, unread count.
- Detail VM: mark-read on open, action flows update store.
- Summary VM: full / no-narrative / no-week rendering states.

**Manual QA:** checklist handed to Gabriel (no scripted simulator driving),
with a seed-data script so all rule types + summary are visitable.

## Out of Scope (this slice)

- Push notifications for new insights (iOS device registration doesn't
  exist; backend alert-push path untouched).
- Supporting-reference deep links / "what to watch" navigation.
- Sleep→energy correlation rule; wearable-derived metrics (HRV, sleep
  hours).
- Insight search; celery/redis infrastructure; Android.

## Risks / Notes

- Weekly summary quality depends on check-in density; the ≥ 3 check-in gate
  plus honest empty states keep it from feeling fake.
- LLM cost is bounded by design: ≤ 1 Haiku call per generation run (only
  when new candidates exist), ≤ 1 Sonnet call per user-week.
- The dormant celery `run_async` path remains dead code; swap-in point for
  a future queue is the single trigger call site.
