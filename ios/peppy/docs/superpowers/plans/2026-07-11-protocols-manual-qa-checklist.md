# Protocols Workflow — Manual QA Checklist (Plan Task 11, Steps 4–6)

Automated verification already done (2026-07-11): backend migration + 139 backend tests, full iOS suite, clean build — all green. What's left is the hands-on pass below.

**Setup:** start the backend first:

```bash
cd backend && venv/bin/python -m uvicorn app.main:app --reload --port 8001
```

Then run the app on the iPhone 17 Pro simulator (it keeps an authenticated session).

## Step 4 — End-to-end workflow

Protocols tab:

- [ ] Open Protocols tab → list loads with your protocols; pull-to-refresh works.
- [ ] Kill the backend, pull-to-refresh → error/retry state appears, previously loaded rows stay. Restart backend, retry → recovers.
- [ ] Tap a protocol → detail shows status, compounds, dose activity.
- [ ] Create protocol: add name, dates, at least one compound → save → lands on its detail; new row in list.
- [ ] Edit protocol metadata → changes reflected in detail and list.
- [ ] Add compound from detail → appears in detail. Edit it → values prepopulate, save reconciles.
- [ ] Remove a compound (confirmation required). Try removing the *last* compound → blocked/error shown without losing state.
- [ ] Log dose → new entry at top of dose activity.
- [ ] Submit invalid forms (empty name, dose ≤ 0, end before start) → inline validation, draft preserved.
- [ ] Deactivate (confirmation) → status updates. Reactivate → any other active protocol deactivates.
- [ ] Delete (destructive confirmation) → detail pops, row gone from list.

Dashboard (new in Task 10 — cross-tab routing):

- [ ] Dashboard card on a **pending setup** starter → tap "Finish setup" → app switches to Protocols tab and opens starter setup (no longer a sheet). Complete it → activation succeeds.
- [ ] Dashboard card on a **configured** protocol → tap "View protocol" → switches to Protocols tab, opens that protocol's detail.
- [ ] After any successful mutation (log dose, activate, edit) → return to Home → Dashboard reflects it without manual refresh.
- [ ] A *failed* mutation (e.g. backend stopped) → Dashboard does not reload/flicker.
- [ ] Dashboard-originated route replaces the Protocols stack: navigate deep in Protocols, go Home, tap the card → Protocols shows just the routed screen.

## Step 5 — Figma comparison (853x1844 frames)

Reference frames: `~/.claude/projects/-Users-gabri-peppy/figma-frames/`

- [ ] Protocols list ↔ `protocols-list`
- [ ] Protocol detail ↔ `protocol-detail`
- [ ] Create protocol ↔ `create-protocol`
- [ ] Add compound ↔ `add-compound`
- [ ] Log dose ↔ `log-dose`
- [ ] Starter setup ↔ `starter-setup`
- [ ] Dashboard active state ↔ `dashboard-active`

Check hierarchy, spacing, typography, colors, borders, icons, controls, sheets, safe areas.

## Step 6 — Adaptive & accessibility

- [ ] One smaller (e.g. iPhone SE/mini class) and one larger (Pro Max) simulator: no overlap, clipping, or broken scrolling.
- [ ] Large Dynamic Type (Settings → Accessibility): forms and cards reflow, no truncation of critical labels.
- [ ] VoiceOver: icon-only controls have labels; delete/deactivate announce as destructive; sheets/dialogs are reachable.
- [ ] Keyboard: numeric fields don't obscure the save button (keyboard avoidance).

## After QA

If anything above needed a code fix, re-run before closing the plan:

```bash
cd backend && venv/bin/python -m pytest tests/test_dose_log_service.py tests/test_dose_log_routes.py tests/test_protocol_service.py tests/test_protocol_routes.py -q
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project ios/peppy/peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Then tick Task 11 steps 4–7 in `2026-07-08-ios-protocols-workflow.md`.
