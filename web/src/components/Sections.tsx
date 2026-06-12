import Link from "next/link";
import { PhoneFrame } from "./PhoneMock";
import { Logo, Wordmark } from "./Logo";
import { Reveal } from "./Reveal";

/* ------------------------------- HERO ------------------------------- */

type FloatCardProps = {
  tint: string;
  icon: React.ReactNode;
  title: string;
  sub: string;
  className: string;
  rot: number;
  delay: number;
};

function FloatCard({ tint, icon, title, sub, className, rot, delay }: FloatCardProps) {
  return (
    <div
      className={`peppy-float absolute z-20 hidden items-center gap-3 rounded-2xl border border-border-subtle bg-cream-50 py-3 pl-3.5 pr-5 shadow-[0_18px_40px_-12px_rgba(33,33,38,0.16)] lg:flex ${className}`}
      style={
        {
          "--float-rot": `${rot}deg`,
          animationDelay: `${delay}ms`,
          transform: `rotate(${rot}deg)`,
        } as React.CSSProperties
      }
    >
      <span
        className="grid h-9 w-9 flex-none place-items-center rounded-xl text-ink-900"
        style={{ background: tint }}
      >
        {icon}
      </span>
      <span>
        <b className="block text-[13px] leading-tight text-ink-900">{title}</b>
        <small className="text-[12px] text-ink-500">{sub}</small>
      </span>
    </div>
  );
}

export function Hero() {
  return (
    <header className="relative overflow-hidden px-6 pt-16 text-center">
      <div className="peppy-aura" aria-hidden="true" />

      <div className="relative z-10 mx-auto max-w-[860px]">
        <p className="peppy-fade peppy-fade-2 inline-flex items-center gap-2 rounded-full border border-border-subtle bg-cream-50/70 px-3.5 py-1.5 text-[13px] font-medium text-ink-700 backdrop-blur">
          <span className="inline-block h-1.5 w-1.5 rounded-full bg-rust-500" />
          Now in early access
        </p>

        <h1
          className="peppy-fade peppy-fade-2 mx-auto mt-5 text-[clamp(44px,6.4vw,80px)] font-semibold leading-[1.02] tracking-[-0.025em] text-ink-900"
          style={{ textWrap: "balance" }}
        >
          Your protocol,
          <br />
          <em className="font-serif italic font-medium text-rust-500">
            understood.
          </em>
        </h1>

        <p className="peppy-fade peppy-fade-3 mx-auto mt-6 max-w-[600px] text-[19px] leading-[1.55] text-ink-700">
          Track your peptide protocol, daily check-ins, weight, symptoms,
          labs, and wearable data — in one private place.
        </p>

        <div className="peppy-fade peppy-fade-3 mt-8 flex flex-wrap items-center justify-center gap-3">
          <Link
            href="/waitlist"
            className="inline-flex items-center gap-2 rounded-full bg-ink-900 px-6 py-3.5 text-[15px] font-semibold text-cream-50 transition-all duration-300 hover:bg-ink-700 hover:-translate-y-px hover:shadow-[0_12px_28px_-10px_rgba(33,33,38,0.5)] active:translate-y-0"
          >
            Join the waitlist
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden="true">
              <path d="M5 12h14M13 6l6 6-6 6" />
            </svg>
          </Link>
          <a
            href="#features"
            className="inline-flex items-center gap-2 rounded-full border border-border-default bg-cream-50/60 px-6 py-3.5 text-[15px] font-semibold text-ink-900 transition-colors duration-300 hover:border-ink-900"
          >
            See how it works
          </a>
        </div>

        <div className="peppy-fade peppy-fade-4 mt-6 inline-flex items-center gap-2 text-[13px] text-ink-500">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
            <rect x="4" y="10" width="16" height="11" rx="2.5" />
            <path d="M8 10V7a4 4 0 0 1 8 0v3" />
          </svg>
          Your health data stays private and encrypted.
        </div>
      </div>

      {/* device showcase */}
      <div className="peppy-fade peppy-fade-4 relative z-10 mx-auto mt-16 max-w-[980px]">
        <div className="relative mx-auto h-[440px] overflow-hidden sm:h-[540px]">
          <div className="absolute left-1/2 top-0 -translate-x-1/2">
            <PhoneFrame
              src="/app/home.webp"
              alt="peppy home screen — greeting, next dose, weight trend, and connected wearable metrics"
              width={320}
              priority
            />
          </div>

          <FloatCard
            tint="var(--peppy-tint-rose)"
            icon={
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M3 17l5-6 4 3 5-7 4 5" />
              </svg>
            }
            title="Weight trend"
            sub="184.5 lb · ↓ 2.3 this week"
            className="left-[3%] top-[14%] xl:left-[9%]"
            rot={-4}
            delay={0}
          />
          <FloatCard
            tint="var(--peppy-tint-sage)"
            icon={
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                <path d="M5 13l4 4L19 7" />
              </svg>
            }
            title="Daily check-in"
            sub="Completed · 21-day streak"
            className="bottom-[26%] left-[6%] xl:left-[12%]"
            rot={3}
            delay={1200}
          />
          <FloatCard
            tint="var(--peppy-tint-butter)"
            icon={
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <rect x="7" y="3" width="10" height="18" rx="3" />
                <path d="M10 7h4" />
              </svg>
            }
            title="Next dose"
            sub="Sun, Jun 1 · 4 mg"
            className="right-[3%] top-[17%] xl:right-[9%]"
            rot={4}
            delay={600}
          />
          <FloatCard
            tint="var(--peppy-tint-lavender)"
            icon={
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M20 13.5A8.5 8.5 0 1 1 10.5 4a7 7 0 0 0 9.5 9.5Z" />
              </svg>
            }
            title="Sleep"
            sub="7h 18m · from Oura"
            className="bottom-[22%] right-[6%] xl:right-[12%]"
            rot={-3}
            delay={1800}
          />

          {/* ground fade */}
          <div
            aria-hidden="true"
            className="pointer-events-none absolute inset-x-0 bottom-0 z-30 h-36"
            style={{
              background:
                "linear-gradient(180deg, transparent, var(--background) 85%)",
            }}
          />
        </div>
      </div>
    </header>
  );
}

