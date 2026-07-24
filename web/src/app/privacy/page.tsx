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
          Last updated: July 23, 2026
        </p>

        <div className="mt-10 flex flex-col gap-8 text-[15.5px] leading-[1.7] text-ink-700 [&_h2]:mt-2 [&_h2]:text-[20px] [&_h2]:font-semibold [&_h2]:text-ink-900 [&_h3]:mt-1 [&_h3]:text-[16px] [&_h3]:font-semibold [&_h3]:text-ink-900">
          <section>
            <h2>1. Information We Collect</h2>
            <p className="mt-3">
              When you use peppy, we collect the information you provide directly:
              email address, display name, and the health and wellness data you
              choose to log, such as protocol details, doses, check-ins, insights,
              wearable metrics, and free-text notes.
            </p>
            <p className="mt-2">
              We also collect basic usage analytics (screen views, feature usage)
              to improve the app. We do not collect precise location data.
            </p>
          </section>

          <section>
            <h2>2. How We Use Your Data</h2>
            <p className="mt-3">
              We use this information to provide the app, maintain your timeline,
              generate the insights and reminders you choose to use, and improve
              the Service. We do not sell your health data or use it for
              advertising.
            </p>
          </section>

          <section>
            <h2>3. Data Storage &amp; Security</h2>
            <p className="mt-3">
              We use reasonable administrative, technical, and organizational
              measures designed to protect the information we hold. Peppy uses
              cloud infrastructure services that support HIPAA-eligible
              configurations. This does not mean Peppy is HIPAA compliant, and
              Peppy does not currently represent that it has Business Associate
              Agreements covering the service.
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
              You can export available account, profile, preference, protocol,
              dose-log, check-in, and insight data, or request account deletion
              at any time. After you confirm deletion, we remove your
              active-system data immediately. Limited backup and provider
              retention may continue under our disclosed operational terms.
            </p>
          </section>

          <section>
            <h2>6. AI Processing and Third Parties</h2>
            <p className="mt-3">
              Relevant health and wellness data and free-text notes may be
              processed by a third-party AI processing service to generate
              informational insights. We exclude direct identifiers from those
              inputs. The resulting output is informational only and is not
              medical advice, diagnosis, or treatment. You control what you log
              and whether to use features that generate these insights.
            </p>
            <p className="mt-2">
              We also use service providers that support hosting, database, and
              email delivery. They process information only to provide services
              to Peppy and not for their own purposes.
            </p>
          </section>

          <section>
            <h2>7. Contact</h2>
            <p className="mt-3">
              Questions about this policy? Reach us at{" "}
              <a
                href="mailto:legal@get-peppy.com"
                className="text-rust-500 underline underline-offset-2 hover:text-rust-700"
              >
                legal@get-peppy.com
              </a>
              .
            </p>
          </section>
        </div>
      </article>
    </PageShell>
  );
}
