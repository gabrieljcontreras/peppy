import Link from "next/link";
import { HeroPhone, HeroWatch } from "./PhoneMock";
import { Logo, Wordmark } from "./Logo";
import { Reveal } from "./Reveal";

/* ------------------------------- HERO ------------------------------- */
export function Hero() {
  return (
    <header className="relative overflow-hidden px-6 pt-16 text-center">
      <div className="peppy-aura" aria-hidden="true" />

      <div className="relative z-10 mx-auto max-w-[860px]">
        <p className="peppy-fade peppy-fade-2 inline-flex items-center gap-2 rounded-full border border-border-subtle bg-cream-50/70 px-3 py-1 text-[13px] font-medium text-ink-700 backdrop-blur">
          <span className="inline-block h-1.5 w-1.5 rounded-full bg-rust-500" />
          Now in early access
        </p>

        <h1
          className="peppy-fade peppy-fade-2 mx-auto mt-5 text-[clamp(44px,6.4vw,76px)] font-semibold leading-[1.02] tracking-[-0.025em] text-ink-900"
          style={{ textWrap: "balance" }}
        >
          Your protocol,
          <br />
          <em className="font-serif italic font-medium text-rust-500">
            understood.
          </em>
        </h1>

        <p className="peppy-fade peppy-fade-3 mx-auto mt-6 max-w-[560px] text-[19px] leading-[1.55] text-ink-700">
          Log peptide protocols, daily check-ins, weight and wearables.
          peppy connects the dots so you can see what&apos;s actually working.
        </p>

        <div className="peppy-fade peppy-fade-3 mt-8 flex flex-wrap items-center justify-center gap-3">
          <a
            href="#download"
            className="inline-flex items-center gap-2 rounded-full bg-ink-900 px-5 py-3.5 text-[15px] font-semibold text-cream-50 transition-all hover:bg-ink-700 hover:-translate-y-px active:translate-y-0"
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M17.6 13.1c-.04-3.1 2.53-4.6 2.65-4.67-1.45-2.12-3.7-2.4-4.5-2.44-1.92-.2-3.74 1.13-4.71 1.13-.98 0-2.48-1.1-4.07-1.07-2.1.03-4.04 1.22-5.12 3.1-2.18 3.78-.56 9.37 1.57 12.44 1.04 1.5 2.28 3.18 3.9 3.12 1.56-.06 2.15-1.01 4.03-1.01 1.87 0 2.4 1.01 4.06.98 1.67-.03 2.74-1.52 3.77-3.04 1.18-1.74 1.67-3.43 1.7-3.52-.04-.02-3.26-1.25-3.3-4.92ZM14.7 4.06c.86-1.04 1.44-2.49 1.28-3.93-1.24.05-2.74.82-3.62 1.86-.79.93-1.48 2.4-1.3 3.82 1.38.1 2.78-.7 3.64-1.75Z" />
            </svg>
            Download for iOS
          </a>
          <a
            href="#features"
            className="inline-flex items-center gap-2 rounded-full border border-border-default px-5 py-3.5 text-[15px] font-semibold text-ink-900 transition-colors hover:border-ink-900"
          >
            See how it works
          </a>
        </div>

        <div className="peppy-fade peppy-fade-4 mt-5 inline-flex items-center gap-2 text-[13px] text-ink-700">
          <span className="text-rust-500 text-[14px] tracking-[1px]">★★★★★</span>
          <span>
            <b className="text-ink-900">4.9</b> · early users report sharper insights in week one
          </span>
        </div>
      </div>

      {/* device cluster */}
      <div className="peppy-fade peppy-fade-4 relative z-10 mx-auto mt-14 flex max-w-[840px] items-end justify-center gap-6">
        <HeroPhone />
        <HeroWatch />
      </div>

      {/* QR card */}
      <div className="absolute right-6 bottom-6 z-20 hidden items-center gap-3 rounded-2xl bg-ink-900 p-3 pl-4 text-cream-50 shadow-[0_10px_24px_rgba(0,0,0,0.18)] md:flex">
        <div
          aria-hidden="true"
          className="h-14 w-14 rounded-md"
          style={{
            background:
              "repeating-linear-gradient(0deg, #fff 0 4px, #1e2026 4px 8px), repeating-linear-gradient(90deg, #fff 0 4px, #1e2026 4px 8px)",
            backgroundBlendMode: "multiply",
          }}
        />
        <div>
          <small className="block text-[11px] text-ink-300">Scan to install</small>
          <b className="text-[13px] leading-tight">
            peppy for iPhone
            <br />Free in early access.
          </b>
        </div>
      </div>
    </header>
  );
}