/* ---------------------------- WORKS WITH ----------------------------- */

const integrations: { name: string; icon: React.ReactNode }[] = [
  {
    name: "Apple Health",
    icon: (
      <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
        <path d="M12 21s-7.5-4.6-9.7-9.2C.7 8.4 2.7 4.9 6.1 4.9c2 0 3.6 1.1 4.4 2.7h3c.8-1.6 2.4-2.7 4.4-2.7 3.4 0 5.4 3.5 3.8 6.9C19.5 16.4 12 21 12 21Z" opacity=".9" />
      </svg>
    ),
  },
  {
    name: "Oura",
    icon: (
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" aria-hidden="true">
        <circle cx="12" cy="12" r="8" />
      </svg>
    ),
  },
  {
    name: "Whoop",
    icon: (
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden="true">
        <path d="M3 12h4l2.5-6 4 12 2.5-6h5" />
      </svg>
    ),
  },
  {
    name: "Garmin",
    icon: (
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden="true">
        <path d="M12 4 21 19H3L12 4Z" strokeLinejoin="round" />
      </svg>
    ),
  },
];

export function WorksWith() {
  const row = [...integrations, ...integrations];
  return (
    <section className="py-14">
      <Reveal>
        <p className="mb-7 text-center text-[12px] font-semibold uppercase tracking-[0.16em] text-ink-500">
          Works with
        </p>
        <div className="peppy-marquee mx-auto max-w-[880px]">
          <div className="peppy-marquee-track">
            {[...row, ...row].map(({ name, icon }, i) => (
              <span
                key={`${name}-${i}`}
                className="inline-flex flex-none items-center gap-2.5 rounded-full border border-border-subtle bg-cream-50 px-5 py-2.5 text-[14px] font-medium text-ink-700"
              >
                <span className="text-rust-500">{icon}</span>
                {name}
              </span>
            ))}
          </div>
        </div>
      </Reveal>
    </section>
  );
}

