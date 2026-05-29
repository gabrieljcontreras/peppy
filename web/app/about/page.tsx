"use client";

import { motion } from "motion/react";
import { Lock, Database, LineChart } from "lucide-react";
import { Nav } from "@/components/layout/Nav";
import { Footer } from "@/components/layout/Footer";
import { Button } from "@/components/ui/Button";

const principles = [
  {
    icon: Lock,
    title: "Privacy by design",
    description:
      "Health data is sensitive. We encrypt everything, never sell your data, and give you full control.",
  },
  {
    icon: Database,
    title: "You own your data",
    description:
      "Export anytime. Delete anytime. No lock-in, no dark patterns, no surprises.",
  },
  {
    icon: LineChart,
    title: "Insights, not prescriptions",
    description:
      "We help you see patterns. We don't tell you what to do — that's between you and your provider.",
  },
];

export default function AboutPage() {
  return (
    <>
      <Nav />
      <main className="relative overflow-hidden pt-32 md:pt-40 pb-24 md:pb-32">
        {/* Ambient */}
        <div className="pointer-events-none absolute inset-0 -z-10">
          <div className="absolute -top-32 left-1/2 -translate-x-1/2 w-[700px] h-[500px] rounded-full bg-[radial-gradient(closest-side,rgba(199,107,62,0.12),transparent_70%)]" />
        </div>

        <div className="mx-auto max-w-6xl px-6 md:px-8">
          {/* Header — centered */}
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease: [0.2, 0.8, 0.2, 1] }}
            className="text-center mb-16 md:mb-20 max-w-2xl mx-auto"
          >
            <p className="mb-4 text-[12px] font-semibold uppercase tracking-[0.08em] text-[var(--color-rust-500)]">
              Our story
            </p>
            <h1 className="text-4xl md:text-6xl font-semibold text-[var(--color-ink-900)] tracking-[-0.025em] leading-[1.05]">
              Why <span className="peppy-wordmark">peppy</span>.
            </h1>
          </motion.div>

          {/* Story content — readable column */}
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.15, ease: [0.2, 0.8, 0.2, 1] }}
            className="max-w-3xl mx-auto space-y-7 text-[17px] md:text-lg text-[var(--color-ink-500)] leading-relaxed"
          >
            <p>
              Peptide protocols are powerful tools for health optimization. GLP-1
              agonists, growth hormone secretagogues, healing peptides — the
              science is advancing rapidly.
            </p>

            <p>
              But tracking a protocol shouldn&apos;t require a spreadsheet, a
              notebook, and three different apps. You shouldn&apos;t have to piece
              together your weight data from one place, your symptoms from
              another, and your lab results from a PDF.
            </p>

            <p className="text-xl md:text-2xl font-semibold text-[var(--color-ink-900)] leading-snug tracking-[-0.01em]">
              <span className="peppy-wordmark">peppy</span> exists to solve this.
            </p>

            <p>
              One app to track your protocols, log daily check-ins, import data
              from wearables, and see AI-powered insights that help you understand
              what&apos;s actually working.
            </p>
          </motion.div>

          {/* Principles — card grid */}
          <div className="mt-24 md:mt-32">
            <motion.h2
              initial={{ opacity: 0, y: 16 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-40px" }}
              transition={{ duration: 0.6, ease: [0.2, 0.8, 0.2, 1] }}
              className="text-3xl md:text-4xl font-semibold text-[var(--color-ink-900)] tracking-[-0.02em] mb-10 md:mb-12 text-center"
            >
              Our principles
            </motion.h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-5">
              {principles.map((p, i) => (
                <motion.div
                  key={p.title}
                  initial={{ opacity: 0, y: 16 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true, margin: "-40px" }}
                  transition={{
                    duration: 0.55,
                    delay: i * 0.08,
                    ease: [0.2, 0.8, 0.2, 1],
                  }}
                  className="rounded-2xl bg-[var(--color-cream-50)] p-7 md:p-8"
                >
                  <div className="mb-5 inline-flex h-11 w-11 items-center justify-center rounded-2xl bg-[var(--color-rust-500)]/8 text-[var(--color-rust-500)]">
                    <p.icon className="h-5 w-5" strokeWidth={1.6} />
                  </div>
                  <h3 className="text-lg font-semibold text-[var(--color-ink-900)] mb-2 tracking-[-0.01em]">
                    {p.title}
                  </h3>
                  <p className="text-[var(--color-ink-500)] leading-relaxed text-[15px]">
                    {p.description}
                  </p>
                </motion.div>
              ))}
            </div>
          </div>

          {/* CTA */}
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-40px" }}
            transition={{ duration: 0.6, ease: [0.2, 0.8, 0.2, 1] }}
            className="mt-24 md:mt-32 text-center"
          >
            <p className="text-[var(--color-ink-500)] mb-6">
              Launching in 2026. Join the waitlist.
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