# Insights AI — Manual QA Checklist

Hand-run checklist for the Insights slice (list, detail, AI weekly summary,
cross-tab wiring). Automated coverage is green (backend 276 pytest, full
`xcodebuild test`); this covers what only a human on the simulator can verify.

## Setup

```bash
# 1. Backend (from repo root)
cd backend && venv/bin/alembic upgrade head
venv/bin/python -m scripts.seed_insights_demo     # prints the demo credentials
venv/bin/uvicorn app.main:app --reload

# 2. iOS: run the peppy scheme on iPhone 17 Pro, log in as
#    insights-demo@peppy.dev / peppy-demo-1
```

The seed produces 5 insights (2 trends, 1 anomaly/warning, 2 milestones) and a
qualifying weekly summary (hero delta −0.35 kg, 7 weight points, 4 metrics).
Re-running the script resets the demo user to this exact state.

## Functional checklist

### Insights list
- [ ] Fresh user (register a new account, no data): Insights tab shows the
      educational empty state — sparkles icon, "peppy is learning your patterns",
      the "first insight usually appears within a week" copy. No filter results,
      no summary card.
- [ ] Demo user: list shows the Unread section with 5 cards, each with type
      badge, "New" badge, 2-line description, date • time, "Confidence: …" in
      its semantic color.
- [ ] Event trigger: submit a fresh check-in from the Check-in tab, then revisit
      Insights — the list refetch (generate-if-stale on the server) completes
      without error; with new qualifying data a new insight appears.
- [ ] Pull-to-refresh spins and completes; list stays stable when nothing changed.
- [ ] Filter chips: "Anomalies" leaves only the nausea card; "Milestones" leaves
      the streak + 4-weeks cards; "All" restores everything. Chip shows the
      checkmark when selected.
- [ ] Unread count chip next to the title matches the tab badge; both count
      down as you open details (opening marks read) and the chip disappears at 0.
- [ ] Privacy footer shows the exact copy: "Your data is used only to generate
      your insights. It's never sold and never used to train AI models."

### Insight detail
- [ ] Opening a card marks it read (back → "New" badge gone, moved to Earlier
      after refresh).
- [ ] Stat card: type icon/tint, severity icon/tint, confidence ring percentage
      matches the list's confidence label (e.g. 95% → High/green, 90% → High).
- [ ] Evidence rows under "Why peppy noticed this" match the numbers in the
      card description (e.g. nausea "4 of last 4 dose days" ↔ description).
- [ ] Snooze: toast "Insight snoozed", pops back, card gone from list.
      Resurface check — backdate the snooze and force-refresh:
      `sqlite3 backend/peppy.db "UPDATE insights SET snoozed_until = '2026-07-01 00:00:00' WHERE snoozed_until IS NOT NULL;"`
      → pull-to-refresh → card reappears as unread.
- [ ] Dismiss: toast "Insight dismissed", card gone and stays gone.
- [ ] Accept: toast "Marked as helpful", card remains in Earlier.
- [ ] Action buttons disable while a request is in flight; a failed action
      (kill the backend, tap Accept) shows the error toast and does NOT pop.

### AI weekly summary
- [ ] Summary entry card on the list (sparkle icon, week range) opens the
      summary screen.
- [ ] Hero: −0.4 kg-style signed delta, down-right arrow, "From X kg to Y kg"
      footer, sparkline sloping down.
- [ ] No-key state (ANTHROPIC_API_KEY unset): no narrative sentence, no What to
      watch / provider questions cards — layout closes up without gaps.
- [ ] With ANTHROPIC_API_KEY exported before uvicorn + fresh seed: narrative
      sentence renders in the hero; watch items and provider questions appear.
- [ ] Metric grid shows only the keys the backend sent, positive values green.

### Cross-tab
- [ ] Dashboard insight card (Home) shows the newest insight title + chevron;
      tap → lands directly on that insight's detail on the Insights tab; back
      goes to the Insights list (replace-stack semantics, same as protocol card).
- [ ] Dashboard card with no insight (fresh user) → lands on the Insights list root.
- [ ] Tab badge shows unread count, hides at 0, survives tab switches.

### VoiceOver (all three screens)
- [ ] List: cards read title + description; filter chips announce
      selected/not selected; unread chip and badges are announced.
- [ ] Detail: stat columns, evidence rows, and the three action buttons are
      reachable and labeled; disabled state announced while acting.
- [ ] Summary: hero delta, metric tiles, watch/question bullets all readable;
      sparkline is decorative (value carried by the hero text).

## Design QA vs Figma frames

Compare side-by-side against the 853×1844 frames in
`~/.claude/projects/-Users-gabri-peppy/figma-frames/`:
`insights-list.png`, `insight-detail.png`, `ai-weekly-summary.png`,
`dashboard-with-insight.png`.

- [ ] **Spacing scale**: 20pt horizontal screen margins, 18pt section rhythm,
      cards use the standard PepCard padding — nothing hugging the edges.
- [ ] **Badge colors per type**: trend→green, anomaly→amber, suggestion→blue,
      milestone→neutral; "New" badge rust. Icon circles use the muted tint of
      the same pair.
- [ ] **Confidence ring**: percentage text matches `confidence`, ring color
      green ≥75 / amber ≥50 / gray below; ring starts at 12 o'clock.
- [ ] **Section order (list)**: header → title+chip → subtitle → filter chips →
      weekly summary card → Unread → Earlier → privacy footer.
- [ ] **Section order (detail)**: badge → title → timestamp → stat card →
      observation → why/evidence → disclaimer → pinned action bar.
- [ ] **Action bar layout**: Snooze and Dismiss bordered white cards, Accept
      filled rust with white text; subtitles under each label; bar pinned above
      the home indicator and doesn't overlap scroll content.
- [ ] **Hero card composition (summary)**: rust-muted card, arrow circle left,
      34pt delta, sparkline right (~120×70), narrative below, divider, footer row.
- [ ] **Grid reflow**: temporarily reseed with fewer metrics (or edit the
      cached weekly_summaries payload) — the What changed grid reflows 2-up
      without empty tiles; odd counts leave the last cell blank, not stretched.
- [ ] **Privacy/disclaimer banners**: info-muted background, white "i" in blue
      circle, copy matches frame.

Known accepted deviations (per plan): filter chips show a checkmark when
selected (PepSelectionChip behavior); evidence-row and watch-item chevrons are
rendered but non-navigating this slice; dashboard insight card keeps the
existing compact layout plus chevron.
