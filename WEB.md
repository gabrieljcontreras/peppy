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

- **Palette**: Rust `#E07A5F` (primary), Ink `#1E2026` (dark), Cream `#FFFAF3` (surface), Success `#81B29A`, Info `#7EB8C9`, Warning `#F2CC8F`
- **Radius**: sm `10px`, md `16px`, lg `24px`, pill `9999px`
- **Motion**: `cubic-bezier(0.19, 1, 0.22, 1)` — durations 150 / 250 / 600ms
- **Scroll reveal**: IntersectionObserver via `useScrollReveal` hook + `<Reveal>` wrapper — no external deps
- **Brand**: Always lowercase "peppy"

Tokens live in `web/src/app/globals.css` as CSS custom properties and are mapped into Tailwind via `@theme inline`.

## Directory Structure

```
web/src/
  app/
    layout.tsx              Root layout (fonts, metadata)
    page.tsx                Home page
    globals.css             Design tokens + base styles
    about/page.tsx          About page
    waitlist/page.tsx       Waitlist / early access signup
    privacy/page.tsx        Privacy policy
    terms/page.tsx          Terms of service
    api/
      waitlist/route.ts     POST proxy → backend /api/v1/waitlist
      health/route.ts       GET health check proxy
  components/
    Nav.tsx                 Sticky pill navbar (server component shell)
    NavShell.tsx            Client wrapper — scroll-aware opacity transition
    Logo.tsx                SVG logo + wordmark
    PhoneMock.tsx           Hero device mockups (responsive)
    Sections.tsx            All home-page sections (Hero, Features, Records, NotAll, Testimonials, CTA, Footer)
    Reveal.tsx              Scroll-reveal animation wrapper (client)
    PageShell.tsx           Shared Nav + main + Footer layout
    WaitlistForm.tsx        Email capture form (client, posts to /api/waitlist)
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
| `/waitlist` | Static | Email capture + FAQ |
| `/privacy` | Static | Privacy policy |
| `/terms` | Static | Terms of service |
| `/api/waitlist` | Dynamic | POST — proxies to backend waitlist endpoint |
| `/api/health` | Dynamic | GET — checks web + backend health |

## Development

```sh
cd web
npm install
npm run dev          # Dev server on port 3000
npm run build        # Production build
npm run lint         # ESLint
npm run type-check   # TypeScript check (tsc --noEmit)
```

## Environment Variables

| Variable | Scope | Default | Description |
|----------|-------|---------|-------------|
| `NEXT_PUBLIC_API_URL` | Client + Server | `http://localhost:8001` | Backend API base URL |
| `API_URL` | Server only | `http://localhost:8001` | Backend URL for route handlers |

Set in `web/.env.local` (gitignored).

## Backend Integration

The web app connects to the FastAPI backend via Next.js route handlers (server-side proxy). This avoids exposing the backend URL to the client and handles CORS cleanly.

- **Waitlist signup**: `POST /api/waitlist` → backend `POST /api/v1/waitlist`
- **Health check**: `GET /api/health` → backend `GET /health`
- **API client**: `web/src/lib/api.ts` — thin fetch wrapper with `ApiError` class

Backend CORS is configured to allow `localhost:3000` (dev) and production domains. See `backend/app/main.py`.

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

### 2026-06-01 — v0.2.0: Design polish, new pages, backend integration, CI/CD

- Added scroll-reveal animations (IntersectionObserver) across all home sections
- Added smooth scroll with nav offset
- Enhanced hover states (FeatureCards, footer icons, accordion arrows, CTA glow)
- Created NavShell with scroll-aware opacity transition
- Made phone mock responsive, hide watch on mobile
- Added /waitlist page with email capture form
- Added /about page with mission, values, CTA
- Added /privacy and /terms legal pages
- Created PageShell for shared Nav/Footer layout
- Built API route handlers for waitlist signup and health check
- Created backend waitlist endpoint (POST /api/v1/waitlist)
- Tightened backend CORS from wildcard to specific origins
- Added API client utility (lib/api.ts)
- Set up GitHub Actions CI pipeline (lint, type-check, build)
- Added Vercel deployment config
- Updated footer links to point to real pages
- Updated nav CTA to "Join waitlist", logo links to "/"
