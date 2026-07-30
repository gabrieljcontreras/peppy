# Peppy Premium paywall — manual QA checklist

Covers the paywall built in `ios/peppy/docs/superpowers/plans/2026-07-26-peppy-premium-paywall.md`
(Tasks 1–17). Everything below is a "do X, expect Y" line to run by hand on a
simulator or device.

## Before you start

- **StoreKit configuration is already wired.** `peppy.xcscheme` references
  `Peppy.storekit`, so simulator purchases work without extra setup. If purchases
  silently fail, confirm the reference is still present under
  Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration.
- **Resetting purchases:** Xcode → Debug → StoreKit → Manage Transactions, then
  delete the transactions. Do this between runs 5–9 or the app will already be
  premium.
- **Prices come from `Peppy.storekit`:** Yearly `$24.99`, Monthly `$7.99`,
  Lifetime `$139.99`. No price is hardcoded in the views — every figure on screen
  is read from StoreKit, so a mismatch means the configuration file changed, not
  the UI.
- The backend must be running for entitlement sync (`localhost:8001`).

---

## Blockers before App Store submission

1. **Apple signature verification is not implemented.**
   `verify_apple_signature()` in `backend/app/services/subscription.py:46` raises
   `NotImplementedError`. It must be implemented against Apple's root CA chain and
   `APPLE_VERIFY_RECEIPTS` must be `true` in production.
   Current safety net: `decode_apple_transaction` refuses unsigned transactions
   whenever `DEBUG` is false, so an unconfigured *production* deployment fails
   closed rather than granting premium. The exploit requires `DEBUG=true` in
   production — narrower than "any crafted request", but still fatal if it ships
   that way. Verify both flags in the production environment before submitting.

2. **App Store Connect products must exist with exact IDs** from `PremiumPlan`:
   - `com.gabriel.peppy.premium.yearly`
   - `com.gabriel.peppy.premium.monthly`
   - `com.gabriel.peppy.premium.lifetime`

   Yearly and monthly must sit in one subscription group. Family Sharing must be
   enabled on **yearly** and **lifetime** — the card copy promises it
   (`PremiumPlan.subtitleLines`), so shipping without it is a false claim.

3. **The struck-through "was" price is computed, not configured.**
   `SubscriptionService.swift:73` renders it as `product.price * 2`. If the real
   App Store Connect list price is not exactly double the sale price, this shows a
   fabricated original price. Replace it with a configured introductory offer
   before launch. Note the same 50% discount is encoded in three places —
   that computation, `PremiumPlan.badgeText` ("For You 50% OFF"), and the
   `"50% OFF"` literal in `PaywallView.priceRecap` — so any change must update all
   three.

---

## Purchase flow

1. **Fresh install → complete onboarding → register a new account.**
   Expect: the paywall appears automatically after registration. Yearly is
   preselected, the yearly card carries a "For You 50% OFF" badge, and the three
   prices read $24.99 / $7.99 / $139.99.

2. **Look at the headline.**
   Expect: "Peppy" in the rounded system font and "Premium" in coral Fraunces
   italic, sharing a baseline. If "Premium" renders in a generic serif the font
   did not bundle — check Fraunces in Copy Bundle Resources.

3. **Tap the Monthly card.**
   Expect: selection moves to Monthly, the price recap updates to $7.99/month, and
   the discount chip disappears.

4. **Tap the Lifetime card.**
   Expect: "Cancel Anytime" disappears (lifetime is a non-consumable) and the
   legal line switches to one-time-purchase wording.

5. **Tap Continue.**
   Expect: the Apple purchase sheet appears → confirm → the paywall dismisses to
   the dashboard.

6. **Immediately after purchasing, check the unlocked surfaces.**
   Expect: Insights tab shows real insights; the Data export row has no "Premium"
   chip and navigates; the More tab card reads "Peppy Premium" with the plan and
   renewal date.

## Locked state

7. **Delete the app, reinstall, and sign in to the same free account.**
   Expect: Insights tab shows the blurred teaser with "Unlock Insights"; the Data
   export row shows a "Premium" chip and opens the paywall instead of navigating;
   the dashboard shows the locked insight card ("Unlock Peppy Premium to see your
   insights.").
   The blurred teaser must be synthetic shapes — if you can read real insight text
   through the blur, that is a content leak and a bug.

8. **Tap Restore Purchase on the paywall** (as a previously-paid account).
   Expect: entitlement returns without paying again, and the paywall dismisses.

9. **Tap Continue, then cancel the Apple sheet.**
   Expect: no error banner. Cards stay tappable and the paywall stays open — a
   cancelled purchase is not an error.

10. **Sign out, then sign back in as a returning free user.**
    Expect: the paywall does **not** auto-appear (it is registration-only).
    Check-ins and protocols work normally — the free tier is not degraded.

11. **Turn on airplane mode and open the paywall.**
    Expect: "We couldn't load plans. Check your connection and try again." with a
    working Retry button. Turn airplane mode off and tap Retry — plans load.

## Entitlement-resolution edge case

12. **Cold-launch as a paying customer on a slow connection.**
    Expect: no surface ever flashes a lock or a "Premium" chip while the
    entitlement is still resolving. `PremiumGate.showsLock` returns false for
    `.unknown`, and the More tab's upsell card is hidden entirely until
    `isResolved`. A flash here means a gate is checking `!isPremium` instead of
    going through `PremiumGate`.

## Known gap (not a blocker)

- Pull-to-refresh on a **locked** Insights tab still fires `/insights` and takes a
  402, surfacing an error toast that restates what the lock already says. No data
  is exposed. `.task` is guarded; `.refreshable` is not.