/* ----------------------------- FEATURES ----------------------------- */

type FeatureCardProps = {
  tint: string;
  title: string;
  copy: string;
  src: string;
  alt: string;
};

function FeatureCard({ tint, title, copy, src, alt }: FeatureCardProps) {
  return (
    <article
      className="group flex flex-col overflow-hidden rounded-[28px] px-7 pt-7 transition-all duration-500 hover:-translate-y-1.5 hover:shadow-[0_28px_56px_-20px_rgba(33,33,38,0.22)]"
      style={{ background: tint }}
    >
      <h3 className="text-[25px] font-semibold leading-tight tracking-[-0.015em] text-ink-900">
        {title}
      </h3>
      <p className="mt-2 max-w-[300px] text-[14.5px] leading-snug text-ink-700">
        {copy}
      </p>
      <div className="relative mt-7 h-[330px] overflow-hidden">
        <div className="absolute left-1/2 top-0 -translate-x-1/2 transition-transform duration-500 group-hover:-translate-y-2">
          <PhoneFrame src={src} alt={alt} width={244} />
        </div>
      </div>
    </article>
  );
}

export function Features() {
  return (
    <section id="features" className="py-24">
      <div className="mx-auto max-w-[1280px] px-6">
        <Reveal>
          <div className="mx-auto mb-14 max-w-[680px] text-center">
            <h2 className="text-[clamp(32px,4.4vw,56px)] font-semibold leading-[1.05] tracking-[-0.02em] text-ink-900">
              Start the day
              <br />
              with <em className="font-serif italic font-medium text-rust-500">clarity.</em>
            </h2>
            <p className="mt-4 text-[17px] text-ink-700">
              Turn what you&apos;re doing — and how you feel — into clear,
              actionable signal.
            </p>
          </div>
        </Reveal>

        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
          {(
            [
              {
                tint: "var(--peppy-tint-rose)",
                title: "Protocols",
                copy: "Every compound, dose, and titration week in one personalized plan.",
                src: "/app/protocols.webp",
                alt: "peppy protocols screen — active Retatrutide titration with weekly progress",
              },
              {
                tint: "var(--peppy-tint-sage)",
                title: "Check-ins",
                copy: "30 seconds a day. Weight, energy, sleep, appetite, and mood.",
                src: "/app/check_in.png",
                alt: "peppy check-in detail screen — daily ratings for weight, energy, sleep, appetite, and mood",
              },
              {
                tint: "var(--peppy-tint-butter)",
                title: "Insights",
                copy: "Trends and patterns over time — see what's actually moving the needle.",
                src: "/app/insights_page.png",
                alt: "peppy insights screen — visualizations of health trends and patterns",
              },
            ] as const
          ).map((card, i) => (
            <Reveal key={card.title} delay={i * 120}>
              <FeatureCard {...card} />
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* --------------------------- FEATURE ROWS ---------------------------- */

type FeatureRowProps = {
  eyebrow: string;
  title: React.ReactNode;
  copy: string;
  bullets: string[];
  src: string;
  alt: string;
  tint: string;
  reverse?: boolean;
};

function FeatureRow({ eyebrow, title, copy, bullets, src, alt, tint, reverse }: FeatureRowProps) {
  return (
    <div className="grid items-center gap-10 md:grid-cols-2 md:gap-16">
      <Reveal
        direction={reverse ? "left" : "right"}
        className={reverse ? "md:order-2" : ""}
      >
        <div
          className="relative flex justify-center overflow-hidden rounded-[32px] pt-12"
          style={{ background: tint }}
        >
          <PhoneFrame src={src} alt={alt} width={272} className="-mb-20" />
        </div>
      </Reveal>

      <Reveal direction={reverse ? "right" : "left"} delay={120}>
        <div className={reverse ? "md:order-1" : ""}>
          <p className="text-[12px] font-semibold uppercase tracking-[0.16em] text-rust-500">
            {eyebrow}
          </p>
          <h3 className="mt-3 text-[clamp(28px,3.4vw,42px)] font-semibold leading-[1.08] tracking-[-0.02em] text-ink-900">
            {title}
          </h3>
          <p className="mt-4 max-w-[440px] text-[16.5px] text-ink-700">{copy}</p>
          <ul className="mt-6 flex flex-col gap-3">
            {bullets.map((b) => (
              <li key={b} className="flex items-start gap-3 text-[15px] text-ink-700">
                <span className="mt-0.5 grid h-5 w-5 flex-none place-items-center rounded-full bg-tint-sage text-success">
                  <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3">
                    <path d="M5 13l4 4L19 7" />
                  </svg>
                </span>
                {b}
              </li>
            ))}
          </ul>
        </div>
      </Reveal>
    </div>
  );
}

export function FeatureRows() {
  return (
    <section id="more" className="py-12">
      <div className="mx-auto flex max-w-[1180px] flex-col gap-28 px-6">
        <FeatureRow
          eyebrow="Connected data"
          title={
            <>
              Connect your{" "}
              <em className="font-serif italic font-medium">health data.</em>
            </>
          }
          copy="Sync your favorite apps and devices to get a more complete picture of your progress — recovery and results, side by side."
          bullets={[
            "Apple Health, Oura, and Whoop sync automatically",
            "Sleep, HRV, and readiness alongside your protocol",
            "Spot how dose changes show up in your recovery",
          ]}
          src="/app/connect.webp"
          alt="peppy connect screen — link Apple Health, Oura, and Whoop"
          tint="var(--peppy-tint-sky)"
        />

        <FeatureRow
          eyebrow="Reminders"
          title={
            <>
              Stay consistent{" "}
              <em className="font-serif italic font-medium">without</em> the
              noise.
            </>
          }
          copy="Helpful reminders and important updates — only when they matter. Everything respects your quiet hours."
          bullets={[
            "Dose reminders, on time, every time",
            "Daily check-in nudges that take less than a minute",
            "Insight alerts when your trends actually change",
          ]}
          src="/app/notifications.webp"
          alt="peppy notifications screen — dose reminders, check-in nudges, and quiet hours"
          tint="var(--peppy-tint-butter)"
          reverse
        />

        <FeatureRow
          eyebrow="Symptoms"
          title={
            <>
              Catch side-effects{" "}
              <em className="font-serif italic font-medium text-rust-500">
                early.
              </em>
            </>
          }
          copy="Log symptoms with severity in seconds, so small signals don't become big surprises — and your provider gets the full story."
          bullets={[
            "Rate severity from none to severe in one tap",
            "Injection-site and GI tracking built in",
            "Clean, provider-ready history of every report",
          ]}
          src="/app/side-effects.webp"
          alt="peppy side-effects screen — symptom checklist with severity sliders"
          tint="var(--peppy-tint-rose)"
        />
      </div>
    </section>
  );
}

/* ---------------------- NOT ALL — INTERACTIVE TABS ------------------- */
export { NotAll } from "./NotAllSection";

/* ------------------------------ PRIVACY ------------------------------ */
export function Privacy() {
  return (
    <section id="privacy" className="px-6 py-12">
      <Reveal>
        <div className="mx-auto flex max-w-[1180px] flex-col items-center gap-6 rounded-[32px] bg-ink-900 px-8 py-20 text-center">
          <span className="grid h-12 w-12 place-items-center rounded-2xl bg-cream-50/10 text-cream-50">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="4" y="10" width="16" height="11" rx="2.5" />
              <path d="M8 10V7a4 4 0 0 1 8 0v3" />
            </svg>
          </span>
          <h2 className="text-[clamp(30px,4vw,48px)] font-semibold leading-[1.05] tracking-[-0.02em] text-cream-50">
            Private by{" "}
            <em className="font-serif italic font-medium text-rust-300">design.</em>
          </h2>
          <p className="max-w-[520px] text-[16.5px] text-cream-50/75">
            Your protocols, check-ins, and health data are encrypted and only
            visible to you. We&apos;ll never sell your data — and you can
            export or delete it at any time.
          </p>
          <div className="mt-2 flex flex-wrap items-center justify-center gap-3">
            {["Encrypted at rest", "Never sold", "Export anytime"].map((chip) => (
              <span
                key={chip}
                className="rounded-full border border-cream-50/20 px-4 py-2 text-[13px] font-medium text-cream-50/90"
              >
                {chip}
              </span>
            ))}
          </div>
        </div>
      </Reveal>
    </section>
  );
}

/* --------------------------- TESTIMONIALS GRID ----------------------- */
export function Testimonials() {
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
          <em className="font-serif italic font-medium text-rust-500">
            Loved everywhere.
          </em>
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
        <div className="mx-auto flex max-w-[1080px] flex-col items-center gap-6 rounded-[32px] bg-rust-500 px-8 py-16 text-center">
          <h2 className="text-[clamp(32px,4.4vw,52px)] font-semibold leading-[1.05] tracking-[-0.02em] text-cream-50">
            Make this week
            <br />
            <em className="font-serif italic font-medium">make sense.</em>
          </h2>
          <p className="max-w-[480px] text-cream-50/90">
            peppy is free during early access. Bring your protocol — we&apos;ll
            help you read it.
          </p>
          <Link
            href="/waitlist"
            className="inline-flex items-center gap-2 rounded-full bg-ink-900 px-7 py-4 text-[16px] font-semibold text-cream-50 transition-all duration-300 hover:-translate-y-px hover:shadow-[0_16px_36px_-12px_rgba(33,33,38,0.6)]"
          >
            Join the waitlist
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden="true">
              <path d="M5 12h14M13 6l6 6-6 6" />
            </svg>
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
            {[
              { label: "TikTok", href: "https://www.tiktok.com/@peppyapp" },
              { label: "Instagram", href: "https://www.instagram.com/peppy.ai/" },
              { label: "X", href: "https://x.com/getpeppyapp" },
              { label: "LinkedIn", href: "https://www.linkedin.com/company/peppyapp/" },
            ].map(({ label, href }, i) => (
              <a
                key={label}
                href={href}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={label}
                className="grid h-9 w-9 place-items-center rounded-full border border-border-subtle text-ink-700 transition-all hover:border-ink-900 hover:text-rust-500 hover:scale-110"
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                  {i === 0 && (
                    <path d="M16.6 5.8A4.3 4.3 0 0 1 13.2 4V1h-3v13.2a2.6 2.6 0 1 1-1.8-2.5V8.5a5.8 5.8 0 1 0 5 5.7V9.5a7.3 7.3 0 0 0 4.2 1.3V7.6a4.3 4.3 0 0 1-1-1.8Z" />
                  )}
                  {i === 1 && (
                    <g fill="none" stroke="currentColor" strokeWidth="1.8">
                      <rect x="3" y="3" width="18" height="18" rx="5" />
                      <circle cx="12" cy="12" r="4" />
                      <circle cx="17.5" cy="6.5" r="0.8" fill="currentColor" />
                    </g>
                  )}
                  {i === 2 && (
                    <path d="M17.5 3h3.4l-7.4 8.5L22 21h-6.8l-5.3-6.9L3.8 21H.4l7.9-9.1L0 3h6.9l4.8 6.4L17.5 3Z" />
                  )}
                  {i === 3 && (
                    <path d="M20.45 2H3.55A1.55 1.55 0 0 0 2 3.55v16.9A1.55 1.55 0 0 0 3.55 22h16.9A1.55 1.55 0 0 0 22 20.45V3.55A1.55 1.55 0 0 0 20.45 2ZM8.12 18.74H5.37V9.73h2.75v9.01ZM6.74 8.5a1.59 1.59 0 1 1 0-3.18 1.59 1.59 0 0 1 0 3.18Zm12 10.24h-2.75v-4.38c0-1.04-.02-2.38-1.45-2.38-1.45 0-1.67 1.13-1.67 2.3v4.46h-2.75V9.73h2.64v1.23h.04a2.89 2.89 0 0 1 2.6-1.43c2.79 0 3.3 1.83 3.3 4.22v4.99Z" />
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
              { label: "Security", href: "/#privacy" },
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
