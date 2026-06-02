import type { Metadata } from "next";
import { PageShell } from "@/components/PageShell";
import { FeedbackForm } from "@/components/FeedbackForm";
import { Reveal } from "@/components/Reveal";

export const metadata: Metadata = {
  title: "Report a bug | peppy",
  description: "Found something broken? Let us know so we can fix it.",
};

export default function BugReportPage() {
  return (
    <PageShell>
      <section className="px-6 pt-20 pb-24">
        <div className="mx-auto max-w-[600px]">
          <Reveal>
            <h1 className="text-[clamp(32px,5vw,48px)] font-semibold leading-[1.08] tracking-[-0.02em] text-ink-900">
              Report a{" "}
              <em className="font-serif italic font-medium text-rust-500">
                bug.
              </em>
            </h1>
            <p className="mt-4 max-w-[480px] text-[17px] leading-[1.55] text-ink-700">
              Something not working right? Tell us what happened and
              we will look into it.
            </p>
          </Reveal>

          <Reveal delay={100}>
            <div className="mt-10">
              <FeedbackForm
                type="bug"
                placeholder="Describe the issue you encountered..."
                buttonLabel="Submit report"
                successMessage="Thank you so much for your feedback. We will do better to fix your issues."
              />
            </div>
          </Reveal>
        </div>
      </section>
    </PageShell>
  );
}
