# Peppy Mobile App Development Plan

**Created:** 2026-05-17  
**Status:** Planning  
**Platforms:** Android (Kotlin) first, then iOS (Swift)

---

## 1. Overview

This document tracks the mobile app development for Peppy MVP. The backend API is complete (312 tests, all endpoints ready). We're building native apps that consume this API.

### Goals
- Native iOS app (Swift, iOS 16+)
- Native Android app (Kotlin, API 26+)
- Feature parity between platforms
- Clean, health-focused UI
- Offline-capable where practical

### Backend Integration
- Base URL (dev): `http://localhost:8000/api/v1`
- Auth: JWT (access token in Authorization header, refresh token for renewal)
- Full API docs: `http://localhost:8000/docs` (when backend running)

### Development Environment
Xcode (macOS-only) is required for iOS development. For Windows development:

| Service | Cost | Notes |
|---------|------|-------|
| **MacinCloud** | ~$30/mo | Recommended. Dedicated cloud Mac via browser/Jump Desktop |
| **Scaleway Mac Mini** | ~€0.10/hr | Hourly billing, SSH + VNC |
| **AWS EC2 Mac** | ~$25/day | Better for CI than daily dev |

**Workflow (Windows → Cloud Mac):**
1. Write/edit Swift in VS Code on Windows (syntax only, no build)
2. `git push` changes
3. Remote into cloud Mac
4. `git pull`, open Xcode, build & test
5. Submit to App Store from cloud Mac

See `ios/XCODE_SETUP.md` for Xcode project creation steps.

---

## 2. Screen Inventory

Based on PRD user stories, here are all screens needed:

### Authentication Flow
| Screen | Purpose | PRD Stories |
|--------|---------|-------------|
| **Welcome** | App intro, sign up / sign in options | - |
| **Register** | Create account (email, password) | #20 (security) |
| **Login** | Email + password login | #21 (biometric) |
| **Biometric Prompt** | Face ID / Touch ID unlock | #21 |

### Onboarding Flow (First-Time Users)
| Screen | Purpose | PRD Stories |
|--------|---------|-------------|
| **Onboarding Intro** | Welcome, explain app value | #1 |
| **First Protocol Setup** | Guided protocol creation wizard | #1, #2 |
| **Wearable Connection** | Optional: connect Oura/Whoop/Apple Health | #6, #7, #8 |
| **Notification Permissions** | Request push notification access | #3, #22 |

