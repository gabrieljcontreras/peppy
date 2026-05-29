"use client";

import { useEffect, useState } from "react";
import { motion, useReducedMotion } from "motion/react";
import { Button } from "@/components/ui/Button";
import { Smile, Zap, Moon, Bell, Sparkles } from "lucide-react";

const insights = [
  "Sleep quality up 14% — recovery on track.",
  "Weight loss accelerating. Great trajectory.",
  "Side effects subsiding. Dose tolerated well.",
  "HRV trending up week-over-week.",
];

export function Hero() {
  const prefersReduced = useReducedMotion();
  const [insightIdx, setInsightIdx] = useState(0);

  useEffect(() => {
    if (prefersReduced) return;
    const i = setInterval(() => setInsightIdx((v) => (v + 1) % insights.length), 3800);
    return () => clearInterval(i);
  }, [prefersReduced]);

  return (
    <section className="relative overflow-hidden pt-32 md:pt-40 pb-24 md:pb-32">
      {/* Ambient background */}
      <div className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute -top-32 left-1/4 w-[700px] h-[600px] rounded-full bg-[radial-gradient(closest-side,rgba(199,107,62,0.14),transparent_70%)]" />
        <div className="absolute top-1/3 -right-32 w-[500px] h-[500px] rounded-full bg-[radial-gradient(closest-side,rgba(199,107,62,0.10),transparent_70%)]" />
      </div>

      <div className="mx-auto max-w-6xl px-6">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-16 items-center">
          {/* LEFT — text + CTAs + stats */}
          <div className="text-center lg:text-left">
            <motion.div
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, ease: [0.2, 0.8, 0.2, 1] }}
              className="inline-flex items-center gap-2 rounded-full border border-[var(--color-ink-100)] bg-[var(--color-cream-50)] px-3 py-1.5 text-[12px] font-semibold uppercase tracking-[0.08em] text-[var(--color-ink-500)]"
            >
              <span className="h-1.5 w-1.5 rounded-full bg-[var(--color-rust-500)]" />
              Now in private beta
            </motion.div>

            <motion.h1
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.65, delay: 0.1, ease: [0.2, 0.8, 0.2, 1] }}
              className="mt-6 font-semibold leading-[1.04] tracking-[-0.025em] text-[var(--color-ink-900)] text-[40px] sm:text-[52px] lg:text-[64px]"
            >
              Track your protocol.
              <br />
              Understand your <em className="peppy-accent">body</em>.
            </motion.h1>

            <motion.p
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.25, ease: [0.2, 0.8, 0.2, 1] }}
              className="mt-6 text-lg lg:text-xl text-[var(--color-ink-500)] leading-relaxed max-w-xl mx-auto lg:mx-0"
            >
              Log protocols, track your response, and get insights that help you
              optimize — all in one calm, beautiful app.
            </motion.p>

            <motion.div
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.4, ease: [0.2, 0.8, 0.2, 1] }}
              className="mt-9 flex flex-col sm:flex-row gap-3 justify-center lg:justify-start"
            >
              <Button href="/waitlist" size="lg">
                Join the waitlist
              </Button>
              <Button href="/features" variant="secondary" size="lg">
                See features
              </Button>
            </motion.div>

            {/* Trust / social proof stats */}
            <motion.div
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.6, ease: [0.2, 0.8, 0.2, 1] }}
              className="mt-12 grid grid-cols-3 gap-4 sm:gap-8 max-w-md mx-auto lg:mx-0 pt-8 border-t border-[var(--color-ink-100)]"
            >
              {[
                { v: "500+", l: "On waitlist" },
                { v: "60+", l: "Peptides supported" },
                { v: "AES‑256", l: "Encrypted" },
              ].map((s) => (
                <div key={s.l} className="text-center lg:text-left">
                  <p className="text-xl sm:text-2xl font-semibold text-[var(--color-ink-900)] tabular tracking-[-0.02em]">
                    {s.v}
                  </p>
                  <p className="mt-1 text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-ink-400)] leading-tight">
                    {s.l}
                  </p>
                </div>
              ))}
            </motion.div>
          </div>

          {/* RIGHT — phone mockup */}
          <motion.div
            initial={{ opacity: 0, y: 32 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.35, ease: [0.2, 0.8, 0.2, 1] }}
            className="relative flex justify-center lg:justify-end"
          >
            <div className="peppy-glow" />
            <PhoneMock insight={insights[insightIdx]} />
          </motion.div>
        </div>
      </div>
    </section>
  );
}

