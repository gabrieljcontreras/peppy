import type { Metadata } from "next";
import { PageShell } from "@/components/PageShell";
import { FeedbackForm } from "@/components/FeedbackForm";
import { Reveal } from "@/components/Reveal";

export const metadata: Metadata = {
  title: "Contact",
  description:
    "Get in touch with the peppy team. Questions, feedback, or partnership inquiries — we'd love to hear from you.",
};

export default function ContactPage() {
  return (
    <PageShell>
      <section className="px-6 pt-20 pb-24">
        <div className="mx-auto max-w-[600px]">
          <Reveal>
            <h1 className="text-[clamp(32px,5vw,48px)] font-semibold leading-[1.08] tracking-[-0.02em] text-ink-900">
              Get in{" "}
              <em className="font-serif italic font-medium text-rust-500">
                touch.
              </em>
            </h1>
            <p className="mt-4 max-w-[480px] text-[17px] leading-[1.55] text-ink-700">
              Questions, partnerships, or just want to say hello?
              We would love to hear from you.
            </p>
          </Reveal>

          <Reveal delay={100}>
            <div className="mt-10">
              <FeedbackForm
                type="contact"
                placeholder="What's on your mind?"
                buttonLabel="Send message"
                successMessage="Thank you for reaching out! We will get back to you as soon as we can."
              />
            </div>
          </Reveal>
        </div>
      </section>
    </PageShell>
  );
}
