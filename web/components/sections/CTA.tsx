"use client";

import { useState } from "react";
import { motion } from "motion/react";
import { ArrowRight, Check } from "lucide-react";

export function CTA() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email) return;
    setStatus("loading");
    try {
      await new Promise((r) => setTimeout(r, 900));
      setStatus("success");
      setEmail("");
    } catch {
      setStatus("error");
    }
  };

  return (
    <section className="relative overflow-hidden py-24 md:py-32 bg-[var(--color-ink-900)]">
      {/* Ambient warm glow */}
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute -top-40 left-1/2 -translate-x-1/2 w-[800px] h-[500px] rounded-full bg-[radial-gradient(closest-side,rgba(199,107,62,0.18),transparent_70%)]" />
        <div className="absolute -bottom-40 left-1/2 -translate-x-1/2 w-[600px] h-[400px] rounded-full bg-[radial-gradient(closest-side,rgba(199,107,62,0.12),transparent_70%)]" />
      </div>

      <div className="relative mx-auto max-w-3xl px-6 md:px-8 text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.6, ease: [0.2, 0.8, 0.2, 1] }}
        >
          <p className="mb-4 text-[12px] font-semibold uppercase tracking-[0.08em] text-[var(--color-rust-500)]">
            Launching 2026
          </p>
          <h2 className="text-3xl md:text-5xl font-semibold text-[var(--color-cream-100)] tracking-[-0.02em] leading-[1.1]">
            Ready to <em className="peppy-accent">optimize</em>?
          </h2>
          <p className="mt-5 text-lg text-[var(--color-ink-200)] max-w-xl mx-auto">
            Join the waitlist — be first to know when peppy launches, and get
            an extended trial on us.
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.6, delay: 0.1, ease: [0.2, 0.8, 0.2, 1] }}
          className="mt-10 mx-auto max-w-md"
        >
          {status === "success" ? (
            <div className="flex items-center justify-center gap-3 rounded-full bg-[var(--color-cream-100)]/10 px-6 py-4 text-[var(--color-cream-100)] ring-1 ring-[var(--color-cream-100)]/20">
              <Check className="h-5 w-5 text-[var(--color-rust-300)]" strokeWidth={2} />
              <span className="font-medium">You&apos;re on the list.</span>
            </div>
          ) : (
            <form onSubmit={submit} className="relative">
              <div className="flex items-center gap-2 rounded-full bg-[var(--color-ink-700)] p-1.5 ring-1 ring-[var(--color-ink-600)] focus-within:ring-[var(--color-rust-500)] transition-colors duration-200">
                <label htmlFor="cta-email" className="sr-only">Email address</label>
                <input
                  id="cta-email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  required
                  className="flex-1 bg-transparent px-4 py-2 text-base text-[var(--color-cream-100)] placeholder:text-[var(--color-ink-300)] focus:outline-none"
                />
                <button
                  type="submit"
                  disabled={status === "loading"}
                  className="group inline-flex h-11 items-center gap-1.5 rounded-full bg-[var(--color-rust-500)] px-5 text-sm font-semibold text-[var(--color-cream-100)] transition-[background-color,transform] duration-200 hover:bg-[var(--color-rust-600)] active:scale-[0.98] disabled:opacity-50"
                >
                  {status === "loading" ? "Joining" : "Join"}
                  <ArrowRight
                    className="h-4 w-4 transition-transform duration-200 group-hover:translate-x-0.5"
                    strokeWidth={2}
                  />
                </button>
              </div>
              {status === "error" && (
                <p className="mt-3 text-sm text-[var(--color-rust-300)]">
                  Something went wrong. Try again.
                </p>
              )}
            </form>
          )}
          <p className="mt-4 text-[13px] text-[var(--color-ink-300)]">
            No spam. Unsubscribe anytime.
          </p>
        </motion.div>
      </div>
    </section>
  );
}