/* ----------------------------- FEATURES ----------------------------- */
type FeatureCardProps = {
  bg: string;
  title: string;
  copy: string;
  children: React.ReactNode;
};

function FeatureCard({ bg, title, copy, children }: FeatureCardProps) {
  return (
    <article
      className="flex min-h-[380px] flex-col overflow-hidden rounded-3xl px-7 pt-7 transition-all duration-300 hover:-translate-y-1 hover:shadow-lg"
      style={{ background: bg }}
    >
      <h3 className="text-[26px] font-semibold leading-tight tracking-[-0.015em] text-ink-900">
        {title}
      </h3>
      <p className="mt-2 max-w-[260px] text-[14.5px] leading-snug text-ink-700">
        {copy}
      </p>
      <div className="mx-auto mt-5 flex w-[84%] flex-1 flex-col gap-2.5 rounded-t-2xl border border-b-0 border-ink-100/70 bg-cream-50 p-4 text-[12px]">
        {children}
      </div>
    </article>
  );
}

export function Features() {
  return (
    <section id="features" className="py-24">
      <div className="mx-auto max-w-[1280px] px-6">
        <Reveal>
          <div className="mx-auto mb-14 max-w-[640px] text-center">
            <h2 className="text-[clamp(32px,4.4vw,56px)] font-semibold leading-[1.05] tracking-[-0.02em] text-ink-900">
              Start the day
              <br />
              with <em className="font-serif text-rust-500">clarity</em>.
            </h2>
            <p className="mt-3 text-[17px] text-ink-700">
              Turn what you&apos;re doing, and how you feel, into clear
              actionable signal.
            </p>
          </div>
        </Reveal>

        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
          {([
            {
              bg: "#fce0dc",
              title: "Protocol",
              copy: "Compounds, doses and schedules in one tidy log with smart reminders.",
              content: (
                <>
                  <div className="flex items-center justify-between">
                    <b className="text-[13px]">Retatrutide</b>
                    <span className="rounded-full bg-rust-500 px-2.5 py-0.5 text-[11px] font-semibold text-cream-50">
                      4 mg · wk 6
                    </span>
                  </div>
                  <div className="flex items-center justify-between border-b border-ink-100/70 pb-2 text-[11px] text-ink-500">
                    <span>Mon · 3.5 mg</span><span className="text-success">✓</span>
                  </div>
                  <div className="flex items-center justify-between border-b border-ink-100/70 pb-2 text-[11px] text-ink-500">
                    <span>Sun · 4 mg titrate</span><span className="text-success">✓</span>
                  </div>
                  <div className="flex items-center justify-between text-[11px] text-ink-500">
                    <span>This Sun · 4 mg</span>
                    <span className="rounded-full bg-ink-100 px-2 py-0.5 text-ink-700">due</span>
                  </div>
                  <div className="mt-auto flex justify-between border-t border-ink-100/70 pt-2 text-[11px] text-ink-500">
                    <small>titration</small>
                    <small>maintenance</small>
                  </div>
                </>
              ),
            },
            {
              bg: "#e6efe4",
              title: "Check-ins",
              copy: "30 seconds a day. Weight, mood, side-effects, energy.",
              content: (
                <>
                  <div className="flex items-center justify-between">
                    <b className="text-[13px]">This week</b>
                    <span className="rounded-full bg-success/20 px-2.5 py-0.5 text-[11px] font-semibold text-success">
                      6 / 7 days
                    </span>
                  </div>
                  <div className="flex h-[70px] items-end gap-1 py-1.5">
                    {[30, 55, 80, 45, 65, 35, 70].map((h, i) => (
                      <span
                        key={i}
                        className="flex-1 rounded-[3px]"
                        style={{
                          height: `${h}%`,
                          background:
                            i % 2 === 0 ? "var(--peppy-rust-500)" : "var(--peppy-success)",
                        }}
                      />
                    ))}
                  </div>
                  <div className="flex justify-between text-[11px] text-ink-500">
                    <span>M</span><span>T</span><span>W</span><span>T</span><span>F</span><span>S</span><span>S</span>
                  </div>
                  <div className="mt-2 flex items-center gap-2 rounded-lg bg-success/10 px-2 py-1.5 text-[11px] text-success">
                    <span className="inline-block h-1.5 w-1.5 rounded-full bg-success" />
                    <b>21-day streak</b>
                  </div>
                  <small className="mt-auto text-[11px] text-ink-500">
                    consistency builds signal
                  </small>
                </>
              ),
            },
            {
              bg: "#fdf0d6",
              title: "Insights",
              copy: "Trends, anomalies, and what's actually moving the needle.",
              content: (
                <>
                  <div className="flex items-center justify-between">
                    <b className="text-[13px]">Readiness</b>
                    <span className="rounded-full bg-rust-500/15 px-2.5 py-0.5 text-[11px] font-semibold text-rust-700">
                      72%
                    </span>
                  </div>
                  <div className="flex items-center justify-center gap-3 py-2">
                    <div
                      className="relative grid h-[72px] w-[72px] place-items-center rounded-full"
                      style={{
                        background:
                          "conic-gradient(var(--peppy-rust-500) 0 72%, #eef0f4 72%)",
                      }}
                    >
                      <span className="absolute inset-1.5 rounded-full bg-cream-50" />
                      <span className="relative text-[16px] font-bold text-ink-900">72%</span>
                    </div>
                    <div className="flex flex-col gap-1 text-[11px]">
                      <span className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-rust-500" /> Sleep <b className="ml-auto text-ink-900">7h 18m</b></span>
                      <span className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-success" /> HRV <b className="ml-auto text-ink-900">54</b></span>
                      <span className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-info" /> RHR <b className="ml-auto text-ink-900">51</b></span>
                    </div>
                  </div>
                  <div className="rounded-lg bg-rust-500/10 p-2 text-[11px] leading-snug text-rust-700">
                    <b>Insight</b> · weight loss accelerating, likely from sleep gain
                  </div>
                  <small className="mt-auto text-[11px] text-ink-500">
                    energy &amp; recovery
                  </small>
                </>
              ),
            },
          ] as const).map((card, i) => (
            <Reveal key={card.title} delay={i * 120}>
              <FeatureCard bg={card.bg} title={card.title} copy={card.copy}>
                {card.content}
              </FeatureCard>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ------------------------- RECORDS / FLOATING CARDS ------------------- */
type Float = {
  dot: string;
  title: string;
  sub: string;
  pos: React.CSSProperties;
};

const floats: Float[] = [
  {
    dot: "var(--peppy-rust-500)",
    title: "Weight check-in",
    sub: "184.5 lb · -2.3 wk",
    pos: { top: 0, left: "8%", transform: "rotate(-5deg)" },
  },
  {
    dot: "var(--peppy-success)",
    title: "Lab: fasting glucose",
    sub: "91 mg/dL · in range",
    pos: { top: "28%", left: "38%", transform: "rotate(3deg)" },
  },
  {
    dot: "var(--peppy-rust-300)",
    title: "Dose logged",
    sub: "Reta 4 mg · Sun",
    pos: { top: "8%", right: "4%", transform: "rotate(8deg)" },
  },
  {
    dot: "var(--peppy-warning)",
    title: "Side-effect note",
    sub: "Mild nausea · day 2",
    pos: { bottom: "6%", left: "20%", transform: "rotate(-2deg)" },
  },
  {
    dot: "var(--peppy-info)",
    title: "Oura sync",
    sub: "Sleep 7h 18m · HRV 54",
    pos: { bottom: "16%", right: "14%", transform: "rotate(6deg)" },
  },
];

export function Records() {
  return (
    <section id="records" className="py-16">
      <div className="mx-auto max-w-[1280px] px-6">
        <div className="grid items-center gap-12 rounded-3xl bg-cream-50 p-10 md:grid-cols-2 md:p-16">
          <Reveal>
            <div className="relative h-[380px]" aria-hidden="true">
              {floats.map((f, i) => (
                <div
                  key={i}
                  className="absolute flex items-center gap-2.5 rounded-2xl border border-border-subtle bg-cream-50 px-4 py-3 text-[13px] shadow-[0_12px_30px_rgba(30,32,38,0.08)] transition-transform duration-500 hover:!rotate-0 hover:-translate-y-1"
                  style={f.pos}
                >
                  <span
                    className="h-7 w-7 flex-none rounded-lg"
                    style={{ background: f.dot }}
                  />
                  <div>
                    <b className="block text-ink-900">{f.title}</b>
                    <small className="text-ink-500">{f.sub}</small>
                  </div>
                </div>
              ))}
            </div>
          </Reveal>

          <Reveal direction="right" delay={150}>
            <div>
              <h2 className="text-[clamp(32px,4.2vw,52px)] font-semibold leading-[1.05] tracking-[-0.02em] text-ink-900">
                Everything
                <br />
                in one
                <br />
                <em className="font-serif text-rust-500">timeline.</em>
              </h2>
              <p className="mt-5 max-w-[400px] text-ink-700">
                Doses, check-ins, labs, side-effects and wearable data. Kept
                private, encrypted, and yours to take to your provider.
              </p>
              <a
                href="#"
                className="mt-7 inline-flex items-center gap-2 rounded-full bg-ink-900 px-5 py-3 text-[15px] font-semibold text-cream-50 transition-all hover:bg-ink-700 hover:-translate-y-px"
              >
                See what gets tracked
              </a>
            </div>
          </Reveal>
        </div>
      </div>
    </section>
  );
}

/* ---------------------- NOT ALL — ACCORDION ROWS --------------------- */
const accordion = [
  {
    title: "AI weekly summary",
    body: "A short, plain-English readout of how your week went and what to try next.",
    active: true,
  },
  {
    title: "Wearable sync",
    body: "Oura, Whoop, Apple Health and Garmin, pulled in automatically.",
  },
  {
    title: "Lab uploads",
    body: "Snap a photo or attach a PDF. peppy parses the values and tracks them over time.",
  },
  {
    title: "Provider-ready exports",
    body: "Generate a clean PDF of your protocol and metrics to share with your clinician.",
  },
];

export function NotAll() {
  return (
    <section id="more" className="py-24">
      <div className="mx-auto grid max-w-[1280px] items-center gap-16 px-6 md:grid-cols-[1.05fr_0.95fr]">
        <div>
          <Reveal>
            <h2 className="text-[clamp(32px,4.4vw,56px)] font-semibold leading-[1.05] tracking-[-0.02em] text-ink-900">
              And that&apos;s
              <br />
              not all.
            </h2>
            <p className="mt-3 text-ink-700">peppy also includes:</p>
          </Reveal>

          <div className="mt-8 flex flex-col gap-3">
            {accordion.map((row, i) => (
              <Reveal key={i} delay={i * 80}>
                <div
                  className={`group flex items-start justify-between gap-4 rounded-2xl p-6 transition-colors duration-300 ${
                    row.active
                      ? "bg-rust-500/10"
                      : "bg-cream-50 hover:bg-cream-200"
                  }`}
                >
                  <div>
                    <h3 className="text-[18px] font-semibold text-ink-900">
                      {row.title}
                    </h3>
                    <p className="mt-1 text-[14px] text-ink-700">{row.body}</p>
                  </div>
                  <span
                    className={`grid h-9 w-9 flex-none place-items-center rounded-full border border-border-subtle text-ink-900 transition-all group-hover:border-ink-900 group-hover:bg-ink-900 group-hover:text-cream-50 group-hover:translate-x-1 ${
                      row.active ? "bg-ink-900 text-cream-50 border-ink-900" : ""
                    }`}
                  >
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M5 12h14M13 6l6 6-6 6" />
                    </svg>
                  </span>
                </div>
              </Reveal>
            ))}
          </div>
        </div>

        {/* right phone mock */}
        <div className="flex justify-center">
          <div
            className="rounded-[40px] bg-ink-900 p-2 shadow-[0_24px_64px_rgba(30,32,38,0.18)]"
            style={{ width: 300, height: 600 }}
          >
            <div className="flex h-full w-full flex-col gap-3 rounded-[32px] bg-cream-50 px-4 pt-5">
              <div className="flex justify-between text-[11px] font-semibold">
                <span>9:41</span>
                <span>•••</span>
              </div>
              <small className="text-center text-[12px] text-ink-500">
                Weekly summary
              </small>
              <small className="-mt-1 text-center text-[12px] text-ink-700">
                Week of May 24
              </small>

              <div className="mt-2 text-center">
                <div className="text-[56px] font-bold leading-none text-rust-500">
                  −2.3
                </div>
                <small className="text-ink-500">lbs vs last week</small>
              </div>

              <div className="rounded-2xl bg-rust-500/10 p-3 text-[12px] leading-snug text-ink-900">
                <b>83% confidence</b>
                <br />
                <small className="text-ink-700">
                  Loss is steepening, possible plateau break.
                </small>
              </div>

              <div>
                <small className="text-ink-500">What changed</small>
                <div className="mt-2 flex flex-col gap-2.5">
                  <div className="flex items-center justify-between">
                    <span className="flex items-center gap-2">
                      <span className="inline-block h-6 w-6 rounded-full bg-success" />
                      <span>
                        <b className="text-[13px]">Sleep</b>
                        <br />
                        <small className="text-ink-500">+38 min avg</small>
                      </span>
                    </span>
                    <span className="text-success">↑</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="flex items-center gap-2">
                      <span className="inline-block h-6 w-6 rounded-full bg-rust-500" />
                      <span>
                        <b className="text-[13px]">Dose adherence</b>
                        <br />
                        <small className="text-ink-500">100% this week</small>
                      </span>
                    </span>
                    <span className="text-success">✓</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="flex items-center gap-2">
                      <span className="inline-block h-6 w-6 rounded-full bg-info" />
                      <span>
                        <b className="text-[13px]">HRV</b>
                        <br />
                        <small className="text-ink-500">54 avg · stable</small>
                      </span>
                    </span>
                    <span className="text-ink-500">→</span>
                  </div>
                </div>
              </div>

              <div className="mt-auto rounded-xl bg-cream-200 px-3 py-2.5 text-[12px] text-ink-900">
                ✨ Ask peppy anything
              </div>

              <div className="flex justify-between border-t border-border-subtle pt-2 text-[11px] text-ink-500">
                <span>Home</span>
                <span>Check-in</span>
                <span>Protocol</span>
                <span>Insights</span>
                <span>+</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

/* --------------------------- TESTIMONIALS GRID ----------------------- */
export function Testimonials() {
  // see id below

  const tiles = [
    "tg--tall",
    "tg--short",
    "",
    "tg--tall",
    "",
    "tg--short",
    "tg--tall",
    "",
    "tg--tall",
    "tg--short",
    "",
    "tg--tall",
    "",
    "tg--short",
  ];
  return (
    <section id="testimonials" className="relative overflow-hidden py-20">
      <div
        className="mx-auto grid max-w-[1100px] grid-cols-7 gap-3.5"
        aria-hidden="true"
      >
        {tiles.map((mod, i) => {
          const variants = [
            "peppy-tile-a",
            "peppy-tile-b",
            "peppy-tile-c",
            "peppy-tile-d",
            "peppy-tile-e",
          ];
          const aspect =
            mod === "tg--tall"
              ? "aspect-[3/5]"
              : mod === "tg--short"
              ? "aspect-square self-end"
              : "aspect-[3/4]";
          return (
            <div
              key={i}
              className={`peppy-tile ${variants[i % variants.length]} ${aspect}`}
            />
          );
        })}
      </div>
      <Reveal className="relative z-10 mx-auto mt-12 max-w-[620px] text-center">
        <h2 className="text-[clamp(32px,4.4vw,56px)] font-semibold leading-[1.05] tracking-[-0.02em] text-ink-900">
          Built with care.
          <br />
          <em className="font-serif text-rust-500">Loved everywhere.</em>
        </h2>
        <p className="mt-3 text-ink-700">
          Don&apos;t take our word for it. Early users say peppy is the
          first app that made their protocol legible.
        </p>
      </Reveal>
    </section>
  );
}

/* -------------------------------- CTA -------------------------------- */
export function CTA() {
  return (
    <section id="download" className="px-6 py-20">
      <Reveal>
        <div className="mx-auto flex max-w-[1080px] flex-col items-center gap-6 rounded-3xl bg-rust-500 px-8 py-16 text-center">
          <h2 className="text-[clamp(32px,4.4vw,52px)] font-semibold leading-[1.05] tracking-[-0.02em] text-cream-50">
            Make this week
            <br />
            <em className="font-serif">make sense.</em>
          </h2>
          <p className="max-w-[480px] text-cream-50/90">
            peppy is free during early access. Bring your protocol, we&apos;ll
            help you read it.
          </p>
          <Link
            href="/waitlist"
            className="inline-flex items-center gap-2 rounded-full bg-ink-900 px-6 py-4 text-[16px] font-semibold text-cream-50 transition-all hover:-translate-y-px hover:shadow-[0_4px_20px_rgba(224,122,95,0.3)]"
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M17.6 13.1c-.04-3.1 2.53-4.6 2.65-4.67-1.45-2.12-3.7-2.4-4.5-2.44-1.92-.2-3.74 1.13-4.71 1.13-.98 0-2.48-1.1-4.07-1.07-2.1.03-4.04 1.22-5.12 3.1-2.18 3.78-.56 9.37 1.57 12.44 1.04 1.5 2.28 3.18 3.9 3.12 1.56-.06 2.15-1.01 4.03-1.01 1.87 0 2.4 1.01 4.06.98 1.67-.03 2.74-1.52 3.77-3.04 1.18-1.74 1.67-3.43 1.7-3.52-.04-.02-3.26-1.25-3.3-4.92ZM14.7 4.06c.86-1.04 1.44-2.49 1.28-3.93-1.24.05-2.74.82-3.62 1.86-.79.93-1.48 2.4-1.3 3.82 1.38.1 2.78-.7 3.64-1.75Z" />
            </svg>
            Download for iOS
          </Link>
        </div>
      </Reveal>
    </section>
  );
}

/* ------------------------------- FOOTER ------------------------------ */
export function Footer() {
  return (
    <footer className="border-t border-border-subtle pb-14 pt-20">
      <div className="mx-auto grid max-w-[1280px] gap-8 px-6 md:grid-cols-[1.4fr_repeat(4,1fr)]">
        <div>
          <div className="flex items-center gap-2 text-[22px]">
            <Logo />
            <Wordmark className="text-[22px]" />
          </div>
          <small className="mt-2 block text-[12px] text-ink-500">
            © peppy, inc. 2026
          </small>

          <div className="mt-5 flex gap-3">
            {["Instagram", "X", "Reddit", "YouTube"].map((label, i) => (
              <a
                key={label}
                href="#"
                aria-label={label}
                className="grid h-9 w-9 place-items-center rounded-full border border-border-subtle text-ink-700 transition-all hover:border-ink-900 hover:text-rust-500 hover:scale-110"
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                  {i === 0 && (
                    <g fill="none" stroke="currentColor" strokeWidth="1.8">
                      <rect x="3" y="3" width="18" height="18" rx="5" />
                      <circle cx="12" cy="12" r="4" />
                      <circle cx="17.5" cy="6.5" r="0.8" fill="currentColor" />
                    </g>
                  )}
                  {i === 1 && (
                    <path d="M17.5 3h3.4l-7.4 8.5L22 21h-6.8l-5.3-6.9L3.8 21H.4l7.9-9.1L0 3h6.9l4.8 6.4L17.5 3Z" />
                  )}
                  {i === 2 && (
                    <g>
                      <circle cx="12" cy="13" r="9" fill="none" stroke="currentColor" strokeWidth="1.6" />
                      <circle cx="9" cy="13" r="1.2" />
                      <circle cx="15" cy="13" r="1.2" />
                      <path d="M8.5 16c1 .9 2.2 1.2 3.5 1.2s2.5-.3 3.5-1.2" stroke="currentColor" strokeWidth="1.4" fill="none" strokeLinecap="round" />
                    </g>
                  )}
                  {i === 3 && (
                    <g>
                      <rect x="2" y="6" width="20" height="12" rx="3" />
                      <path d="M10 9.5v5l4.5-2.5L10 9.5Z" fill="#fff" />
                    </g>
                  )}
                </svg>
              </a>
            ))}
          </div>
        </div>

        {[
          {
            h: "Company",
            links: [
              { label: "About", href: "/about" },
            ],
          },
          {
            h: "Product",
            links: [
              { label: "Download", href: "/waitlist" },
              { label: "What's tracked", href: "/#features" },
            ],
          },
          {
            h: "Support",
            links: [
              { label: "FAQ", href: "/waitlist#faq" },
              { label: "Request a feature", href: "/feedback/feature" },
              { label: "Report a bug", href: "/feedback/bug" },
              { label: "Contact", href: "/contact" },
            ],
          },
          {
            h: "Legal",
            links: [
              { label: "Privacy", href: "/privacy" },
              { label: "Terms", href: "/terms" },
              { label: "Security", href: "#" },
            ],
          },
        ].map((col) => (
          <div key={col.h}>
            <h4 className="mb-3.5 text-[13px] font-medium text-ink-500">
              {col.h}
            </h4>
            <ul className="flex flex-col gap-2.5">
              {col.links.map((l) => (
                <li key={l.label}>
                  <Link
                    href={l.href}
                    className="text-[15px] text-ink-900 transition-colors hover:text-rust-500"
                  >
                    {l.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </footer>
  );
}
