# peppy web

Marketing and landing site for the peppy peptide protocol tracking app.

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16.2.6 (App Router) |
| React | 19.2.4 |
| Styling | Tailwind CSS v4 + PostCSS |
| Fonts | Plus Jakarta Sans (body, 95%), Fraunces (italic accents), Nunito (logo wordmark) |
| Deployment | Vercel (preview on PR, production on main) |
| CI | GitHub Actions — lint, type-check, build |
| Backend | FastAPI on port 8001 (separate service, see BACKEND_HANDOFF.md) |

## Design System

Sourced from the iOS app designs in `web/src/Peppy IOS.fig` — colors sampled directly from the exported screens, so web and app share one visual language.

- **Palette**: Coral `#EA584C` (primary, `rust-500`; scale 100–900), Ink `#212126` (text, `ink-900`; scale 50–900), Cream `#FCF8F3` (page bg, `cream-100`) / `#FEFBF8` (cards, `cream-50`)
- **Pastel tints** (feature cards, icon chips): Rose `#FBE5E0`, Sage `#E5EFE4`, Sky `#E4ECF5`, Butter `#FBF0D9`, Lavender `#ECE7F7` — usable as `bg-tint-rose` etc.
- **Borders**: subtle `#F0E9E0`, default `#E2D9CC`
- **Radius**: sm `10px`, md `16px`, lg `24px`, pill `9999px`
- **Motion**: `cubic-bezier(0.19, 1, 0.22, 1)` — durations 150 / 250 / 600ms
- **Scroll reveal**: IntersectionObserver via `useScrollReveal` hook + `<Reveal>` wrapper — no external deps
- **Brand**: Always lowercase "peppy"

Tokens live in `web/src/app/globals.css` as CSS custom properties and are mapped into Tailwind via `@theme inline`.

## Directory Structure

```
web/
  public/app/             Real app screens (webp) extracted from Peppy IOS.fig, shown in PhoneFrame
  scripts/screenshot.mjs  Playwright visual-QA script (desktop/tablet/mobile captures)
web/src/
  Peppy IOS.fig           Figma design source (not imported by code)
  app/
    layout.tsx              Root layout (fonts, metadata)
    page.tsx                Home page
    globals.css             Design tokens + base styles
    about/page.tsx          About page
    contact/page.tsx        Contact page
    waitlist/page.tsx       Waitlist / early access signup
    feedback/
      bug/page.tsx          Bug report form
      feature/page.tsx      Feature request form
    privacy/page.tsx        Privacy policy
    terms/page.tsx          Terms of service
    api/
      waitlist/route.ts     POST proxy → backend /api/v1/waitlist
      feedback/route.ts     POST proxy → backend feedback endpoint
      health/route.ts       GET health check proxy
  components/
    Nav.tsx                 Sticky pill navbar (server component shell)
    NavShell.tsx            Client wrapper — scroll-aware opacity transition
    Logo.tsx                SVG logo + wordmark
    PhoneMock.tsx           PhoneFrame — device frame around real app screenshots (next/image)
    Sections.tsx            All home-page sections (Hero, WorksWith, Features, FeatureRows, NotAll, Privacy, Testimonials, CTA, Footer)
    Reveal.tsx              Scroll-reveal animation wrapper (client)
    PageShell.tsx           Shared Nav + main + Footer layout
    WaitlistForm.tsx        Email capture form (client, posts to /api/waitlist)
    FeedbackForm.tsx        Bug / feature feedback form (client, posts to /api/feedback)
  hooks/
    useScrollReveal.ts      IntersectionObserver hook, respects prefers-reduced-motion
  lib/
    api.ts                  Backend fetch utility (ApiError class)
```

## Routes

| Path | Type | Description |
|------|------|-------------|
| `/` | Static | Landing page — hero, features, records, testimonials, CTA |
| `/about` | Static | Mission, values, CTA |
| `/contact` | Static | Contact information |
| `/waitlist` | Static | Email capture + FAQ |
| `/feedback/bug` | Static | Bug report form |
| `/feedback/feature` | Static | Feature request form |
| `/privacy` | Static | Privacy policy |
| `/terms` | Static | Terms of service |
| `/api/waitlist` | Dynamic | POST — proxies to backend waitlist endpoint |
| `/api/feedback` | Dynamic | POST — proxies to backend feedback endpoint |
| `/api/health` | Dynamic | GET — checks web + backend health |

## Development

```sh
cd web
npm install
npm run dev          # Dev server on port 3000 (use `npx next dev -p 3005` if 3000 is taken)
npm run build        # Production build
npm run lint         # ESLint
npm run type-check   # TypeScript check (tsc --noEmit)

# Visual QA — captures desktop/tablet/mobile screenshots into web/screenshots/<TAG>/
URL=http://localhost:3005 TAG=my-run node scripts/screenshot.mjs
```

Note: the screenshot script scrolls with `behavior: "instant"` — the site sets `scroll-behavior: smooth`, which would otherwise animate past sections and IntersectionObserver reveals at the bottom of the page would never fire.

## Environment Variables

| Variable | Scope | Default | Description |
|----------|-------|---------|-------------|
| `NEXT_PUBLIC_API_URL` | Client + Server | `http://localhost:8001` | Backend API base URL |
| `API_URL` | Server only | `http://localhost:8001` | Backend URL for route handlers |

Set in `web/.env.local` (gitignored).

## Backend Integration

The web app connects to the FastAPI backend via Next.js route handlers (server-side proxy). This avoids exposing the backend URL to the client and handles CORS cleanly.

