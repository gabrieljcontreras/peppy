"use client";

import { motion } from "motion/react";
import {
  Pill,
  ClipboardCheck,
  Sparkles,
  Watch,
  TestTube,
  ShieldCheck,
} from "lucide-react";
import { Nav } from "@/components/layout/Nav";
import { Footer } from "@/components/layout/Footer";
import { Button } from "@/components/ui/Button";

const features = [
  {
    icon: Pill,
    title: "Protocol tracking",
    description:
      "Log compounds, doses, frequencies, and schedules. Support for 60+ peptides with smart defaults. Track multiple protocols simultaneously.",
  },
  {
    icon: Sparkles,
    title: "Smart insights",
    description:
      "AI analyzes your data to spot trends, flag anomalies, and suggest optimizations. Correlation analysis between protocol changes and outcomes.",
  },
  {
    icon: ClipboardCheck,
    title: "Daily check-ins",
    description:
      "Quick 30-second check-ins capture weight, symptoms, mood, and energy. The more you log, the better the insights become.",
  },
  {
    icon: Watch,
    title: "Wearable sync",
    description:
      "Connect Oura, Whoop, and Apple Health. Automatic import of sleep, HRV, activity, and recovery data.",
  },
  {
    icon: TestTube,
    title: "Lab integration",
    description:
      "Log blood work results. Track metabolic markers over time. See how your protocol affects key biomarkers.",
  },
  {
    icon: ShieldCheck,
    title: "Privacy first",
    description:
      "Your data is encrypted and never sold. Export or delete everything anytime. You own your data.",
  },
];

export default function FeaturesPage() {
  return (
    <>
      <Nav />
      <main className="relative overflow-hidden pt-32 md:pt-40 pb-24 md:pb-32">
        <div className="pointer-events-none absolute inset-0 -z-10">
          <div className="absolute -top-32 left-1/2 -translate-x-1/2 w-[800px] h-[500px] rounded-full bg-[radial-gradient(closest-side,rgba(199,107,62,0.12),transparent_70%)]" />
        </div>

        <div className="mx-auto max-w-6xl px-6 md:px-8">
          {/* Header */}
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease: [0.2, 0.8, 0.2, 1] }}
            className="text-center mb-16 md:mb-20 max-w-2xl mx-auto"
          >
            <p className="mb-4 text-[12px] font-semibold uppercase tracking-[0.08em] text-[var(--color-rust-500)]">
              Features
            </p>
            <h1 className="text-4xl md:text-6xl font-semibold text-[var(--color-ink-900)] tracking-[-0.025em] leading-[1.05]">
              Everything you need to <em className="peppy-accent">track</em>.
            </h1>
            <p className="mt-5 text-lg text-[var(--color-ink-500)] leading-relaxed">
              The full toolkit for understanding your protocol&apos;s effect on
              your body.
            </p>
          </motion.div>

          {/* Feature cards — same grid as homepage for consistency */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-5">
            {features.map((feature, i) => {
              const aboveFold = i < 3;
              const motionProps = aboveFold
                ? {
                    initial: { opacity: 0, y: 16 } as const,
                    animate: { opacity: 1, y: 0 } as const,
                    transition: {
                      duration: 0.6,
                      delay: 0.15 + i * 0.08,
                      ease: [0.2, 0.8, 0.2, 1] as const,
                    },
                  }
                : {
                    initial: { opacity: 0, y: 20 } as const,
                    whileInView: { opacity: 1, y: 0 } as const,
                    viewport: { once: true, margin: "-40px" } as const,
                    transition: {
                      duration: 0.6,
                      delay: 0.05,
                      ease: [0.2, 0.8, 0.2, 1] as const,
                    },
                  };
              return (
                <motion.div
                  key={feature.title}
                  {...motionProps}
                  className="group rounded-2xl bg-[var(--color-cream-50)] p-7 md:p-8 transition-colors duration-300 hover:bg-[var(--color-cream-200)]/50"
                >
                  <div className="mb-5 inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-[var(--color-rust-500)]/8 text-[var(--color-rust-500)] transition-colors duration-300 group-hover:bg-[var(--color-rust-500)]/15">
                    <feature.icon className="h-5 w-5" strokeWidth={1.6} />
                  </div>
                  <h2 className="text-xl md:text-2xl font-semibold text-[var(--color-ink-900)] tracking-[-0.01em] mb-3">
                    {feature.title}
                  </h2>
                  <p className="text-[var(--color-ink-500)] leading-relaxed text-[16px]">
                    {feature.description}
                  </p>
                </motion.div>
              );
            })}
          </div>

          {/* CTA */}
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-40px" }}
            transition={{ duration: 0.6, ease: [0.2, 0.8, 0.2, 1] }}
            className="mt-20 text-center"
          >
            <p className="text-[var(--color-ink-500)] mb-6">
              Ready to start tracking?
            </p>
            <Button href="/waitlist" size="lg">
              Join the waitlist
            </Button>
          </motion.div>
        </div>
      </main>
      <Footer />
    </>
  );
}