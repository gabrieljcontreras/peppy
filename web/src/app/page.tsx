import { PageShell } from "@/components/PageShell";
import {
  Hero,
  WorksWith,
  Features,
  FeatureRows,
  NotAll,
  Privacy,
  Testimonials,
  CTA,
} from "@/components/Sections";

export default function Home() {
  return (
    <PageShell>
      <Hero />
      <WorksWith />
      <Features />
      <FeatureRows />
      <NotAll />
      <Privacy />
      <Testimonials />
      <CTA />
    </PageShell>
  );
}
