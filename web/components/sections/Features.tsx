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

const features = [
  {
    icon: Pill,
    title: "Protocol tracking",
    description:
      "Log compounds, doses, and schedules. Track multiple protocols with 60+ peptides supported.",
  },
  {
    icon: ClipboardCheck,
    title: "Daily check-ins",
    description:
      "Quick 30-second check-ins for weight, symptoms, and mood. The more you log, the smarter it gets.",
  },
  {
    icon: Sparkles,
    title: "Smart insights",
    description:
      "AI analysis spots trends, flags anomalies, and suggests optimizations based on your data.",
  },
  {
    icon: Watch,
    title: "Wearable sync",
    description:
      "Connect Oura, Whoop, and Apple Health for automatic sleep and recovery data import.",
  },
  {
    icon: TestTube,
    title: "Lab integration",
    description:
      "Log blood work results and track how your protocol affects metabolic markers over time.",
  },
  {
    icon: ShieldCheck,
    title: "Private & secure",
    description:
      "Your health data is encrypted and never sold. Export or delete anytime.",
  },
];

export function Features() {
  return (
    <section id="features" className="relative py-24 md:py-32">
      <div className="mx-auto max-w-6xl px-6 md:px-8">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.6, ease: [0.2, 0.8, 0.2, 1] }}
          className="text-center mb-16 md:mb-20 max-w-2xl mx-auto"
        >
          <p className="mb-4 text-[12px] font-semibold uppercase tracking-[0.08em] text-[var(--color-rust-500)]">
            Features
          </p>
          <h2 className="text-3xl md:text-5xl font-semibold text-[var(--color-ink-900)] tracking-[-0.02em] leading-[1.1]">
            Everything you need to understand your body.
          </h2>
          <p className="mt-5 text-lg text-[var(--color-ink-500)]">
            Built for people who want to know what&apos;s actually working — and
            what&apos;s not.
          </p>
        </motion.div>

        {/* Card grid — consistent on all breakpoints */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-5">
          {features.map((feature, i) => (
            <FeatureCard key={feature.title} {...feature} index={i} />
          ))}
        </div>
      </div>
    </section>
  );
}

function FeatureCard({
  icon: Icon,
  title,
  description,
  index,
}: {
  icon: React.ComponentType<{ className?: string; strokeWidth?: number }>;
  title: string;
  description: string;
  index: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-60px" }}
      transition={{
        duration: 0.55,
        delay: (index % 3) * 0.08,
        ease: [0.2, 0.8, 0.2, 1],
      }}
      className="group rounded-2xl bg-[var(--color-cream-50)] p-7 md:p-8 transition-colors duration-300 hover:bg-[var(--color-cream-200)]/50"
    >
      <div className="mb-5 inline-flex h-11 w-11 items-center justify-center rounded-2xl bg-[var(--color-rust-500)]/8 text-[var(--color-rust-500)] transition-colors duration-300 group-hover:bg-[var(--color-rust-500)]/15">
        <Icon className="h-5 w-5" strokeWidth={1.6} />
      </div>
      <h3 className="text-lg md:text-xl font-semibold text-[var(--color-ink-900)] mb-2 tracking-[-0.01em]">
        {title}
      </h3>
      <p className="text-[var(--color-ink-500)] leading-relaxed text-[15px]">
        {description}
      </p>
    </motion.div>
  );
}