### Main App (Tab Bar)
| Tab | Primary Screen | Purpose |
|-----|----------------|---------|
| **Home** | Dashboard | Unified view of all data (#10) |
| **Check-in** | Quick Check-in | Fast daily logging (#23) |
| **Protocols** | Protocol List | Manage protocols (#17, #18) |
| **Insights** | Insights List | AI recommendations (#13, #14) |
| **Profile** | Settings/Profile | Account, preferences, export |

### Dashboard (Home Tab)
| Component | Purpose | PRD Stories |
|-----------|---------|-------------|
| **Active Protocol Card** | Current protocol summary | #2, #17 |
| **Weight Trend Chart** | Visual weight over time | #5, #11 |
| **Recent Check-ins** | Last few entries | #10 |
| **Unread Insights Badge** | Alert for new insights | #12, #13 |
| **Quick Actions** | Log check-in, view labs | #23 |

### Check-in Flow
| Screen | Purpose | PRD Stories |
|--------|---------|-------------|
| **Quick Check-in** | Weight + how you feel (fast) | #23 |
| **Detailed Check-in** | Symptoms, mood, sleep, notes | #4, #24 |
| **Symptom Picker** | Select from common symptoms | #4 |

### Protocol Management
| Screen | Purpose | PRD Stories |
|--------|---------|-------------|
| **Protocol List** | All protocols (active/inactive) | #17, #18 |
| **Protocol Detail** | View protocol + compounds | #18 |
| **Create/Edit Protocol** | Add/modify protocol | #1, #2 |
| **Add Compound** | Select compound, set dose/frequency | #2, #17 |

### Labs
| Screen | Purpose | PRD Stories |
|--------|---------|-------------|
| **Lab List** | All lab entries | #9 |
| **Lab Detail** | View markers from a lab panel | #9 |
| **Add Lab Entry** | Enter blood work results | #9 |

### Insights
| Screen | Purpose | PRD Stories |
|--------|---------|-------------|
| **Insights List** | All insights (filterable) | #13 |
| **Insight Detail** | Full insight + explanation | #15 |
| **Insight Action** | Accept / Dismiss / Snooze | #16 |

### Wearables
| Screen | Purpose | PRD Stories |
|--------|---------|-------------|
| **Connected Wearables** | List of connections | #6, #7, #8 |
| **Connect Wearable** | OAuth flow for Oura/Whoop | #7, #8 |
| **Apple Health Permissions** | HealthKit access (iOS only) | #6 |

### Profile & Settings
| Screen | Purpose | PRD Stories |
|--------|---------|-------------|
| **Profile** | Account info, edit profile | - |
| **Notification Settings** | Reminder times, preferences | #3, #22 |
| **Data Export** | Export all data | #19 |
| **Security Settings** | Biometric toggle, logout | #20, #21 |
| **About / Help** | App info, support | - |

### Search
| Screen | Purpose | PRD Stories |
|--------|---------|-------------|
| **Search** | Search history (check-ins, labs, insights) | #25 |

---

## 3. Development Phases

### Phase 0: Project Setup + Design System
**Goal:** iOS project ready to build features, with a design system in place.

| Slice | Task | Details |
|-------|------|---------|
| 0a | Create iOS Xcode project | Swift, SwiftUI, iOS 17+, bundle ID |
| 0b | Folder structure | Features/, Core/, Design/ per architecture |
| 0c | Design system — Colors | Define palette, create Color extension |
| 0d | Design system — Typography | Define text styles, create ViewModifiers |
| 0e | Design system — Spacing | Define spacing scale constants |
| 0f | Design system — Components | Button, TextField, Card (basic versions) |
| 0g | Networking layer | APIClient with async/await, error handling |
| 0h | Auth interceptor | Attach JWT, handle 401 → refresh |
| 0i | Secure storage | Keychain wrapper for tokens |
| 0j | Firebase setup | Analytics + Crashlytics SDK |

*iOS setup deferred — Android first due to Windows dev environment.*

### Phase 1: Auth + Core Navigation
**Goal:** User can register, login, and see the main tab bar.

| Slice | Feature | Screens |
|-------|---------|---------|
| 1a | App shell + tab bar | Main tab bar with placeholders |
| 1b | Register flow | Welcome → Register → Auto-login |
| 1c | Login flow | Login → Token storage → Main app |
| 1d | Biometric unlock | Face ID / Touch ID on app launch |
| 1e | Logout | Clear tokens, return to Welcome |

### Phase 2: Protocol Management
**Goal:** User can create and manage protocols with compounds.

| Slice | Feature | Screens |
|-------|---------|---------|
| 2a | Protocol list | View all protocols (empty state) |
| 2b | Create protocol | Name, start date, notes |
| 2c | Add compounds | Compound picker, dose, frequency |
| 2d | Protocol detail | View protocol with compounds |
| 2e | Edit/delete protocol | Modify existing protocol |
| 2f | Activate/deactivate | Toggle protocol status |

### Phase 3: Check-ins
**Goal:** User can log daily check-ins (weight, symptoms, mood).

| Slice | Feature | Screens |
|-------|---------|---------|
| 3a | Quick check-in | Weight + quick mood |
| 3b | Symptom logging | Add symptoms from picker |
| 3c | Detailed check-in | Full form with notes |
| 3d | Check-in history | List with date filters |
| 3e | Check-in detail | View past check-in |

### Phase 4: Dashboard
**Goal:** User sees unified view of their data on home screen.

| Slice | Feature | Screens |
|-------|---------|---------|
| 4a | Dashboard layout | Card-based layout |
| 4b | Active protocol card | Show current protocol |
| 4c | Weight trend chart | Line chart with date range picker |
| 4d | Recent activity | Last check-ins, labs |
| 4e | Quick actions | Shortcuts to common tasks |

### Phase 5: Insights
**Goal:** User can view and act on AI-generated insights.

| Slice | Feature | Screens |
|-------|---------|---------|
| 5a | Insights list | All insights with badges |
| 5b | Insight detail | Full explanation view |
| 5c | Insight actions | Accept / Dismiss / Snooze |
| 5d | Unread indicators | Badge on tab, dashboard card |
| 5e | Generate insights | Manual trigger button |

### Phase 6: Labs
**Goal:** User can log and view blood work results.

| Slice | Feature | Screens |
|-------|---------|---------|
| 6a | Lab list | All lab entries |
| 6b | Add lab entry | Panel type + markers |
| 6c | Lab detail | View markers |

### Phase 7: Wearables
**Goal:** User can connect Oura/Whoop and sync data.

| Slice | Feature | Screens |
|-------|---------|---------|
| 7a | Connections list | Show connected wearables |
| 7b | Connect Oura | OAuth flow |
| 7c | Connect Whoop | OAuth flow |
| 7d | Apple Health (iOS) | HealthKit permissions + sync |
| 7e | Sync trigger | Manual sync button |
| 7f | Disconnect | Remove connection |

### Phase 8: Notifications & Reminders
**Goal:** User receives push notifications and can set reminders.

| Slice | Feature | Screens |
|-------|---------|---------|
| 8a | Push registration | Register device token with backend |
| 8b | Notification preferences | Settings screen |
| 8c | Handle push | Deep link to relevant screen |
| 8d | Local reminders | Check-in reminder scheduling |

### Phase 9: Profile & Settings
**Goal:** User can manage account and app settings.

| Slice | Feature | Screens |
|-------|---------|---------|
| 9a | Profile view | Account info |
| 9b | Edit profile | Update name, etc. |
| 9c | Data export | Trigger export, download |
| 9d | Security settings | Biometric toggle |
| 9e | About / Help | App version, support links |

### Phase 10: Search & Polish
**Goal:** Final features and polish for MVP launch.

| Slice | Feature | Screens |
|-------|---------|---------|
| 10a | Search | Full-text search across data |
| 10b | Empty states | Friendly empty states everywhere |
| 10c | Error handling | User-friendly error messages |
| 10d | Loading states | Skeletons, spinners |
| 10e | Offline handling | Graceful degradation |

---

## 4. Technical Architecture

### iOS (Swift + SwiftUI)

```
ios/
├── Peppy/
│   ├── App/
│   │   ├── PeppyApp.swift           # App entry point
│   │   └── AppState.swift           # Global app state
│   ├── Features/
│   │   ├── Auth/
│   │   │   ├── Views/
│   │   │   ├── ViewModels/
│   │   │   └── Models/
│   │   ├── Dashboard/
│   │   ├── Checkin/
│   │   ├── Protocols/
│   │   ├── Insights/
│   │   ├── Labs/
│   │   ├── Wearables/
│   │   └── Settings/
│   ├── Core/
│   │   ├── Network/
│   │   │   ├── APIClient.swift
│   │   │   ├── Endpoints.swift
│   │   │   └── AuthInterceptor.swift
│   │   ├── Storage/
│   │   │   ├── KeychainService.swift
│   │   │   └── UserDefaults+Extensions.swift
│   │   └── Utilities/
│   ├── Design/
│   │   ├── Colors.swift
│   │   ├── Typography.swift
│   │   └── Components/
│   └── Resources/
│       └── Assets.xcassets
└── PeppyTests/
```

### Android (Kotlin + Jetpack Compose)

```
android/
├── app/
│   └── src/
│       └── main/
│           ├── java/com/peppy/
│           │   ├── PeppyApp.kt              # Application class
│           │   ├── MainActivity.kt
│           │   ├── features/
│           │   │   ├── auth/
│           │   │   │   ├── ui/
│           │   │   │   ├── viewmodel/
│           │   │   │   └── data/
│           │   │   ├── dashboard/
│           │   │   ├── checkin/
│           │   │   ├── protocols/
│           │   │   ├── insights/
│           │   │   ├── labs/
│           │   │   ├── wearables/
│           │   │   └── settings/
│           │   ├── core/
│           │   │   ├── network/
│           │   │   │   ├── ApiClient.kt
│           │   │   │   ├── AuthInterceptor.kt
│           │   │   │   └── Endpoints.kt
│           │   │   ├── storage/
│           │   │   │   └── SecureStorage.kt
│           │   │   └── util/
│           │   └── design/
│           │       ├── theme/
│           │       └── components/
│           └── res/
└── app/src/test/
```

### Shared Patterns

| Concern | iOS | Android |
|---------|-----|---------|
| UI Framework | SwiftUI | Jetpack Compose |
| Architecture | MVVM | MVVM |
| Networking | URLSession + async/await | Retrofit + Coroutines |
| DI | Manual / Environment | Hilt |
| Secure Storage | Keychain | EncryptedSharedPreferences |
| Image Loading | AsyncImage | Coil |
| Charts | Swift Charts | MPAndroidChart / Vico |

---

## 5. API Integration Checklist

Each endpoint the apps will use:

### Auth
- [ ] `POST /auth/register` — Create account
- [ ] `POST /auth/login` — Get tokens
- [ ] `POST /auth/refresh` — Refresh access token
- [ ] `POST /auth/logout` — Logout
- [ ] `GET /auth/me` — Get current user

### Protocols
- [ ] `POST /protocols` — Create protocol
- [ ] `GET /protocols` — List protocols
- [ ] `GET /protocols/{id}` — Get protocol
- [ ] `PATCH /protocols/{id}` — Update protocol
- [ ] `DELETE /protocols/{id}` — Delete protocol
- [ ] `POST /protocols/{id}/activate` — Activate
- [ ] `POST /protocols/{id}/deactivate` — Deactivate

### Check-ins
- [ ] `POST /checkins` — Log check-in
- [ ] `GET /checkins` — List check-ins
- [ ] `GET /checkins/{id}` — Get check-in

### Labs
- [ ] `POST /labs` — Log lab result
- [ ] `GET /labs` — List labs
- [ ] `GET /labs/{id}` — Get lab

### Wearables
- [ ] `GET /wearables/connections` — List connections
- [ ] `POST /wearables/connect/{provider}` — Start OAuth
- [ ] `GET /wearables/callback/{provider}` — OAuth callback
- [ ] `POST /wearables/sync/{provider}` — Trigger sync
- [ ] `DELETE /wearables/connections/{id}` — Disconnect

### Insights
- [ ] `GET /insights` — List insights
- [ ] `GET /insights/{id}` — Get insight
- [ ] `POST /insights/{id}/read` — Mark as read
- [ ] `POST /insights/{id}/action` — Accept/dismiss/snooze
- [ ] `POST /insights/generate` — Generate insights

### Notifications
- [ ] `POST /notifications/devices` — Register device
- [ ] `GET /notifications/devices` — List devices
- [ ] `DELETE /notifications/devices/{id}` — Unregister
- [ ] `GET /notifications/preferences` — Get preferences
- [ ] `PATCH /notifications/preferences` — Update preferences

---

## 6. Design Guidelines

**Full design system:** See `design-mockups/handoff-v2/DESIGN_SYSTEM.md`  
**Design tokens:** See `design-mockups/handoff-v2/tokens.css`  
**Landing mockup:** See `design-mockups/landing-v4.html`

### Brand Voice

peppy is **warm, calm, and confident** — not loud, not cute, not corporate.

| Voice | UI Translation |
|-------|----------------|
| Warm | Cream backgrounds (not pure white), Fraunces italic for one-word accents, generous radii |
| Calm | Restrained motion, one accent color on screen, sentence case (no SHOUTY-CAPS) |
| Confident | SemiBold (600) at display sizes, decisive contrast, no apologetic gray-on-gray text |

### Color Palette (Three Roles)

| Role | Hex | Usage |
|------|-----|-------|
| **Rust** (brand) | `#C76B3E` | Hero surfaces, primary CTAs, accents — never body text |
| **Ink** (foreground) | `#1E2026` | Primary text, dark buttons, headlines |
| **Cream** (background) | `#FAF7F0` | Default page background, text on rust |

**Full scale:**
- Rust: 100 `#F7DDCB` · 300 `#E5A487` · 500 `#C76B3E` · 700 `#98512E` · 900 `#663520`
- Ink: 100 `#E5E7EB` · 300 `#BFC1C7` · 500 `#777A82` · 700 `#4A4D54` · 900 `#1E2026`
- Cream: 50 `#FCFAF5` · 100 `#FAF7F0` · 200 `#F3EDDF`

**Semantic:** Success `#4E8C5B` · Warning `#D9A04A` · Danger `#C24B3F`

**Dark mode:** Auto-honor `prefers-color-scheme: dark`. Cream inverts to deep ink, rust desaturates slightly.

### Typography (Rule of Three)

| Family | Role | Usage |
|--------|------|-------|
| **Plus Jakarta Sans** | Workhorse (~95%) | Display, headlines, body, UI, buttons, metadata |
| **Fraunces** (italic) | Warmth accent | **One word at a time** inside a headline |
| **Nunito** | Logo only | The "peppy" wordmark — nowhere else |

**Hard rules:**
- Fraunces is a spice, not an ingredient — never a sentence, never two consecutive words
- Nunito does not appear outside the wordmark
- No monospace anywhere in product surface
- Weight ceiling is 700 — emphasis via SemiBold (600), not Black (900)
- Sentence case throughout (no all-lowercase or ALL-CAPS except labels)

**Type Scale (mobile / desktop):**

| Token | Mobile | Desktop | Weight |
|-------|--------|---------|--------|
| Display | 40px | 72px | 600 |
| H1 | 28px | 44px | 600 |
| H2 | 22px | 28px | 600 |
| H3 | 18px | 20px | 600 |
| Body Large | 17px | 17px | 400 |
| Body | 16px | 16px | 400 |
| Body Small | 14px | 14px | 500 |
| Caption | 13px | 13px | 500 |
| Label | 12px | 12px | 600 UPPERCASE (0.08em tracking) |

**Native fallbacks:**

| Family | iOS | Android |
|--------|-----|---------|
| Plus Jakarta Sans | SF Pro Display/Text | Roboto |
| Fraunces (italic) | New York italic | Noto Serif italic |
| Nunito (wordmark) | SF Pro Rounded | Google Sans (or SVG) |

### Spacing Scale (4px base)

| Token | Value | Usage |
|-------|-------|-------|
| space-1 | 4px | Tightest gap |
| space-2 | 8px | Inline siblings |
| space-3 | 12px | Compact stack |
| space-4 | 16px | **Default** — body gap, card padding (mobile) |
| space-5 | 20px | Mobile screen edge padding |
| space-6 | 24px | Section gaps inside a card |
| space-8 | 32px | Between unrelated sections |
| space-10 | 40px | Block separator |
| space-12 | 48px | Hero vertical rhythm |

### Corner Radius

| Token | Value | Usage |
|-------|-------|-------|
| sm | 8px | Inputs, chips, tags |
| md | 16px | Cards, modals |
| lg | 20px | Hero cards, bottom sheets |
| pill | 999px | **All buttons, all toggles, avatars** |

### Components

**Buttons** — all pill-shaped (999px radius):
- Primary: ink-900 background, cream text — one per screen
- Secondary: transparent, 1.5px ink border
- Tertiary: transparent, rust text, underline on hover
- Sizes: Small (40px), Default (48px), Large (56px) — all hit 44pt minimum

**Inputs:** 48px height, 8px radius, 1.5px border, rust border on focus (no glow)

**Cards:** 16px radius, cream-50 background, 24px padding desktop / 20px mobile, optional 1px subtle border, **no drop shadow by default**

**Navigation (mobile):**
- Top nav: 56px + safe area, cream background, ink title at 17px weight 600
- Tab bar: 56px + safe area, 1px top border, tertiary icons, rust for active

### Motion

| Speed | Duration | When |
|-------|----------|------|
| Instant | 100ms | Hover color changes |
| Fast | 180ms | Most UI transitions |
| Normal | 240ms | Modal in/out, page transitions |
| Slow | 400ms | Hero animations, bottom-sheet snap |

No spring/bouncy easings — too playful for the professional voice.

### Don't Do This

- ❌ Use Nunito anywhere except the wordmark logo
- ❌ Use Fraunces for more than one word at a time
- ❌ Use monospace anywhere in product surface
- ❌ Weight 800 or 900 on any element
- ❌ All-lowercase or ALL-CAPS headlines (labels only for caps)
- ❌ Multiple accent colors on the same screen
- ❌ Drop shadows on cards (flat by default)
- ❌ Pure white (#FFFFFF) or pure black (#000000)
- ❌ Bouncy/springy easings
- ❌ Text under 16px in form fields (iOS zoom)

---

## 7. Testing Strategy

### Unit Tests
- ViewModels / Presenters
- Network response parsing
- Data transformations

### UI Tests
- Critical user flows:
  - Register → Login → Dashboard
  - Create protocol → Add compound
  - Log check-in
  - View and act on insight

### Manual Testing Checklist (per release)
- [ ] Fresh install flow
- [ ] Login / logout
- [ ] Biometric unlock
- [ ] All CRUD operations
- [ ] Offline behavior
- [ ] Push notifications
- [ ] Deep links

---

## 8. Progress Tracker

### Phase 0: Project Setup + Design System
| Slice | Task | iOS | Android | Notes |
|-------|------|-----|---------|-------|
| 0a | Create project | [ ] | [x] | iOS: `ios/XCODE_SETUP.md`, Android: Android Studio Panda |
| 0b | Folder structure | [x] | [x] | core/, design/, features/ |
| 0c | Design — Colors | [x] | [x] | v2: Rust/Ink/Cream palette |
| 0d | Design — Typography | [x] | [x] | v2: Plus Jakarta Sans (95%), Nunito logo only |
| 0e | Design — Spacing | [x] | [x] | 4/8/16/24/32/48pt scale |
| 0f | Design — Components | [x] | [x] | PepButton, PepCard, PepBadge, PepTextField, PepListItem, PepEmptyState |
| 0g | Networking layer | [x] | [x] | Retrofit + OkHttp (Android), URLSession (iOS) |
| 0h | Auth interceptor | [x] | [x] | Token refresh with mutex lock |
| 0i | Secure storage | [x] | [x] | EncryptedSharedPreferences (Android), Keychain (iOS) |
| 0j | Analytics + Crashlytics | [ ] | [ ] | Deferred to post-MVP |

### Phase 1: Auth + Navigation ✅
| Slice | iOS | Android | Notes |
|-------|-----|---------|-------|
| 1a Tab bar | [x] | [x] | MainScreen with 5 tabs (placeholder content) |
| 1b Register | [x] | [x] | RegisterScreen with validation |
| 1c Login | [x] | [x] | LoginScreen with validation |
| 1d Biometric | [ ] | [x] | Fingerprint/Face unlock on app launch |
| 1e Logout | [ ] | [x] | Clear tokens, return to Welcome |

### Phase 2: Protocol Management ✅
| Slice | iOS | Android | Notes |
|-------|-----|---------|-------|
| 2a Protocol list | [ ] | [x] | ProtocolListScreen with empty state, pull-to-refresh |
| 2b Create protocol | [ ] | [x] | CreateProtocolScreen with date pickers, UX polish |
| 2c Add compounds | [ ] | [x] | Compound form with frequency/route dropdowns |
| 2d Protocol detail | [ ] | [x] | ProtocolDetailScreen with compounds display |
| 2e Edit/delete protocol | [ ] | [x] | Delete works; Autocomplete peptide picker (60+ peptides) added |
| 2f Activate/deactivate | [ ] | [x] | Toggle from detail screen |

### Phase 3: Check-ins ✅
| Slice | iOS | Android | Notes |
|-------|-----|---------|-------|
| 3a Quick check-in | [ ] | [x] | Weight + quick mood capture |
| 3b Symptom logging | [ ] | [x] | Symptom picker integrated into check-in form |
| 3c Detailed check-in | [ ] | [x] | Full form: weight, mood, energy, sleep, symptoms, notes |
| 3d Check-in history | [ ] | [x] | List with date display |
| 3e Check-in detail | [ ] | [x] | View past check-in entry |

*(Continue for all phases)*

---

## 9. Decisions Made

| Question | Decision | Rationale |
|----------|----------|-----------|
| **Design approach** | Design system first, then screens per phase | Consistency without long upfront delay |
| **Development order** | Android first, then iOS | Windows dev environment — Android Studio runs natively, iOS requires cloud Mac with latency. Faster iteration → learnings transfer to iOS port. |
| **iOS version** | iOS 17+ | Modern SwiftUI, widely adopted in 2026, App Store favored |
| **Android version** | API 26+ (Android 8) | Broad device coverage |
| **Offline support** | Read-only cache | Simple for MVP; full offline queue is future work |
| **Analytics/Crash** | Firebase (Analytics + Crashlytics) | Industry standard, good dashboards |
| **iOS Push** | APNs directly (not FCM) | Backend already has APNs adapter; simpler, no Google dependency on iOS |
| **Android Push** | FCM | Standard for Android |
| **Color theme** | Cream background with rust accent | Three roles: rust (#C76B3E), ink (#1E2026), cream (#FAF7F0) — warm, professional |
| **Typography** | Plus Jakarta Sans (95%), Fraunces italic (accent), Nunito (logo only) | Professional direction — weight ceiling 600, no monospace |
| **State management** | Hybrid `@Observable` — AppState (global) + feature ViewModels | Balanced: shared auth state + isolated features |
| **Networking** | Protocol + Endpoint enum, generic `execute<T>()` | Type-safe, testable, single auth header injection point |
| **Token refresh** | Coordinated with `Task` lock | Handles concurrent 401s without duplicate refreshes |
| **Navigation** | `NavigationStack` with typed route enum per tab | Programmatic control, type-safe, deep-link ready |
| **Dependency injection** | Lightweight `Dependencies` container via `@Environment` | Testable, no singletons, clean swap for mocks |
| **Error handling** | Typed `APIError` → user message, global toast | Consistent UX, one pattern everywhere |
| **Caching** | In-memory, stale-while-revalidate | Fast revisits, graceful network failure, simple for MVP |
| **Keychain** | Thin wrapper with protocol | Testable, clean API over Security framework |
| **Android DI** | Manual injection for MVP | AGP 9.x built-in Kotlin incompatible with KAPT; Hilt deferred |
| **Android Kotlin** | Built-in (AGP 9.x) | No separate kotlin-android plugin; handled by AGP |
| **Android secure storage** | EncryptedSharedPreferences | Standard Android Jetpack Security library |

---

## 10. Session Log

### 2026-05-17 — Planning Session
- Created APP_DEV.md
- Defined all screens from PRD user stories
- Outlined 10 development phases with slices
- Documented technical architecture (MVVM, SwiftUI/Compose)
- Listed API integration checklist
- **Decisions made:**
  - Design system first, screens per phase
  - iOS first (iOS 17+), then Android (API 26+)
  - Read-only cache for offline
  - Firebase for analytics/crash (not push)

### 2026-05-17 — Design System Session
- Iterated on landing page mockups (v1 → v2 → v3)
- **Final design decisions:**
  - Theme: Warm dark (charcoal `#1C1917`, not pure black)
  - Primary: Peach `#E07A5F` (warm, human, approachable)
  - Success accent: Sage green `#81B29A`
  - Typography: Plus Jakarta Sans (headlines) + Outfit (body) for web
  - Typography: SF Pro for iOS (native)
- **Push notifications:**
  - iOS: APNs directly (backend already has adapter)
  - Android: FCM
- Created `ios/Design/DESIGN_SYSTEM.md` with full spec
- Created `design-mockups/landing-v3.html` (final mockup)
- **Next:** Grill the plan, then break into issues, then start Phase 0

### 2026-05-18 — Architecture Grilling + Phase 0 Complete
- Grilled iOS architecture decisions (8 questions)
- **Architectural decisions locked in:**
  - State: Hybrid `@Observable` (AppState + feature ViewModels)
  - Networking: Protocol + Endpoint enum pattern
  - Token refresh: Coordinated with Task lock for concurrent 401s
  - Navigation: NavigationStack with typed route enum per tab
  - DI: Lightweight Dependencies container via @Environment
  - Errors: Typed APIError + global toast
  - Caching: In-memory + stale-while-revalidate
  - Keychain: Thin wrapper with protocol
- **Phase 0 implementation complete (24 Swift files):**
  - App layer: PeppyApp, AppState, Dependencies, RootView, MainTabView
  - Networking: APIClient, Endpoint, APIError, APIModels, MockAPIClient
  - Storage: KeychainService
  - Design: Colors, Typography, Spacing + 7 components
  - Auth screens: WelcomeView, LoginView, RegisterView
- Created `ios/XCODE_SETUP.md` with step-by-step instructions
- **Development environment:** Cloud Mac required (MacinCloud recommended ~$30/mo)

### 2026-05-22 — Platform Switch Decision
- **Decision:** Switch from iOS-first to Android-first
- **Rationale:** Windows dev environment makes Android iteration 2-3x faster
  - Android Studio runs natively on Windows
  - iOS requires cloud Mac with remote desktop latency + $30/mo
  - Mobile dev is highly iterative — friction compounds into weeks of delay
- **iOS work not wasted:** Architecture, design tokens, API contracts, screen inventory all transfer to Kotlin
- **New plan:** Build Android MVP → validate flows → port to iOS with known-good design
- **Next:** Set up Android project (Android Studio), port design system to Compose, start Phase 0 for Android

### 2026-05-23 — Android Project Setup Complete
- **Android Studio Panda 4** installed and configured
- **Created Android project** with:
  - Package: `com.peppy.app`
  - Min SDK: API 26 (Android 8.0)
  - Target SDK: API 35
  - Kotlin DSL for Gradle
  - Jetpack Compose UI
- **AGP 9.x Discovery:** Android Gradle Plugin 9.x has **built-in Kotlin support**
  - Traditional `kotlin-android` plugin conflicts with built-in Kotlin
  - KAPT is incompatible with built-in Kotlin
  - KSP requires exact version matching with Kotlin (tricky with Kotlin 2.2.10)
- **DI Decision:** Use manual dependency injection for MVP
  - Hilt requires KAPT/KSP which conflicts with AGP 9.x built-in Kotlin
  - Manual DI is simpler, faster to iterate, and fine for MVP scope
  - Can add Hilt later when tooling stabilizes
- **Dependencies configured:**
  - Jetpack Compose + Material 3
  - Navigation Compose
  - Retrofit + OkHttp (networking)
  - Kotlinx Serialization (JSON)
  - EncryptedSharedPreferences (secure storage)
  - Coil (image loading)
- **Folder structure created:**
  ```
  com/peppy/app/
  ├── core/network/       # API client, interceptors
  ├── core/storage/       # Secure storage, preferences
  ├── core/util/          # Utilities
  ├── design/theme/       # Colors, typography, spacing
  ├── design/components/  # Reusable UI components
  ├── features/auth/      # Login, register, welcome
  ├── features/dashboard/ # Home screen
  ├── features/protocols/ # Protocol management
  ├── features/checkin/   # Check-in flow
  ├── features/insights/  # AI insights
  └── features/settings/  # Profile, preferences
  ```
- **App verified running** on Android emulator

### 2026-05-24 — Android Phase 0 + Phase 1 Complete
- **Phase 0 Design System (Android):**
  - Updated Color.kt with Peppy warm dark theme (peach primary, charcoal background)
  - Updated Type.kt with full Material 3 typography scale
  - Created Spacing.kt with 4/8/16/24/32/48dp scale + corner radius
  - Created 6 reusable components: PepButton, PepCard, PepTextField, PepBadge, PepListItem, PepEmptyState
  - Added Material Icons Extended dependency
- **Phase 0 Infrastructure (Android):**
  - ApiModels.kt — Auth request/response models with kotlinx.serialization
  - ApiService.kt — Retrofit interface for auth endpoints
  - ApiClient.kt — Generic execute() wrapper with typed ApiResult
  - AuthInterceptor.kt — JWT injection + 401 refresh with mutex coordination
  - SecureStorage.kt — EncryptedSharedPreferences wrapper
  - Dependencies.kt — Manual DI container (Hilt deferred due to AGP 9.x/KAPT conflict)
  - PeppyApp.kt — Application class for dependency init
- **Phase 1 Auth + Navigation (Android):**
  - AppState.kt — Global auth state with StateFlow
  - Routes.kt — String-based route constants
  - AppNavigation.kt — NavHost with auth flow
  - WelcomeScreen.kt — App intro with sign up/in buttons
  - LoginScreen.kt — Email/password login with validation
  - RegisterScreen.kt — Account creation with validation
  - AuthViewModel.kt — Login/register logic with event-based navigation
  - MainScreen.kt — Tab bar with 5 tabs (Home, Check-in, Protocols, Insights, Settings)
  - Updated MainActivity.kt — Auth state check on launch, navigation setup
- **Build verified successful**

### 2026-05-24 (continued) — Design System Overhaul
- **Theme switch:** Dark → Light based on user-provided HTML examples
- **Color palette updated:**
  - Background: `#1C1917` (dark) → `#FBF8F3` (warm cream)
  - Primary: `#E07A5F` (peach) → `#D4805A` (coral)
  - Text: Light-on-dark → Dark-on-light (`#1E2235`)
- **Typography updated:**
  - Added Nunito font via Google Fonts downloadable fonts API
  - Created `font_certs.xml` for Google Fonts provider
  - All typography styles now use NunitoFontFamily
- **Theme.kt:** Switched from `darkColorScheme` to `lightColorScheme`
- **All screens refactored:** Using `MaterialTheme.colorScheme.*` instead of hardcoded color imports
- **Fixed:** MainActivity loading state now shows spinner (was blank)
- **Build verified successful**
- **Next session:** Test on device, then complete 1d (Biometric) + 1e (Logout), then Phase 2 (Protocol Management)

### 2026-05-25 — Design System v2 (Professional Direction)
- **Major design system overhaul** based on new handoff files
- **Typography completely changed:**
  - Plus Jakarta Sans is now the workhorse (~95% of text)
  - Nunito is ONLY for the "peppy" wordmark logo — nowhere else
  - Fraunces italic for one-word accents inside headlines
  - No monospace anywhere in product surface
  - Weight ceiling is 600 (SemiBold), not 800/900
- **Color palette refined:**
  - Rust `#C76B3E` (brand accent)
  - Ink `#1E2026` (text, dark buttons)
  - Cream `#FAF7F0` (background)
- **Brand name:** "peppy" (lowercase) — never "Peppy"
- **New design artifacts:**
  - `design-mockups/handoff-v2/DESIGN_SYSTEM.md` — full spec
  - `design-mockups/handoff-v2/tokens.css` — design tokens
  - `design-mockups/landing-v4.html` — landing page matching v2
- **Android app needs update:** Current implementation uses Nunito everywhere + wrong colors

### 2026-05-25 (continued) — Android Design System v2 Applied
- **Updated Android theme to v2 spec:**
  - **Color.kt:** Rust/Ink/Cream three-role palette with full scales
  - **Type.kt:** Plus Jakarta Sans (was Nunito), weight ceiling 600
  - **Spacing.kt:** Added v2 space-1 through space-12 tokens, pill radius (999dp)
  - **Theme.kt:** Updated Material color scheme mappings
- **Updated all components:**
  - PepButton: Pill-shaped (999dp radius), Ink900 bg for primary, added size variants
  - PepCard: Cream50 background, 16dp radius
  - PepTextField: Rust500 focus border, Ink colors for text
  - PepBadge: Updated to v2 color tokens
  - PepListItem: Rust500 icons, Ink colors for text
  - PepEmptyState: headlineSmall for title, Ink colors
- **Updated screens:**
  - WelcomeScreen: "peppy" lowercase (brand fix)
  - All screens already use MaterialTheme.colorScheme (no changes needed)
- **Build verified successful**

### 2026-05-25 (continued) — Wordmark Font + Dark Mode
- **Nunito wordmark:** Added NunitoFontFamily to Type.kt for "peppy" wordmark only
- **WelcomeScreen:** Updated to use Nunito ExtraBold 48sp for the bubbly "peppy" logo
- **Dark mode support:**
  - Added full dark color scheme to Color.kt (DarkBackground, DarkSurface, etc.)
  - Theme.kt now uses `isSystemInDarkTheme()` to auto-detect system preference
  - Status/navigation bars adapt to dark/light mode
  - Added dark mode preview to WelcomeScreen
- **Build verified successful**
- **Next:** Test on device, then Phase 1d (Biometric) + 1e (Logout)

### 2026-05-26 — Auth Flow Debugging + Network Fixes
- **API field mismatch fixed:**
  - Android `RegisterRequest.name` → `RegisterRequest.displayName` with `@SerialName("display_name")`
  - Android `UserResponse.name` → `UserResponse.displayName` with `@SerialName("display_name")`
  - Added `UserResponse.isVerified` field
  - Updated `MainActivity.kt` cached UserResponse to use new field names
- **Backend bcrypt fix:**
  - bcrypt 5.0.0 incompatible with passlib 1.7.4
  - Downgraded bcrypt to 4.3.0
- **Android network fixes:**
  - Added `android:usesCleartextTraffic="true"` to AndroidManifest.xml (required for HTTP on Android 9+)
  - Backend running on port 8001 (8000 was stuck), updated ApiClient baseUrl
  - Added Windows Firewall rule for port 8001
- **AuthInterceptor fix:**
  - Was skipping ALL `/auth/` endpoints including `/auth/me`
  - Fixed to only skip `/auth/login`, `/auth/register`, `/auth/refresh`
  - `/auth/me` now correctly receives Authorization header
- **Result:** Registration, login, logout all working end-to-end

### Next Session — UX Polish (Priority)
- **Goal:** Professional, production-ready feel
- **Requirements:**
  - Smooth clicks and swipes throughout the app
  - Touch feedback (ripple effects, press states)
  - Fluid transitions between screens
  - No jank or stuttering on interactions
  - Standard mobile UX patterns (swipe gestures, pull-to-refresh where appropriate)
  - Consistent with how polished production apps behave

---

## 11. Future Requirements (Pre-Launch Essential)

### Pre-Auth Onboarding Questionnaire ⚠️ ESSENTIAL
Users must go through an onboarding questionnaire **BEFORE** seeing the sign in/sign up screen. This is critical for product personalization.

**Flow:** App Launch → Onboarding Questions → Sign In/Sign Up → Main App

**Questions to collect:**
| Question | Type | Skip allowed? |
|----------|------|---------------|
| Age | Number picker | Yes |
| Height | Number + unit | Yes |
| Weight | Number + unit | Yes |
| Peptides currently taking | Multi-select | Yes |
| Other medications | Free text / multi-select | Yes |
| Workout frequency | "X times per week" picker | Yes |
| Goals (weight loss, muscle, etc.) | Multi-select | Yes |

**Implementation notes:**
- Store answers locally until account creation
- Backend needs user profile/preferences endpoints
- Product features should adapt based on these answers
- Some questions may be required (age for safety warnings?)

### Social Authentication
- **Google Sign-In** — standard OAuth flow
- **Apple Sign-In** — required for iOS App Store if offering other social logins
- Keep email/password as fallback option
- Backend needs OAuth endpoints for each provider

### Login Persistence
- Users must stay logged in across app restarts (current token storage should handle this)
- Verify token refresh handles long-lived sessions gracefully
- Biometric unlock already implemented — works alongside persistence

### UX/UI Polish
- Address incrementally during feature development
- Dedicated polish pass before beta/launch milestones
- Smooth animations, touch feedback, no jank

---

## 12. Session Log (Continued)

### 2026-05-27 — Phase 2 Protocol Management Complete
- **API Models added:**
  - `CompoundRequest`, `CompoundResponse` for compound data
  - `ProtocolCreateRequest`, `ProtocolUpdateRequest`, `ProtocolResponse`
  - Backend returns `List<ProtocolResponse>` not paginated object
- **API Endpoints added to ApiService:**
  - `GET /protocols` — list (returns plain array)
  - `GET /protocols/{id}` — detail
  - `POST /protocols` — create with compounds
  - `PATCH /protocols/{id}` — update
  - `DELETE /protocols/{id}` — delete
  - `POST /protocols/{id}/activate` — activate
  - `POST /protocols/{id}/deactivate` — deactivate
- **ProtocolViewModel created:**
  - Manages list, detail, and create states
  - Handles all CRUD operations
  - Event-based navigation (ProtocolCreated, ProtocolDeleted, etc.)
- **Protocol UI screens created:**
  - `ProtocolListScreen` — list with empty state, FAB for create, pull-to-refresh
  - `ProtocolDetailScreen` — full detail with compounds, activate/deactivate toggle, delete confirmation
  - `CreateProtocolScreen` — form with date pickers, compound management inline
- **Navigation updated:**
  - Added protocol routes to Routes.kt
  - AppNavigation handles protocol detail/create screens
  - MainScreen Protocols tab now uses ProtocolListScreen
- **PepButton enhanced:**
  - Added `leadingIcon` parameter for icon+text buttons
  - Renamed `style` → `variant` for consistency
- **Dependencies added:**
  - `lifecycle-viewmodel-compose` for `viewModel()` composable
- **Bug fixes:**
  - Fixed API response parsing (`List<ProtocolResponse>` not `ProtocolListResponse`)
  - Fixed `PepTextField` parameter names (`error` not `isError`/`errorMessage`)
  - Fixed `PepBadge` usage (`style = PepBadgeStyle.Success` not `isActive`)
  - Fixed `CornerRadius.sm/md/pill` imports (was `Spacing.radiusSm` etc.)
  - Fixed `keyboardType` parameter (not `keyboardOptions`)
- **UX improvements to CreateProtocolScreen:**
  - Added `imePadding()` for keyboard-aware scrolling
  - Added tap-outside-to-dismiss keyboard (`pointerInput` + `detectTapGestures`)
  - Added `imeAction = ImeAction.Done` to text fields for Enter key behavior
  - Added `focusManager.clearFocus()` on ime action
- **Backend README updated:**
  - Python 3.11/3.12 requirement (3.13+ not supported)
  - Port changed to 8001 throughout
  - PowerShell syntax for Windows
- **Future requirements documented:**
  - Pre-auth onboarding questionnaire (ESSENTIAL)
  - Social auth (Google, Apple sign-in)
  - Login persistence verification
  - UX/UI polish priority noted
- **Phase 2 status:** ✅ Core complete (2a-2d, 2f done; 2e Edit screen deferred)

### 2026-05-27 — Phase 2e Autocomplete + Phase 3 Planning
- **PeptideData.kt created:**
  - 60+ peptides organized by category (GLP-1, GHRP, Healing, Cognitive, etc.)
  - Each entry has name, category, and common dose info
  - `peptideNames` list for autocomplete suggestions
- **PepAutocompleteField component created:**
  - Reusable autocomplete text field using `ExposedDropdownMenuBox`
  - Filters suggestions as user types (case-insensitive)
  - Shows up to 10 suggestions with max height 200dp
  - Users can type custom names OR select from list
  - Matches design system (Rust500 focus, Cream50 background)
- **CreateProtocolScreen updated:**
  - Compound name field now uses `PepAutocompleteField`
  - Suggestions sourced from `peptideNames` list
  - UX: scroll through suggestions without leaving keyboard
- **Phase 2 status:** ✅ COMPLETE (all slices 2a-2f done)

### 2026-05-27 (continued) — Phase 2 Bug Fixes
- **Bug 1: Edit button crash fixed:**
  - Root cause: `Routes.PROTOCOL_EDIT` had no `composable()` handler
  - Fix: Added edit route to AppNavigation.kt
- **Bug 2: Protocol reactivation fixed:**
  - Root cause: Backend has no `/activate` endpoint — only `/deactivate`
  - Fix: Changed `activateProtocol()` to use `updateProtocol(isActive = true)`
- **Edit mode fully implemented:**
  - `CreateProtocolScreen` now accepts optional `protocolId` parameter
  - Pre-fills form with existing protocol data when editing
  - Button text adapts: "Create Protocol" vs "Update Protocol"
  - `updateProtocolFull()` added to ViewModel (updates metadata + compounds)
- **API additions:**
  - `PUT /protocols/{id}/compounds` endpoint added to ApiService
  - `CompoundsReplaceRequest` model added to ApiModels.kt
- **Phase 2 status:** ✅ FULLY COMPLETE with bug fixes
- **Next:** Phase 3 (Check-ins) planned and ready for implementation

### 2026-05-28 — Phase 3 Android Check-ins Complete
- **New screens:**
  - `features/checkin/ui/CheckinScreen.kt` — full check-in flow with weight, mood, energy, sleep, symptoms, notes
  - `features/checkin/viewmodel/CheckinViewModel.kt` — state + submission logic
- **API integration (`core/network/`):**
  - `ApiModels.kt` — added `CheckinRequest`, `CheckinResponse`, `SymptomRequest`/`SymptomResponse` models
  - `ApiService.kt` — added `POST /checkins`, `GET /checkins`, `GET /checkins/{id}` endpoints
  - `ApiClient.kt` — wired check-in endpoints into the generic execute layer
- **Navigation:** Check-in tab in `MainScreen.kt` now opens `CheckinScreen` (was placeholder)
- **MainActivity.kt:** updated to include check-in routing
- **Gradle:** added one dependency to `app/build.gradle.kts`
- **Backend fix:** added missing package to `backend/requirements.txt` (resolved a runtime import error during check-in submission)
- **Polish pass:** CheckinScreen iterated +402 lines after slices a-e (validation, error states, UX refinements)
- **Phase 3 status:** ✅ COMPLETE (Android, slices 3a–3e)
- **Next:** Phase 4 (Dashboard) — unified home view with active protocol, weight chart, recent check-ins, unread insights

### 2026-05-28 — Web Landing Site Redesign (peppy.app)
**Goal:** Upgrade the Next.js 16 landing site from generic-minimal to a professional, motion-rich, design-system-compliant experience that "wows".

- **Stack additions:**
  - `motion` (formerly framer-motion) — scroll/hover/stagger animations
  - `lucide-react` — SVG icon set (replaced all emojis per design system)
- **Design system v2 compliance fixes:**
  - Page background switched from pure white to cream `#FAF7F0`
  - All sections use Plus Jakarta Sans; Nunito reserved for `.peppy-wordmark`; Fraunces italic via semantic `<em class="peppy-accent">` (max 2 per page, e.g., "body", "optimize")
  - Weight ceiling 700, sentence case, pill buttons, no card shadows, no bouncy easings
- **Hero — two-column layout** (inspired by levelshealth.com / whoop.com):
  - Left: eyebrow chip, large headline with Fraunces accent, subtitle, two CTAs, trust stats (500+ waitlist / 60+ peptides / AES-256) above a hairline divider
  - Right: pure-CSS iPhone mockup (`rounded-[36px]` ink bezel, notch pill, `rounded-[30px]` cream screen) containing greeting, rust recovery card with animated 84% ring, quick check-in row (Smile/Zap/Moon Lucide icons), AI insight card with rust left-border accent and rotating text, next-dose reminder
- **Nav:** scroll-aware — transparent at top, translucent backdrop-blur + border once scrolled past 12px; mobile menu fade/slide
- **Features section:** mobile = stacked rounded cards; desktop = bordered hairline grid (md+) with scroll-stagger reveal and cream hover tint
- **HowItWorks:** vertical gradient connector line that draws downward on scroll, numbered rust badges
- **CTA:** dark ink section with rust ambient glow, inline email capture (ArrowRight micro-interaction), success state with checkmark
- **Footer:** unified container, two-column with link grid
- **Inner pages (`/features`, `/about`, `/waitlist`):**
  - All wrapped in `mx-auto max-w-Nxl px-6 md:px-8` (`max-w-6xl` outer, narrower inner columns for readability)
  - Top padding `pt-32 md:pt-40` clears the fixed 64px nav
  - Above-the-fold motion uses `animate` (immediate) instead of `whileInView` to prevent SSR opacity:0 → invisible content during hydration delays
- **Globals:** added motion easing tokens (`--ease-out-peppy`), `peppy-glow` radial helper, `peppy-noise` SVG noise utility, full `prefers-reduced-motion` reset
- **Verified:** production build clean (TypeScript ✓, 5 routes statically prerendered), HMR compiles in 40–270ms
- **Hydration warning** in dev logs is from browser form-filler extensions injecting `fdprocessedid` — not our code
- **Next:** integrate Mailchimp/ConvertKit on `/waitlist`, hook up Plausible/Posthog, deploy to Vercel
