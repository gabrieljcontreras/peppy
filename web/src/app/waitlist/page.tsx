import type { Metadata } from "next";
import { PageShell } from "@/components/PageShell";
import { WaitlistForm } from "@/components/WaitlistForm";
import { Reveal } from "@/components/Reveal";

export const metadata: Metadata = {
  title: "Join the Waitlist",
  description:
    "Get early access to peppy, the peptide protocol tracker that connects the dots so you can see what's actually working. Sign up now.",
};

const faqs = [
  {
    q: "What is peppy?",
    a: "peppy is a mobile app that helps you track peptide protocols, daily check-ins, weight, and wearable data. It connects the dots so you can see what's actually working.",
  },
  {
    q: "Is peppy free?",
    a: "Yes, peppy is completely free during the early access period. We'll introduce plans later, but early access users will always get special pricing.",
  },
  {
    q: "What platforms does peppy support?",
    a: "We're launching on iOS first, with Android coming shortly after. The web dashboard is in development.",
  },
  {
    q: "Is my data private?",
    a: "Absolutely. Your health data is encrypted at rest and in transit. We never sell your data, and you can export or delete everything at any time.",
  },
];

export default function WaitlistPage() {
  return (
    <PageShell>
      <section className="px-6 pt-20 pb-16">
        <div className="mx-auto max-w-[600px] text-center">
          <Reveal>
            <p className="inline-flex items-center gap-2 rounded-full border border-border-subtle bg-cream-50/70 px-3 py-1 text-[13px] font-medium text-ink-700">
              <span className="inline-block h-1.5 w-1.5 rounded-full bg-rust-500" />
              Early access
            </p>

            <h1 className="mt-5 text-[clamp(36px,5.5vw,56px)] font-semibold leading-[1.05] tracking-[-0.025em] text-ink-900">
              Join the peppy
              <br />
              <em className="font-serif italic font-medium text-rust-500">
                waitlist.
              </em>
            </h1>

            <p className="mx-auto mt-5 max-w-[480px] text-[17px] leading-[1.55] text-ink-700">
              Be among the first to track your protocol with clarity.
              We&apos;ll let you know as soon as your spot is ready.
            </p>
          </Reveal>

          <Reveal delay={100}>
            <div className="relative mt-8">
              <WaitlistForm />
            </div>
          </Reveal>

          <Reveal delay={200}>
            <p className="mt-4 text-[13px] text-ink-500">
              No spam, ever. We&apos;ll only email you about your early access invite.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="px-6 pb-24">
        <div className="mx-auto max-w-[640px]">
          <Reveal>
            <h2 className="mb-8 text-center text-[28px] font-semibold tracking-[-0.015em] text-ink-900">
              Frequently asked questions
            </h2>
          </Reveal>

          <div className="flex flex-col gap-4">
            {faqs.map((faq, i) => (
              <Reveal key={i} delay={i * 60}>
                <div className="rounded-2xl bg-cream-50 p-6">
                  <h3 className="text-[16px] font-semibold text-ink-900">
                    {faq.q}
                  </h3>
                  <p className="mt-2 text-[14.5px] leading-relaxed text-ink-700">
                    {faq.a}
                  </p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>
    </PageShell>
  );
}
