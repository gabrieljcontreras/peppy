"use client";

import { useState } from "react";
import { motion } from "motion/react";
import { Check, ArrowRight } from "lucide-react";
import { Nav } from "@/components/layout/Nav";
import { Footer } from "@/components/layout/Footer";

export default function WaitlistPage() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email) return;
    setStatus("loading");

    try {
      await new Promise((resolve) => setTimeout(resolve, 900));
      setStatus("success");
      setEmail("");
    } catch {
      setStatus("error");
    }
  };

  return (
    <>
      <Nav />
      <main className="relative overflow-hidden pt-32 md:pt-40 pb-24 md:pb-32">
        <div className="pointer-events-none absolute inset-0 -z-10">
          <div className="absolute -top-32 left-1/2 -translate-x-1/2 w-[800px] h-[500px] rounded-full bg-[radial-gradient(closest-side,rgba(199,107,62,0.15),transparent_70%)]" />
        </div>

        <div className="mx-auto max-w-6xl px-6 md:px-8">
          <div className="max-w-2xl mx-auto text-center">
            <motion.div
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.55, ease: [0.2, 0.8, 0.2, 1] }}
              className="mb-6 flex justify-center"
            >
              <span className="inline-flex items-center gap-2 rounded-full border border-[var(--color-ink-100)] bg-[var(--color-cream-50)] px-3 py-1.5 text-[12px] font-semibold uppercase tracking-[0.08em] text-[var(--color-ink-500)]">
                <span className="h-1.5 w-1.5 rounded-full bg-[var(--color-rust-500)]" />
                Limited beta
              </span>
            </motion.div>

            <motion.h1
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.05, ease: [0.2, 0.8, 0.2, 1] }}
              className="text-4xl md:text-6xl font-semibold text-[var(--color-ink-900)] tracking-[-0.025em] leading-[1.05]"
            >
              Get <em className="peppy-accent">early</em> access
            </motion.h1>
            <motion.p
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.15, ease: [0.2, 0.8, 0.2, 1] }}
              className="mt-5 text-lg text-[var(--color-ink-500)]"
            >
              Be first to know when peppy launches, and unlock an extended trial.
            </motion.p>

            <motion.div
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.25, ease: [0.2, 0.8, 0.2, 1] }}
              className="mt-10"
            >
              {status === "success" ? (
                <div className="rounded-2xl bg-[var(--color-cream-50)] px-8 py-10">
                  <div className="mx-auto mb-4 inline-flex h-12 w-12 items-center justify-center rounded-full bg-[var(--color-rust-500)]/10 text-[var(--color-rust-500)]">
                    <Check className="h-6 w-6" strokeWidth={2} />
                  </div>
                  <p className="text-xl font-semibold text-[var(--color-ink-900)]">
                    You&apos;re on the list.
                  </p>
                  <p className="mt-2 text-[15px] text-[var(--color-ink-500)]">
                    We&apos;ll send a note when peppy is ready for you.
                  </p>
                </div>
              ) : (
                <form onSubmit={handleSubmit}>
                  <div className="flex items-center gap-2 rounded-full bg-[var(--color-cream-50)] p-1.5 ring-1 ring-[var(--color-ink-100)] focus-within:ring-[var(--color-rust-500)] transition-colors duration-200">
                    <label htmlFor="waitlist-email" className="sr-only">
                      Email address
                    </label>
                    <input
                      id="waitlist-email"
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="you@example.com"
                      required
                      className="flex-1 bg-transparent px-4 py-2 text-base text-[var(--color-ink-900)] placeholder:text-[var(--color-ink-300)] focus:outline-none"
                    />
                    <button
                      type="submit"
                      disabled={status === "loading"}
                      className="group inline-flex h-11 items-center gap-1.5 rounded-full bg-[var(--color-ink-900)] px-5 text-sm font-semibold text-[var(--color-cream-100)] transition-[background-color,transform] duration-200 hover:bg-[var(--color-ink-600)] active:scale-[0.98] disabled:opacity-50"
                    >
                      {status === "loading" ? "Joining" : "Join"}
                      <ArrowRight
                        className="h-4 w-4 transition-transform duration-200 group-hover:translate-x-0.5"
                        strokeWidth={2}
                      />
                    </button>
                  </div>
                  {status === "error" && (
                    <p className="mt-3 text-sm text-red-600">
                      Something went wrong. Try again.
                    </p>
                  )}
                </form>
              )}
              <p className="mt-4 text-[13px] text-[var(--color-ink-400)]">
                No spam. Unsubscribe anytime.
              </p>
            </motion.div>

            {/* Stats */}
            <motion.div
              initial={{ opacity: 0, y: 16 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-40px" }}
              transition={{ duration: 0.6, ease: [0.2, 0.8, 0.2, 1] }}
              className="mt-20 grid grid-cols-3 gap-6"
            >
              {[
                { value: "500+", label: "On waitlist" },
                { value: "60+", label: "Peptides supported" },
                { value: "2026", label: "Launch year" },
              ].map((s) => (
                <div key={s.label}>
                  <p className="text-3xl md:text-4xl font-semibold text-[var(--color-ink-900)] tabular tracking-[-0.02em]">
                    {s.value}
                  </p>
                  <p className="mt-1 text-[12px] font-semibold uppercase tracking-[0.08em] text-[var(--color-ink-400)]">
                    {s.label}
                  </p>
                </div>
              ))}
            </motion.div>
          </div>
        </div>
      </main>
      <Footer />
    </>
  );
}