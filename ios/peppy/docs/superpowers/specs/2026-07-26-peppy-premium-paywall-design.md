# Peppy Premium Paywall and Entitlement Gating

## Problem

Peppy has no monetization. `AppFlowCoordinator` carries a vestigial
`.futurePaywall` route that renders a bare `Color.pepBackground` and
immediately calls `advancePastFuturePaywall()` — a placeholder from the
original onboarding-auth work that never became a real screen. Every feature
in the app is free to every account, and there is no notion of an entitlement
anywhere in the iOS client or the FastAPI backend.

## Goal

Ship a working Peppy Premium purchase flow:

1. A paywall screen shown once after a new account is created, taking direct
   visual influence from `~/Downloads/peppy_payment.png` without copying it
   pixel-for-pixel, rendered in Peppy's existing design system.
2. Real payments through StoreKit 2 — Apple's purchase sheet, three products,
   restore support — working end to end in the simulator today via a
   `.storekit` configuration file, and in production once the same product IDs
   exist in App Store Connect.
3. Premium enforcement on both client and server. Free accounts keep Check-ins
   and Protocols. Insights and Data export are locked, and tapping either
   presents the same paywall.

Visual reference: `~/Downloads/peppy_payment.png`.

## Non-goals

- Android and web paywalls. iOS only.
- App Store Server Notifications V2 (renewal/refund/cancellation webhooks).
  The design leaves room for them but this work does not implement them.
- Promotional offers, free trials, or referral codes.
- Migrating or grandfathering existing accounts. Every existing user becomes
  `free` when the migration runs; this is pre-launch so no one is affected.

## Plans and pricing

| Plan | Product ID | Price | Kind |
|---|---|---|---|
| Yearly | `com.gabriel.peppy.premium.yearly` | $24.99/year, was $49.99, "For You 50% OFF" | Auto-renewable, 1 year |
| Monthly | `com.gabriel.peppy.premium.monthly` | $7.99/month | Auto-renewable, 1 month |
| Lifetime | `com.gabriel.peppy.premium.lifetime` | $139.99 | Non-consumable |

Yearly is preselected. The two subscriptions share one subscription group so
StoreKit handles upgrade/downgrade proration; Lifetime sits outside it.

Prices displayed in the UI always come from StoreKit's localized
`Product.displayPrice`. The table above is the `.storekit` configuration and
the App Store Connect setup, never a hardcoded string in a view. The struck
`$49.99` comes from the yearly product's configured introductory-offer base
price; if products fail to load, the paywall shows an error state with a retry
rather than fabricated prices.

## Typography: the "Peppy Premium" wordmark

The headline is two faces on one line, mirroring the web site's headline
treatment (`web/src/components/Sections.tsx`, `<em className="font-serif
italic font-medium text-rust-500">`):

- **"Peppy"** — the app's existing rounded system face,
  `.system(size: 40, weight: .bold, design: .rounded)` in `pepTextPrimary`.
- **"Premium"** — Fraunces Italic at weight 500, the site's `--font-fraunces`
  accent face, in `pepPrimary`.

Fraunces is not currently bundled in the iOS app; no font files exist under
`ios/`. It ships under the SIL Open Font License, so it can be bundled.

