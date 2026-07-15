# Peppy iOS Launch Session Fallback Design

## Objective

Prevent a failed launch-time session restoration from trapping a returning
user on the Peppy logo with a server connection error. When Peppy finds saved
credentials but cannot restore the session, it must immediately show the
returning-user sign-in screen. That screen already includes the path to create
a new account.

## Scope

### Included

- Update launch routing for every failed `/auth/me` restoration attempt.
- Treat the presence of saved credentials as evidence of a known account.
- Clear access and refresh credentials after restoration fails so the same
  failed session is not retried on the next launch.
- Route directly to `authentication(.signIn)` without showing onboarding.
- Preserve onboarding drafts and per-user local draft data.
- Add regression coverage for API errors and raw transport errors.

### Excluded

- Offline authenticated dashboard support.
- User-profile or dashboard caching.
- Changes to login, registration, onboarding, or backend APIs.
- Retrying session restoration in the background.
- Redesigning the logo or authentication screens.

## Current Problem

`RootView` asks `AppFlowCoordinator` to resolve the initial route while the
logo screen is visible. When an access token exists, the coordinator calls
`/auth/me`. A failed request currently leaves the route as `launching` and
stores a launch error, which `LaunchResolutionView` displays beneath the logo.

This behavior incorrectly makes a backend connection a prerequisite for
reaching an interactive signed-out screen. The existing test
`testTemporarySessionFailureKeepsLaunchingWithRetryError` explicitly preserves
the faulty behavior and must be replaced.

## Launch Behavior

Launch resolution keeps its successful and fresh-user behavior:

1. No saved access token follows the existing local signed-out routing rules.
2. A saved token plus a successful `/auth/me` response routes to the dashboard.
3. Any `/auth/me` failure routes to the returning-user sign-in screen.

For step 3, the coordinator performs one contained fallback operation:

- Delete the access token.
- Delete the refresh token.
- Mark `hasKnownAccount` as `true`.
- Reset transient authenticated application state.
- Clear any launch error.
- Clear the authentication back stack.
- Set the route to `authentication(.signIn)`.

The sign-in screen has no back button in this state. Its existing
`Create account.` action remains the route for someone who wants to register
instead.

## Error Handling

Every session-restoration failure uses the same fallback, including:

- Unauthorized or expired credentials that cannot be refreshed.
- Network unavailability and connection refusal.
- Backend 5xx responses.
- Invalid or incompatible response data.
- Raw errors such as `URLError` that are not wrapped as `APIError`.

The failure is not shown on the logo screen because the user can take action
only from authentication. Login and registration continue to display their
own request errors normally.

Clearing credentials is intentional. Preserving them would cause Peppy to
repeat the same restoration request on every subsequent launch. Local
onboarding and user draft data are not credentials and are not removed.

## Testing

`AppFlowCoordinatorTests` will cover these contracts:

- A successful saved session still opens the dashboard.
- An unauthorized saved session clears both tokens, records a known account,
  and opens sign-in without a launch error.
- An `APIError.networkUnavailable` saved-session failure produces the same
  fallback.
- A raw `URLError` produces the same fallback, covering the original
  `Could not connect to the server` symptom.
- A true fresh install with no token still starts onboarding.
- A known signed-out account still starts sign-in.

The network and raw-error regression tests must fail against the current
implementation before production code changes. After the minimal coordinator
change, the focused test target, full iOS test suite, and Debug simulator build
must pass.

## Success Criteria

- Peppy never remains on the logo screen because session restoration failed.
- A returning user with unusable saved credentials immediately sees sign-in.
- The user can reach account creation from the existing sign-in link.
- Returning users are never sent through onboarding because of a backend or
  transport failure.
- Failed credentials do not trigger another restoration attempt on the next
  launch.
