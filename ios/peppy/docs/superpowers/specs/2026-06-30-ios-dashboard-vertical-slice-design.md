# Peppy iOS Dashboard Vertical Slice Design

## Objective

Build the first real post-auth iOS MVP slice around the Home dashboard. The slice
must make Peppy's core value clear: help a user understand what they are taking,
log how they are responding, and see enough trend/context feedback to keep using
the app.

This is a dashboard-first vertical slice with real backend support. "MVP" means a
narrow surface area, not a disposable or weak implementation. The backend must be
durable, validated, service-oriented, and ready to scale without rewriting the
first profile and dashboard contracts.

## Source Context

- Existing iOS app has native launch, pre-auth onboarding, permission screens,
  auth handoff, local onboarding draft persistence, and a temporary tab shell.
- Existing backend has auth, protocols, check-ins, labs, insights, wearables,
  notifications, waitlist, and feedback modules.
- Existing iOS `BACKEND.md` defines a proposed onboarding/profile contract that
  should become the foundation for this slice.
- Figma source: `/Users/gabrielcontreras/Downloads/Peppy IOS.fig`.
- Not every Figma screen is in scope. Use Figma as the visual source and product
  language, not as a requirement to implement every frame.

## Scope

### Included

- Persist authenticated onboarding/profile data on the backend.
- Attach the anonymous local onboarding draft after registration or sign-in.
- Derive a pending starter protocol from onboarding peptide selections.
- Open the dashboard immediately after authentication.
- Show a clear `Finish your starter protocol` dashboard card when setup is
  pending.
- Allow the user to finish starter protocol setup by confirming health-critical
  fields: dose, frequency, route, and start date.
- Provide a full daily check-in path for weight, energy, mood, symptoms, and
  notes.
- Show a simple response snapshot using weight trend and recent check-in state.
- Show lightweight AI insight utility with useful empty states.
- Show connected health/labs utility with simple status and add/connect actions.
- Add enough backend dashboard summary support for the iOS dashboard to avoid
  drifting from real data contracts.

### Excluded

- Full labs management depth.
- Full connected-health ingestion or wearable OAuth depth.
- Full insight generation UX and complex explainability.
- Automatic protocol activation from onboarding data.
- Dose, frequency, route, or start-date collection inside onboarding. This is a
  future improvement.
- Paywall, subscriptions, StoreKit, and social authentication.
- Building every Figma screen.

## Product Principle

Few surfaces, real workflows, no fake depth.

The first slice should feel useful without pretending the whole product is
finished. Protocol tracking and daily check-ins get the most depth. Insights,
connected health, and labs provide simple utility that communicates Peppy's
direction while staying honest about available data.

## Architecture

The slice introduces three bounded areas:

1. Profile/onboarding backend persistence.
2. Pending starter protocol state derived from onboarding.
3. Dashboard MVP summary and iOS presentation.

### iOS

Use the existing SwiftUI and dependency structure:

- Keep networking behind `APIClientProtocol`.
- Add new API models and endpoints in `Core/Network`.
- Add dashboard UI and state under `Features/Dashboard`.
- Add or extend protocol setup UI under `Features/Protocols`.
- Add or extend check-in UI under `Features/Checkins` or the existing local
  feature naming pattern chosen during implementation.
- Reuse `Dependencies`, `AppFlowCoordinator`, `OnboardingStoreProtocol`, and
  existing Peppy design components before adding new primitives.
- Keep mock API support for previews, tests, and offline visual iteration.

### Backend

Follow the existing FastAPI structure:

- SQLAlchemy models under `app/models`.
- Pydantic schemas under `app/api/schemas`.
- Business rules in service classes under `app/services`.
- Route modules under `app/api/routes`.
- Alembic migrations for schema changes.

Backend quality requirements:

- Validate all profile, protocol, and dashboard summary inputs.
- Keep account/user ownership checks at every authenticated boundary.
- Use explicit error responses for validation, missing profile, conflicts, and
  duplicate attach attempts.
- Keep schema versioning in the onboarding profile from the first migration.
- Avoid putting raw health values in ordinary logs.
- Keep dashboard summary aggregation read-only and side-effect free.
- Add tests for services and routes, not only happy-path serialization.

## User Flow

Post-auth flow:

```text
Registration or sign-in succeeds
-> iOS attaches the anonymous onboarding draft to the authenticated user
-> Backend persists onboarding profile
-> Backend creates or updates a pending starter protocol when profile peptides exist
-> App opens Home dashboard immediately
```

The dashboard is still the first post-auth destination. If starter protocol
setup is incomplete, the dashboard shows a prominent card rather than blocking
entry into the app.

## Dashboard Screen

The Home dashboard should match the tone and density of the Figma dashboard
frames: warm background, peppy wordmark treatment, compact useful cards, clear
red/coral actions, and bottom tab navigation.

Dashboard content:

- Header with greeting and the "your protocol, understood" tone.
- Pending starter protocol card when onboarding selected peptides but setup is
  incomplete.
- Active protocol card once setup is confirmed.
- Today card showing whether a check-in has been logged.
- Check-in quick action for weight, energy, mood, symptoms, and notes.
- Response snapshot with weight trend and recent signal.
- Lightweight insight card with latest insight or a truthful empty state.
- Connected context card for Apple Health/labs status.
- Bottom tabs: Home, Check-in, Protocols, Insights, More.

