import type { Metadata } from "next";
import { PageShell } from "@/components/PageShell";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How peppy collects, uses, and protects your personal data.",
};

export default function PrivacyPage() {
  return (
    <PageShell>
      <article className="mx-auto max-w-[720px] px-6 pt-20 pb-24">
        <h1 className="text-[36px] font-semibold tracking-[-0.02em] text-ink-900">
          Privacy Policy
        </h1>
        <p className="mt-2 text-[14px] text-ink-500">
          Last updated: June 1, 2026
        </p>

        <div className="mt-10 flex flex-col gap-8 text-[15.5px] leading-[1.7] text-ink-700 [&_h2]:mt-2 [&_h2]:text-[20px] [&_h2]:font-semibold [&_h2]:text-ink-900 [&_h3]:mt-1 [&_h3]:text-[16px] [&_h3]:font-semibold [&_h3]:text-ink-900">
          <section>
            <h2>1. Information We Collect</h2>
            <p className="mt-3">
              When you use peppy, we collect information you provide directly:
              email address, display name, and the health data you choose to log
              (protocol details, check-ins, lab results, and wearable metrics).
            </p>
            <p className="mt-2">
              We also collect basic usage analytics (screen views, feature usage)
              to improve the app. We do not collect precise location data.
            </p>
          </section>

          <section>
            <h2>2. How We Use Your Data</h2>
            <p className="mt-3">
              Your health data is used exclusively to power your personal
              insights and timeline. We never use your health data for
              advertising, and we never sell it to third parties.
            </p>
          </section>

          <section>
            <h2>3. Data Storage &amp; Security</h2>
            <p className="mt-3">
              All health data is encrypted at rest using AES-256 and in transit
              using TLS 1.3. OAuth tokens for wearable integrations are
              encrypted with Fernet symmetric encryption. Our infrastructure
              runs on HIPAA-eligible services with a Business Associate
              Agreement (BAA).
            </p>
          </section>

          <section>
            <h2>4. Wearable Integrations</h2>
            <p className="mt-3">
              When you connect Oura, Whoop, or Apple Health, we request only
              the data categories needed to generate insights (sleep, HRV,
              resting heart rate, recovery). You can disconnect at any time and
              we will delete the associated tokens and synced data.
            </p>
          </section>

          <section>
            <h2>5. Data Retention &amp; Deletion</h2>
            <p className="mt-3">
              You can export all your data or request full account deletion at
              any time. Upon deletion, all personal data is permanently removed
              within 30 days.
            </p>
          </section>

          <section>
            <h2>6. Third Parties</h2>
            <p className="mt-3">
              We use essential infrastructure providers (hosting, database,
              email delivery) under strict data processing agreements. We do
              not share your health data with any third party for their own
              purposes.
            </p>
          </section>

          <section>
            <h2>7. Contact</h2>
            <p className="mt-3">
              Questions about this policy? Reach us at{" "}
              <a
                href="mailto:privacy@peppy.app"
                className="text-rust-500 underline underline-offset-2 hover:text-rust-700"
              >
                privacy@peppy.app
              </a>
              .
            </p>
          </section>
        </div>
      </article>
    </PageShell>
  );
}
