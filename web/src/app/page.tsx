import { Nav } from "@/components/Nav";
import {
  Hero,
  Features,
  Records,
  NotAll,
  Testimonials,
  CTA,
  Footer,
} from "@/components/Sections";

export default function Home() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Features />
        <Records />
        <NotAll />
        <Testimonials />
        <CTA />
      </main>
      <Footer />
    </>
  );
}
