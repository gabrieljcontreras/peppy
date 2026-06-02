import type { Metadata } from "next";
import Link from "next/link";
import { PageShell } from "@/components/PageShell";
import { Reveal } from "@/components/Reveal";

export const metadata: Metadata = {
  title: "About — peppy",
  description:
    "Why we built peppy and what we believe about personal health tracking.",
};

const values = [
  {
    title: "Privacy first",
    body: "Your health data is yours. Encrypted at rest, encrypted in transit, never sold. Export or delete everything at any time.",
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6">
        <rect x="3" y="11" width="18" height="11" rx="2" />
        <path d="M7 11V7a5 5 0 0110 0v4" />
      </svg>
    ),
  },
  {
    title: "Science-backed",
    body: "Every insight is grounded in your data: weight trends, biomarkers, wearable metrics. No guesswork, no pseudoscience.",
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6">
        <path d="M9 3v6l-4 8a2 2 0 002 2h10a2 2 0 002-2l-4-8V3" />
        <path d="M8 3h8" />
      </svg>
    ),
  },
  {
    title: "User-controlled",
    body: "You decide what to track, what to share, and who sees it. Generate clean reports for your provider on your terms.",
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6">
        <circle cx="12" cy="12" r="3" />
        <path d="M12 1v4m0 14v4m-9-9h4m14 0h-4m-1.5-6.5l-2.8 2.8m-3.4 3.4l-2.8 2.8m0-9l2.8 2.8m3.4 3.4l2.8 2.8" />
      </svg>
    ),
  },
];

export default function AboutPage() {
  return (
    <PageShell>
      <section className="px-6 pt-20 pb-16">
        <div className="mx-auto max-w-[720px]">
          <Reveal>
            <h1 className="text-[clamp(36px,5.5vw,56px)] font-semibold leading-[1.05] tracking-[-0.025em] text-ink-900">
              We built peppy because
              <br />
              <em className="font-serif italic font-medium text-rust-500">
                protocols deserve clarity.
              </em>
            </h1>
          </Reveal>

          <Reveal delay={100}>
            <p className="mt-6 max-w-[560px] text-[18px] leading-[1.6] text-ink-700">
              People running peptide protocols are doing something hard. Tracking
              doses, monitoring side-effects, reading lab work, syncing wearables,
              all across scattered notes, spreadsheets, and memory.
            </p>
          </Reveal>

          <Reveal delay={200}>
            <p className="mt-4 max-w-[560px] text-[18px] leading-[1.6] text-ink-700">
              peppy brings it all into one timeline. Log what you&apos;re doing, how
              you feel, and what the numbers say. Then let the engine find the
              signal in the noise.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="px-6 pb-24">
        <div className="mx-auto max-w-[900px]">
          <Reveal>
            <h2 className="mb-10 text-center text-[32px] font-semibold tracking-[-0.015em] text-ink-900">
              What we believe
            </h2>
          </Reveal>

          <div className="grid gap-6 md:grid-cols-3">
            {values.map((v, i) => (
              <Reveal key={v.title} delay={i * 100}>
                <div className="rounded-2xl bg-cream-50 p-7">
                  <div className="grid h-11 w-11 place-items-center rounded-xl bg-rust-500/10 text-rust-600">
                    {v.icon}
                  </div>
                  <h3 className="mt-4 text-[18px] font-semibold text-ink-900">
                    {v.title}
                  </h3>
                  <p className="mt-2 text-[14.5px] leading-relaxed text-ink-700">
                    {v.body}
                  </p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="px-6 pb-24">
        <Reveal>
          <div className="mx-auto flex max-w-[720px] flex-col items-center gap-5 rounded-3xl bg-rust-500 px-8 py-14 text-center">
            <h2 className="text-[clamp(28px,4vw,40px)] font-semibold leading-[1.1] tracking-[-0.02em] text-cream-50">
              Interested in joining?
            </h2>
            <p className="max-w-[400px] text-cream-50/90">
              peppy is free during early access. Sign up and we&apos;ll
              let you know when your spot is ready.
            </p>
            <Link
              href="/waitlist"
              className="inline-flex items-center gap-2 rounded-full bg-ink-900 px-6 py-3.5 text-[15px] font-semibold text-cream-50 transition-all hover:-translate-y-px hover:shadow-[0_4px_20px_rgba(224,122,95,0.3)]"
            >
              Join the waitlist
            </Link>
          </div>
        </Reveal>
      </section>
    </PageShell>
  );
}
