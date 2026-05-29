"use client";

import { motion } from "motion/react";

const steps = [
  {
    number: "01",
    title: "Set up your protocol",
    description:
      "Add your compounds, doses, and schedule. Smart defaults and autocomplete make it fast.",
  },
  {
    number: "02",
    title: "Log daily check-ins",
    description:
      "30-second check-ins capture weight, symptoms, and how you feel each morning.",
  },
  {
    number: "03",
    title: "Get insights",
    description:
      "See trends, spot patterns, and get suggestions to optimize your protocol — week over week.",
  },
];

export function HowItWorks() {
  return (
    <section id="how" className="relative py-24 md:py-32">
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
            How it works
          </p>
          <h2 className="text-3xl md:text-5xl font-semibold text-[var(--color-ink-900)] tracking-[-0.02em] leading-[1.1]">
            Start in minutes. See results in weeks.
          </h2>
        </motion.div>

        {/* Steps */}
        <div className="relative max-w-3xl mx-auto">
          {/* Vertical connector line */}
          <motion.div
            initial={{ scaleY: 0 }}
            whileInView={{ scaleY: 1 }}
            viewport={{ once: true, margin: "-100px" }}
            transition={{ duration: 1.4, ease: [0.2, 0.8, 0.2, 1] }}
            style={{ originY: 0 }}
            className="absolute left-[27px] top-3 bottom-3 w-px bg-gradient-to-b from-[var(--color-rust-500)]/40 via-[var(--color-rust-500)]/20 to-transparent"
            aria-hidden
          />

          <div className="space-y-14 md:space-y-16">
            {steps.map((step, i) => (
              <motion.div
                key={step.number}
                initial={{ opacity: 0, x: -16 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true, margin: "-80px" }}
                transition={{
                  duration: 0.6,
                  delay: i * 0.12,
                  ease: [0.2, 0.8, 0.2, 1],
                }}
                className="relative flex gap-6 md:gap-8"
              >
                <div className="relative flex-shrink-0">
                  <div className="flex h-14 w-14 items-center justify-center rounded-full bg-[var(--color-cream-100)] ring-1 ring-[var(--color-rust-500)]/30">
                    <span className="text-[15px] font-semibold tabular text-[var(--color-rust-500)]">
                      {step.number}
                    </span>
                  </div>
                </div>
                <div className="pt-2">
                  <h3 className="text-xl md:text-2xl font-semibold text-[var(--color-ink-900)] tracking-[-0.01em] mb-2">
                    {step.title}
                  </h3>
                  <p className="text-[var(--color-ink-500)] leading-relaxed text-[16px] md:text-[17px] max-w-lg">
                    {step.description}
                  </p>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}