import { PageShell } from "@/components/PageShell";
import {
  Hero,
  Features,
  Records,
  NotAll,
  Testimonials,
  CTA,
} from "@/components/Sections";

export default function Home() {
  return (
    <PageShell>
      <Hero />
      <Features />
      <Records />
      <NotAll />
      <Testimonials />
      <CTA />
    </PageShell>
  );
}
