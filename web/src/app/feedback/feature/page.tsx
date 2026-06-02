import type { Metadata } from "next";
import { PageShell } from "@/components/PageShell";
import { FeedbackForm } from "@/components/FeedbackForm";
import { Reveal } from "@/components/Reveal";

export const metadata: Metadata = {
  title: "Request a feature | peppy",
  description: "Have an idea for peppy? Let us know what you'd like to see.",
};

export default function FeatureRequestPage() {
  return (
    <PageShell>
      <section className="px-6 pt-20 pb-24">
        <div className="mx-auto max-w-[600px]">
          <Reveal>
            <h1 className="text-[clamp(32px,5vw,48px)] font-semibold leading-[1.08] tracking-[-0.02em] text-ink-900">
              Request a{" "}
              <em className="font-serif italic font-medium text-rust-500">
                feature.
              </em>
            </h1>
            <p className="mt-4 max-w-[480px] text-[17px] leading-[1.55] text-ink-700">
              Have an idea that would make peppy better? We read every
              suggestion and use them to shape what we build next.
            </p>
          </Reveal>

          <Reveal delay={100}>
            <div className="mt-10">
              <FeedbackForm
                type="feature"
                placeholder="Describe the feature you'd like to see..."
                buttonLabel="Submit request"
                successMessage="Thank you for your suggestion! We review every feature request and it helps us build a better peppy."
              />
            </div>
          </Reveal>
        </div>
      </section>
    </PageShell>
  );
}
