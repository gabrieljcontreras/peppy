import type { Metadata } from "next";
import { PageShell } from "@/components/PageShell";

export const metadata: Metadata = {
  title: "Terms of Service — peppy",
  description: "Terms governing your use of peppy.",
};

export default function TermsPage() {
  return (
    <PageShell>
      <article className="mx-auto max-w-[720px] px-6 pt-20 pb-24">
        <h1 className="text-[36px] font-semibold tracking-[-0.02em] text-ink-900">
          Terms of Service
        </h1>
        <p className="mt-2 text-[14px] text-ink-500">
          Last updated: June 1, 2026
        </p>

        <div className="mt-10 flex flex-col gap-8 text-[15.5px] leading-[1.7] text-ink-700 [&_h2]:mt-2 [&_h2]:text-[20px] [&_h2]:font-semibold [&_h2]:text-ink-900">
          <section>
            <h2>1. Acceptance of Terms</h2>
            <p className="mt-3">
              By accessing or using peppy (&ldquo;the Service&rdquo;), you agree
              to be bound by these Terms. If you do not agree, do not use the
              Service.
            </p>
          </section>

          <section>
            <h2>2. Description of Service</h2>
            <p className="mt-3">
              peppy is a personal health-tracking application designed to help
              users log peptide protocols, daily check-ins, lab results, and
              wearable data. The Service provides data visualization and
              AI-generated insights based on user-provided data.
            </p>
          </section>

          <section>
            <h2>3. Not Medical Advice</h2>
            <p className="mt-3">
              peppy is an informational tool only. Nothing in the Service
              constitutes medical advice, diagnosis, or treatment. Always
              consult a qualified healthcare provider before making decisions
              about your health or modifying any protocol.
            </p>
          </section>

          <section>
            <h2>4. User Accounts</h2>
            <p className="mt-3">
              You are responsible for maintaining the confidentiality of your
              account credentials and for all activity under your account. You
              must provide accurate information and keep it up to date.
            </p>
          </section>

          <section>
            <h2>5. Acceptable Use</h2>
            <p className="mt-3">
              You agree not to misuse the Service, including but not limited to:
              reverse engineering, unauthorized access, interfering with other
              users, or using the Service for any unlawful purpose.
            </p>
          </section>

          <section>
            <h2>6. Intellectual Property</h2>
            <p className="mt-3">
              The Service, including its design, code, and content, is owned by
              peppy, inc. Your health data remains yours. We claim no ownership
              over data you provide to the Service.
            </p>
          </section>

          <section>
            <h2>7. Limitation of Liability</h2>
            <p className="mt-3">
              To the maximum extent permitted by law, peppy, inc. shall not be
              liable for any indirect, incidental, special, or consequential
              damages arising from your use of the Service.
            </p>
          </section>

          <section>
            <h2>8. Changes to Terms</h2>
            <p className="mt-3">
              We may update these Terms from time to time. We will notify you of
              material changes via email or in-app notification. Continued use
              after changes constitutes acceptance.
            </p>
          </section>

          <section>
            <h2>9. Contact</h2>
            <p className="mt-3">
              Questions? Contact us at{" "}
              <a
                href="mailto:legal@peppy.app"
                className="text-rust-500 underline underline-offset-2 hover:text-rust-700"
              >
                legal@peppy.app
              </a>
              .
            </p>
          </section>
        </div>
      </article>
    </PageShell>
  );
}