Empty states:

- No onboarding peptides: show `Create your first protocol`.
- No check-ins: explain that trends and insights need a few check-ins.
- No labs or connected health: show simple add/connect actions.
- Dashboard summary failure: show local/profile-derived fallback cards and a
  retry affordance.

## Starter Protocol

Onboarding-selected peptides create a pending starter protocol candidate. The
candidate may prefill:

- Protocol name.
- Peptide names.
- User goals and context for copy or card ranking.

The system must not infer:

- Dose.
- Frequency.
- Administration route.
- Start date.

The user must confirm those fields before the protocol becomes active. This is a
safety and data-integrity requirement, not just UX preference.

Future onboarding can collect dose, frequency, route, and start date to reduce
this follow-up step. That future collection should still require confirmation
before activation.

## Backend Data Design

### Onboarding Profile

Add an `onboarding_profiles` table keyed by authenticated `user_id`. It should
store:

- `schema_version`.
- Baseline fields from onboarding: age, height, weight, preferred units.
- Selected canonical peptides and custom peptides.
- Other medications.
- Workout frequency.
- Goals and custom goal.
- HealthKit and notification onboarding choices/outcomes.
- `created_at` and `updated_at`.

Use normalized storage for health-related measurements, matching the existing
`BACKEND.md` direction.

### Starter Protocol State

Prefer extending the existing protocol system over creating a parallel starter
protocol model. Add a setup status such as:

```text
pending_setup
active
inactive
```

If the current protocol model cannot absorb this cleanly, introduce the smallest
compatible status field and service rules needed for:

- creating a pending starter protocol from profile data,
- preventing activation until required fields are complete,
- showing pending or active state in dashboard summary,
- preserving historical protocol behavior.

### Dashboard Summary

Add a read-oriented dashboard summary endpoint:

```text
GET /api/v1/dashboard/summary
```

The response should include:

- Profile status.
- Pending or active protocol summary.
- Today check-in status.
- Recent check-in summary.
- Weight trend points.
- Latest insight summary.
- Connected context status for HealthKit/labs/wearables where available.

This endpoint should aggregate existing data. It should not create protocols,
generate insights, or mutate user state.

## API Endpoints

Implement or finalize:

```text
GET   /api/v1/profile/onboarding
PUT   /api/v1/profile/onboarding
PATCH /api/v1/profile/onboarding
POST  /api/v1/profile/onboarding/attach
GET   /api/v1/dashboard/summary
```

Attach behavior:

- iOS sends the local draft after authentication.
- The backend creates or updates the user profile.
- The backend creates a pending starter protocol only when profile peptide data
  exists and no active/pending starter protocol already covers it.
- Repeated attach attempts must not create duplicates.
- If attach fails, iOS keeps the local draft and exposes retry.

The profile endpoints should remain useful beyond this slice. They are not just
dashboard helpers.

## Error Handling

- Profile attach failure after auth: keep local draft, open dashboard, and show a
  retryable `Finish syncing setup` state.
- Dashboard summary failure: use cached/local profile-derived cards when
  possible and provide retry.
- Protocol activation missing dose/frequency/route/start date: block activation
  with field-level validation.
- No onboarding peptides: show `Create your first protocol`.
- No check-ins: use empty trend and insight states.
- HealthKit unavailable or not connected: keep connected context card useful as
  status plus action.
- Backend conflict or duplicate attach: return deterministic errors and avoid
  duplicate profile/protocol records.

## Testing

### Backend

Cover:

- Onboarding profile create/read/update/attach.
- Profile validation ranges, enum values, and schema version handling.
- Attach retry behavior does not duplicate pending starter protocols.
- Starter protocol generation from selected peptides.
- Starter protocol activation validation.
- Dashboard summary with:
  - no profile,
  - profile but no peptides,
  - pending starter protocol,
  - active protocol,
  - no check-ins,
  - check-ins with weight trend,
  - latest insight,
  - empty connected context.

### iOS

Cover:

- Dashboard view model loading, loaded, failed, and retry states.
- Attach-failed fallback behavior after auth.
- Pending starter protocol card state.
- No-onboarding-peptides create-protocol state.
- Protocol setup validation for required health-critical fields.
- Check-in logging state and empty trend/insight states.
- Mock API preview data for Figma-style visual iteration.

Verification should include the iOS test suite, backend test suite, generic iOS
simulator build, and screenshot review against the relevant Figma dashboard and
setup frames.

## Acceptance Criteria

- Authenticated users land on the dashboard immediately.
- Onboarding data is persisted to the backend profile after auth.
- Failed profile attach does not block dashboard entry or destroy the local
  draft.
- Selected onboarding peptides create a pending starter protocol candidate.
- The starter protocol cannot become active until the user confirms dose,
  frequency, route, and start date.
- The dashboard shows useful states for pending setup, active protocol, check-in
  status, trend, lightweight insight, and connected context.
- Backend APIs are validated, tested, and structured for future scale.
- iOS uses real API contracts with mock support rather than hardcoded dashboard
  content.
- Figma visual language is followed for the implemented screens without
  expanding scope to every Figma frame.