- **Waitlist signup**: `POST /api/waitlist` → backend `POST /api/v1/waitlist`
- **Feedback**: `POST /api/feedback` → backend feedback endpoint
- **Health check**: `GET /api/health` → backend `GET /health`
- **API client**: `web/src/lib/api.ts` — thin fetch wrapper with `ApiError` class

Backend CORS is configured to allow `localhost:3000` (dev) and production domains. See `backend/app/main.py`.

The backend ships as a Docker image (`backend/Dockerfile`, `backend/.dockerignore`) and is deployed to Railway. The initial Alembic migration (`backend/alembic/versions/19381cefe6c7_initial_schema.py`) creates all 13 tables on first boot.

## CI/CD

**GitHub Actions** (`.github/workflows/web.yml`):
- Triggers on push/PR to `main` when `web/**` files change
- Steps: checkout → setup-node 20 → npm ci → lint → type-check → build

**Vercel**:
- Root directory: `web/`
- Preview deployments on PRs
- Production deploy on merge to main
- Config: `web/vercel.json`

## Conventions

- Brand name is always "peppy" (lowercase)
- Plus Jakarta Sans for 95% of text; Fraunces italic for emphasis words in headings
- All animations respect `prefers-reduced-motion`
- Check `node_modules/next/dist/docs/` before using any Next.js API (per AGENTS.md)
- No external animation libraries — pure CSS transitions + IntersectionObserver

## Changelog

### 2026-06-11 — v0.3.0: Homepage redesign from Figma (Peppy IOS.fig)

Homepage rebuilt around the iOS app designs in `web/src/Peppy IOS.fig`, with bevel.health as the polish benchmark.

- Extracted 56 screen renders from the .fig (it's a ZIP archive); optimized 10 of them to `web/public/app/*.webp` (720px wide, q90, 50–85KB each)
- Resampled all design tokens from the .fig renders: coral `#EA584C` replaces `#E07A5F`, ink `#212126`, cream `#FCF8F3`/`#FEFBF8`, plus five pastel tints (rose/sage/sky/butter/lavender) — full scales in `globals.css`
- Rewrote `PhoneMock.tsx` as `PhoneFrame`: dark device frame around real app screenshots via next/image (replaces the hand-drawn CSS mockup)
- Rewrote `Sections.tsx`:
  - **Hero** — "Your protocol, understood." with home screen in PhoneFrame + four floating stat cards (weight trend, check-in streak, next dose, sleep) on `peppy-float` animation
  - **WorksWith** — marquee of integration chips (Apple Health, Oura, Whoop, Garmin) via `.peppy-marquee` (CSS mask edges, 32s loop, pauses on hover)
  - **Features** — Protocols / Check-ins / Insights trio, app screens cropped inside pastel-tinted cards with hover lift
  - **FeatureRows** — alternating rows (connect health data / notifications / side-effects) with eyebrow labels and check-chip bullets
  - **NotAll** — accordion (AI weekly summary, lab uploads, provider exports, guided onboarding) beside the "ready" screen
  - **Privacy** — dark ink-900 card: "Private by design." with encrypted/never-sold/export chips
  - **CTA** — coral card "Make this week make sense." → /waitlist
- `globals.css`: added `.peppy-marquee` and `.peppy-float` animations, retuned `.peppy-tile-*` gradients and `.peppy-aura`; removed `.peppy-bargraph`
- `scripts/screenshot.mjs`: scroll-through pass so IntersectionObserver reveals fire before capture, using `behavior: "instant"` (smooth scrolling animated past bottom sections, leaving them unrevealed in tablet captures); section-level captures updated to new section ids
- `useScrollReveal.ts`: reduced-motion path sets visibility inside requestAnimationFrame (fixes `react-hooks/set-state-in-effect` lint error)

### 2026-06-02 — Deployment hotfixes

- Synced `web/package-lock.json` with `package.json` so Vercel `npm ci` stops failing on `@emnapi/runtime` and `@emnapi/core` drift
- Tightened `web/vercel.json` (explicit `buildCommand`, `outputDirectory`, `installCommand`)
- `backend/app/config.py`: strip whitespace from `DATABASE_URL` before the `postgresql://` → `postgresql+asyncpg://` conversion (Railway env values can have stray spaces)
- `backend/alembic/env.py`: keep the `+asyncpg` driver in the URL so `async_engine_from_config` doesn't fall back to psycopg2 and crash on Railway

### 2026-06-01 — v0.2.0: Design polish, new pages, backend integration, CI/CD

- Added scroll-reveal animations (IntersectionObserver) across all home sections
- Added smooth scroll with nav offset
- Enhanced hover states (FeatureCards, footer icons, accordion arrows, CTA glow)
- Created NavShell with scroll-aware opacity transition
- Made phone mock responsive, hide watch on mobile
- Added /waitlist page with email capture form
- Added /about page with mission, values, CTA
- Added /contact page
- Added /feedback/bug and /feedback/feature forms (FeedbackForm + `/api/feedback` proxy)
- Added /privacy and /terms legal pages
- Created PageShell for shared Nav/Footer layout
- Built API route handlers for waitlist signup and health check
- Created backend waitlist endpoint (POST /api/v1/waitlist)
- Tightened backend CORS from wildcard to specific origins
- Added API client utility (lib/api.ts)
- Set up GitHub Actions CI pipeline (lint, type-check, build)
- Added Vercel deployment config (`web/vercel.json`)
- Added backend Docker image (`backend/Dockerfile`, `.dockerignore`) for Railway deploys
- Added initial Alembic migration (`19381cefe6c7_initial_schema`) covering all 13 tables
- Auto-fix `DATABASE_URL` prefix (`postgresql://` → `postgresql+asyncpg://`) in `backend/app/config.py` for Railway
- Updated footer links to point to real pages
- Updated nav CTA to "Join waitlist", logo links to "/"
