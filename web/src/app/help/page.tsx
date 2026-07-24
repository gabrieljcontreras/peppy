import type { Metadata } from "next";
import { HelpSearch } from "@/components/HelpSearch";
import { PageShell } from "@/components/PageShell";

export const metadata: Metadata = {
  title: "Help Center",
  description: "Answers to common questions about using Peppy.",
};

export default function HelpPage() {
  return (
    <PageShell>
      <section className="px-6 pt-16 pb-24 sm:pt-20">
        <div className="mx-auto max-w-[720px]">
          <h1 className="text-[36px] font-semibold tracking-[-0.02em] text-ink-900">
            Help Center
          </h1>
          <p className="mt-3 max-w-[560px] text-[16px] leading-[1.6] text-ink-700">
            Browse common questions about your account, tracking, privacy, and
            support.
          </p>
          <div className="mt-8">
            <HelpSearch />
          </div>
        </div>
      </section>
    </PageShell>
  );
}