function PhoneMock({ insight }: { insight: string }) {
  return (
    <div className="relative w-[300px] sm:w-[320px] rounded-[36px] bg-[var(--color-ink-900)] p-2.5 ring-1 ring-[var(--color-ink-600)]">
      {/* Notch */}
      <div className="absolute left-1/2 top-3 z-10 h-6 w-28 -translate-x-1/2 rounded-full bg-[var(--color-ink-900)]" />

      <div className="relative overflow-hidden rounded-[30px] bg-[var(--color-cream-100)]">
        {/* Status bar */}
        <div className="flex h-9 items-end justify-between px-6 pb-1 text-[11px] font-semibold text-[var(--color-ink-900)] tabular">
          <span>9:41</span>
          <span className="flex items-center gap-1 opacity-70">
            <svg width="14" height="10" viewBox="0 0 14 10" fill="none" aria-hidden>
              <rect x="0" y="6" width="2" height="3" rx="0.5" fill="currentColor" />
              <rect x="3" y="4" width="2" height="5" rx="0.5" fill="currentColor" />
              <rect x="6" y="2" width="2" height="7" rx="0.5" fill="currentColor" />
              <rect x="9" y="0" width="2" height="9" rx="0.5" fill="currentColor" />
            </svg>
          </span>
        </div>

        {/* Greeting */}
        <div className="px-5 pt-3 pb-3">
          <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-ink-400)]">
            Good morning, Alex
          </p>
          <h3 className="mt-1 text-2xl font-semibold tracking-[-0.01em] text-[var(--color-ink-900)]">
            Today
          </h3>
        </div>

        {/* Cards */}
        <div className="px-4 pb-5 space-y-2.5">
          {/* Recovery score */}
          <div className="rounded-2xl bg-[var(--color-rust-500)] px-5 py-4 text-[var(--color-cream-100)]">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-[0.08em] opacity-80">
                  Recovery
                </p>
                <p className="mt-1 text-3xl font-semibold tabular leading-none">
                  84<span className="text-lg opacity-70">%</span>
                </p>
                <p className="mt-1 text-[11px] opacity-80">Strong — train hard</p>
              </div>
              <RecoveryRing pct={84} />
            </div>
          </div>

          {/* Quick check-in */}
          <div className="rounded-2xl bg-[var(--color-cream-50)] p-4">
            <div className="flex items-center justify-between mb-3">
              <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-ink-400)]">
                Quick check-in
              </p>
              <span className="text-[10px] font-semibold text-[var(--color-ink-400)] tabular">
                30 sec
              </span>
            </div>
            <div className="grid grid-cols-3 gap-2">
              <QuickButton icon={Smile} label="Mood" />
              <QuickButton icon={Zap} label="Energy" />
              <QuickButton icon={Moon} label="Sleep" />
            </div>
          </div>

          {/* AI insight — left border accent */}
          <div className="relative rounded-2xl bg-[var(--color-cream-50)] py-3 pl-4 pr-4 overflow-hidden">
            <div className="absolute left-0 top-3 bottom-3 w-[3px] rounded-r-full bg-[var(--color-rust-500)]" />
            <div className="flex items-center gap-1.5 mb-1">
              <Sparkles className="h-3 w-3 text-[var(--color-rust-500)]" strokeWidth={2} />
              <span className="text-[10px] font-semibold uppercase tracking-[0.08em] text-[var(--color-rust-500)]">
                AI insight
              </span>
            </div>
            <div className="relative h-9">
              <motion.p
                key={insight}
                initial={{ opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.35, ease: [0.2, 0.8, 0.2, 1] }}
                className="absolute inset-0 text-[13px] leading-snug text-[var(--color-ink-900)]"
              >
                {insight}
              </motion.p>
            </div>
          </div>

          {/* Next dose reminder */}
          <div className="rounded-2xl bg-[var(--color-cream-50)] p-3 flex items-center gap-3">
            <div className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-xl bg-[var(--color-rust-500)]/10">
              <Bell className="h-4 w-4 text-[var(--color-rust-500)]" strokeWidth={2} />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-[13px] font-semibold text-[var(--color-ink-900)] truncate">
                Retatrutide 4 mg
              </p>
              <p className="text-[11px] text-[var(--color-ink-400)] mt-0.5">
                Due tonight · 9:00 PM
              </p>
            </div>
            <span className="text-[10px] font-semibold uppercase tracking-[0.08em] text-[var(--color-rust-500)] bg-[var(--color-rust-500)]/10 rounded-full px-2 py-1 whitespace-nowrap">
              Tonight
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

function QuickButton({
  icon: Icon,
  label,
}: {
  icon: React.ComponentType<{ className?: string; strokeWidth?: number }>;
  label: string;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-1.5 rounded-xl bg-[var(--color-cream-100)] py-3 ring-1 ring-[var(--color-ink-100)]">
      <Icon className="h-4 w-4 text-[var(--color-ink-500)]" strokeWidth={1.8} />
      <span className="text-[10px] font-semibold text-[var(--color-ink-500)]">
        {label}
      </span>
    </div>
  );
}

function RecoveryRing({ pct }: { pct: number }) {
  const r = 22;
  const c = 2 * Math.PI * r;
  return (
    <svg width="56" height="56" viewBox="0 0 56 56" aria-hidden>
      <circle
        cx="28"
        cy="28"
        r={r}
        fill="none"
        stroke="rgba(255,255,255,0.22)"
        strokeWidth="4"
      />
      <motion.circle
        cx="28"
        cy="28"
        r={r}
        fill="none"
        stroke="white"
        strokeWidth="4"
        strokeLinecap="round"
        strokeDasharray={c}
        initial={{ strokeDashoffset: c }}
        animate={{ strokeDashoffset: c * (1 - pct / 100) }}
        transition={{ duration: 1.4, delay: 0.9, ease: [0.2, 0.8, 0.2, 1] }}
        transform="rotate(-90 28 28)"
      />
    </svg>
  );
}