**Bundling approach.** Add `Fraunces-Italic[SOFT,WONK,opsz,wght].ttf` (the
variable italic, 415 KB, from `google/fonts/ofl/fraunces`) to
`ios/peppy/Design/Fonts/`, renamed `Fraunces-Italic.ttf` for sanity, alongside
`OFL.txt`. The target uses `GENERATE_INFOPLIST_FILE = YES` and has no
`Info.plist` file, so rather than fight `INFOPLIST_KEY_UIAppFonts`, the font is
**registered at runtime** with `CTFontManagerRegisterFontsForURL` on first
access. The file still needs to be a bundle resource, which does require
`project.pbxproj` registration (Xcode's "Add Files", not hand-editing).

**Resolution with fallback.** Variable-font named instances do not always
resolve by PostScript name on iOS. `PeppyFonts.premiumItalic(size:)` therefore:

1. Registers the font file once (idempotent, guarded by a `once` token).
2. Builds a `UIFontDescriptor` for family `Fraunces` with the
   `kCTFontVariationAttribute` axis dictionary set to `wght: 500` and the
   italic trait, matching the site's `font-medium italic` at default `SOFT`/
   `WONK` of 0.
3. Falls back to `.system(size:, weight: .medium, design: .serif).italic()` if
   registration or descriptor resolution fails, so the screen never renders
   with a missing glyph or a silently wrong face.

This lives in `Design/Typography.swift` as `Font.peppyPremiumItalic(size:)`
plus the `PeppyFonts` helper, so any future screen can reuse the accent face.

## Architecture

```
StoreKit purchase / restore / Transaction.updates
                    │ signed JWS transaction
                    ▼
            EntitlementStore  ──────►  POST /api/v1/subscription/apple
         (@Observable, client truth)              │
                    │                             ▼
                    │                   users.subscription_* columns
                    ▼                             │
        Paywall + locked UI states                ▼
                                        RequirePremium → 402 on
                                        /insights/* and /profile/export
```

StoreKit is the client's source of truth so the UI unlocks instantly and works
offline. The backend is the authority for data access, so a free account
cannot reach paid data by calling the API directly.

### New iOS files

`ios/peppy/Core/Subscriptions/`

| File | Responsibility |
|---|---|
| `PremiumPlan.swift` | `enum PremiumPlan { case yearly, monthly, lifetime }` — product ID, display title, subtitle, badge text, sort order. Pure data, no StoreKit import. |
| `PremiumEntitlement.swift` | `enum PremiumEntitlement { case unknown, free, premium(plan: PremiumPlan?, expires: Date?) }` with `var isPremium: Bool`. `.unknown` is the pre-resolution state and is treated as **not** premium for gating but suppresses the upsell UI, so nothing flashes "locked" during launch. |
| `SubscriptionService.swift` | `protocol SubscriptionServicing` — `loadProducts()`, `purchase(_:)`, `restore()`, `currentEntitlement()`, `transactionUpdates` stream. Live `StoreKitSubscriptionService` wraps StoreKit 2. |
| `MockSubscriptionService.swift` | Deterministic double for previews and tests: scriptable products, purchase outcomes (success/cancelled/pending/failed), and entitlement. |
| `EntitlementStore.swift` | `@MainActor @Observable`. Owns `entitlement`, starts the `Transaction.updates` listener at app launch, reconciles StoreKit against `GET /api/v1/subscription` on launch and after login, and pushes new transactions to the backend. Exposes `refresh()`, `apply(_ transaction:)`, and `markFreeFromServer()` for the 402 path. |

`ios/peppy/Features/Paywall/`

| File | Responsibility |
|---|---|
| `ViewModels/PaywallViewModel.swift` | Product loading, plan selection, purchase/restore orchestration, `PaywallState` (`loading`/`ready`/`purchasing`/`failed`), error copy. |
| `Views/PaywallView.swift` | The screen. |
| `Views/PaywallPlanCard.swift` | One selectable plan row. |
| `Views/PremiumLockedOverlay.swift` | Reusable blurred-teaser lock used by Insights and the dashboard card. |
| `Views/PremiumUpsellCard.swift` | The Settings row / status card. |

### Changed iOS files

- `App/Dependencies.swift` — construct and inject `subscriptionService` and
  `entitlementStore` in both `live()` and `mock()`; reset the entitlement in
  `resetSessionData` and refresh it in `prepareSessionData`.
- `App/AppFlowCoordinator.swift` — delete `.futurePaywall` and
  `advancePastFuturePaywall()`; `continueFromReadySummary()` now goes straight
  to `.authentication(.register)`. Add `.paywall` as a post-auth route.
  `didAuthenticate(user:)` gains an `isNewAccount: Bool = false` parameter;
  when true the route becomes `.paywall` instead of `.dashboard`. Add
  `dismissPaywall()` → `.dashboard`.
- `App/RootView.swift` — render `PaywallView` for `.paywall`; drop the
  pass-through placeholder.
- `Features/Auth/Views/RegisterView.swift` — pass `isNewAccount: true`.
- `Core/Network/APIError.swift` — add `.paymentRequired`, mapped from HTTP 402,
  with user message "Peppy Premium is required for this."
- `Core/Network/APIClient.swift` — map 402 → `.paymentRequired`.
- `Core/Network/Endpoint.swift` — `getSubscription`, `syncAppleTransaction(_:)`.
- `Features/Insights/Views/InsightsListView.swift` — wrap the content in the
  locked overlay when not premium.
- `Features/Dashboard/Views/DashboardView.swift` — locked upsell variant of the
  insight card.
- `Features/Settings/Views/SettingsRootView.swift` — `PremiumUpsellCard` above
  the profile card; intercept the `.dataExport` route for free users.
- `Features/Settings/Views/SettingsComponents.swift` — lock chip affordance on
  a gated row.

### Backend changes

**Migration** (`backend/alembic/versions/`) adding to `users`:

| Column | Type | Notes |
|---|---|---|
| `subscription_tier` | `String(20)`, not null, default/server default `"free"` | `free` \| `premium` |
| `subscription_product_id` | `String(100)`, nullable | |
| `subscription_expires_at` | `DateTime(timezone=True)`, nullable | Null for lifetime |
| `subscription_original_transaction_id` | `String(100)`, nullable, indexed | Apple's stable per-user purchase ID |
| `subscription_updated_at` | `DateTime(timezone=True)`, nullable | Last sync |

Columns on `users` rather than a separate table, matching the existing style
(`last_insight_run_at` already lives there) and keeping the entitlement check a
single attribute read on an object the request already loaded.

**`app/services/subscription.py`**
- `decode_apple_transaction(jws)` — splits the JWS, base64url-decodes the
  payload, and validates `bundleId == settings.apple_bundle_id`, `productId` in
  the known set, and `type`.
- `verify_apple_signature(jws)` — full x5c chain validation against Apple's
  root CA. **Gated behind `settings.apple_verify_receipts`, which defaults to
  `False` in debug and must be `True` in production.** Shipping without it
  would let a crafted request grant premium, so the service logs a loud warning
  when the flag is off and the plan carries this as an explicit pre-launch
  blocker rather than a silent gap.
- `apply_transaction(db, user, payload)` — computes tier and expiry
  (`expiresDate` for subscriptions, permanent for the lifetime non-consumable),
  writes the columns, returns the entitlement.
- `current_entitlement(user)` — returns `free` when
  `subscription_expires_at` is in the past, so a lapsed subscription degrades
  without needing a webhook.

**`app/api/routes/subscription.py`** (registered in `main.py` under
`/api/v1/subscription`)
- `GET ""` → `SubscriptionResponse { tier, product_id, expires_at, is_premium }`
- `POST "/apple"` → body `{ signed_transaction: str }`, returns the same shape.
  400 on a malformed or foreign-bundle transaction.

**`app/api/deps.py`** — `require_premium(current_user)` raising
`HTTPException(402, detail="premium_required")`, exported as
`PremiumUser = Annotated[User, Depends(require_premium)]`.

**Gated routes** — every route in `insights.py` (list, get, mark read, action,
generate, weekly summary) swaps `CurrentUser` for `PremiumUser`, as does
`POST /profile/export` in `profile.py`.

**`dashboard.py`** — `GET /dashboard/summary` returns a null `insight` block for
free users. Without this, paid insight titles leak into a free surface and the
gating is cosmetic.

## Paywall screen

Full-screen, cream `pepBackground`, scrollable so it survives large Dynamic
Type. Top to bottom:

1. **Top bar** — `xmark` button top-left (44pt tap target, `pepTextPrimary`),
   `PeppyLogo(showsWordmark: true)` centered.
2. **Headline** — "Peppy Premium" as described in Typography above, centered,
   the two faces baseline-aligned in a single `HStack(alignment: .firstTextBaseline)`.
3. **Feature run** — centered, `pepTextSecondary`, ~17pt, line spacing 6:
   "Insights, Weekly Summaries, Trend Charts, Confidence Scores, Symptom
   Patterns, Data Export."

   Every item is a feature that ships today and is actually gated by this
   work: insights and their detail charts, `WeeklySummaryView`, `ConfidenceRing`,
   the symptom-after-dose rule family, and `DataExportView`. The reference's
   list (Workout Suggestions, Mirror Tracking, RPE) belongs to a different
   product. Labs and wearables are deliberately excluded — they exist as
   backend endpoints but have no iOS screen, so naming them would advertise
   something a buyer cannot use. "Full History" is excluded for the same
   reason: no history cap exists for free accounts and this work does not add
   one.
4. **Plan cards** — `PaywallPlanCard` × 3, 14pt gap, `CornerRadius.lg`:
   - Selected: `pepPrimaryMuted` fill, 1.5pt `pepPrimary` border, filled coral
     circle with a white check.
   - Unselected: `pepSurface` fill, `pepCardShadow()`, hollow `pepBorder` ring.
   - Left: title (17pt semibold), optional subtitle lines in
     `pepTextSecondary`. Right: price, plus struck-through original beneath it
     for yearly.
   - The "For You 50% OFF" badge is a coral capsule anchored to the yearly
     card's top-right via `.overlay(alignment: .topTrailing)` with a negative
     offset so it rides the border, as in the reference.
   - Whole card is one `Button` with `.accessibilityAddTraits(.isSelected)`
     when active; the three form a radio group.
5. **Restore Purchase** — centered text button, dotted underline drawn as a
   1pt dashed `Rectangle` overlay.
6. **Price recap** — struck original, current price, coral "50% OFF" chip.
   Reflects the selected plan, so it changes with selection.
7. **Continue** — full-width coral capsule. `PepButton`'s `.primary` style is
   `pepInk`, not coral, so the paywall's CTA is a local
   `PaywallPrimaryButton` using `pepPrimary` rather than mutating the shared
   `PepButtonStyle` and changing every other primary button in the app.
   Shows a spinner and disables during purchase.
8. **Cancel Anytime** — coral 15pt, centered. Hidden when Lifetime is selected,
   where it would be untrue.
9. **Legal** — small `pepTextTertiary` line with Terms and Privacy links, plus
   auto-renewal disclosure. Required for App Store review; absent from the
   reference but non-optional to ship.

The reference's bottom "← Back" is dropped. Presented after registration there
is nowhere to go back to, and the X already dismisses.

**States.** Loading products (skeleton cards, disabled CTA) · ready ·
purchasing · failed to load (message + Retry) · purchase failed (inline error,
cards stay interactive) · cancelled (silent return to ready) · pending
(Ask-to-Buy — "Waiting for approval" message, dismissible) · success (dismisses
to dashboard or unlocks the feature behind it).

## Gating surfaces

| Surface | Free behavior |
|---|---|
| Post-registration | Route to `.paywall` before `.dashboard`. X or a completed purchase continues to the dashboard. Sign-in does not re-show it. |
| Insights tab | `PremiumLockedOverlay`: three synthetic skeleton cards under `.blur(radius: 8)` with a lock badge and "Unlock Insights" → paywall sheet. The blurred cards are **placeholder shapes, never real insight data**, so nothing paid leaks through the teaser. `.allowsHitTesting(false)` and `.accessibilityHidden(true)` on the blurred layer. |
| Dashboard insight card | Locked upsell card → paywall sheet. |
| Data export row | Lock chip on the row; tap presents the paywall instead of pushing `DataExportView`. |
| More tab | `PremiumUpsellCard` above the profile card. Free: "Unlock Peppy Premium" + benefit line → paywall. Premium: plan name, renewal or "Lifetime", and a Manage Subscription link to `showManageSubscriptions`. |
| Everything else | Check-ins, Protocols, Profile, Notifications, Security, Help, About, Legal stay free. |

The paywall is dismissible everywhere. Free accounts are a real tier, not a
lockout.

## Error handling

- **402 from any endpoint** → `EntitlementStore.markFreeFromServer()` then
  present the paywall. This is the self-healing path when StoreKit and the
  server disagree (expired subscription, restored device, revoked purchase);
  the user sees the paywall, not a generic red toast.
- **Backend sync fails after a successful purchase** → StoreKit already
  finished the transaction, so the client is premium locally. `EntitlementStore`
  retains the unsynced JWS and retries on next launch and next foreground.
  The purchase is never lost because a network call failed.
- **Products fail to load** → error state with Retry. No fake prices.
- **`Transaction.updates` while backgrounded** → the listener starts at app
  launch and lives for the process lifetime, so renewals and Ask-to-Buy
  approvals are picked up whenever they arrive.
- **Unverified StoreKit transaction** (`VerificationResult.unverified`) → treated
  as a failed purchase; never grants entitlement.

## Testing

**iOS unit tests** (`peppyTests/`)
- `EntitlementStoreTests` — StoreKit/server reconciliation, 402 downgrade,
  unsynced-transaction retry, expiry, session reset on logout.
- `PaywallViewModelTests` — product load ordering, default yearly selection,
  price recap follows selection, each purchase outcome, restore with and
  without prior purchase.
- `PremiumGatingTests` — locked vs unlocked resolution for each gated surface,
  and `.unknown` not rendering the upsell.
- `AppFlowCoordinatorTests` — updated: `.futurePaywall` gone, registration
  routes to `.paywall`, sign-in does not, dismissal reaches `.dashboard`.

**Backend tests** (`backend/tests/`)
- `test_subscription.py` — transaction decode, bundle/product validation,
  tier and expiry computation, lifetime never expiring, lapsed subscription
  reading as free, `GET`/`POST` contracts.
- Gating assertions: free account gets 402 from each insights route and from
  `POST /profile/export`; premium gets 200; dashboard summary nulls the insight
  block for free users.

**Manual QA** — a checklist under `docs/superpowers/plans/` covering the
simulator purchase of each plan against the `.storekit` file, restore on a
second launch, cancellation, Ask-to-Buy, and each locked surface. Per the
project's standing preference, simulator UI verification is Gabriel's, not
driven from here.

## Risks

1. **Apple signature verification is off by default.** The single most
   important pre-launch task in this design. Documented as a blocker in the
   plan, not a nice-to-have.
2. **`project.pbxproj` edits.** The font file, `.storekit` file, and new source
   directories all need target registration. Known project gotcha; do it
   through Xcode where possible and verify with a clean build.
3. **Variable-font instance resolution.** Mitigated by the descriptor-plus-
   fallback strategy above, but the rendered weight should be eyeballed against
   the web site before sign-off.
4. **No renewal webhooks.** A subscription cancelled mid-term stays premium in
   the database until `subscription_expires_at` passes. Acceptable — the expiry
   check makes it self-correcting — but real-time revocation needs App Store
   Server Notifications V2 later.
